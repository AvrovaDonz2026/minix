#!/bin/bash
#
# MINIX/i386 test runner (distribution + QEMU smoke).
#
# Usage:
#   ./run_tests.sh [build|user|kernel|native|gate|all]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MINIX_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
OBJDIR="${OBJDIR:-${MINIX_ROOT}/obj.i386}"
ARCH=i386
MACHINE=i386
DESTDIR="${DESTDIR:-${OBJDIR}/destdir.${ARCH}}"
KERNEL="${KERNEL:-${OBJDIR}/minix/kernel/kernel}"
BOOT_KERNEL="${BOOT_KERNEL:-${DESTDIR}/boot/minix/.temp/kernel}"
QEMU_SCRIPT="${MINIX_ROOT}/minix/scripts/qemu-i386.sh"
RUNTIME_PROBE="${SCRIPT_DIR}/qemu_runtime_probe.py"
TIMEOUT="${TIMEOUT:-180}"
CMD_TIMEOUT="${CMD_TIMEOUT:-60}"
SMOKE_DISK_IMAGE="${SMOKE_DISK_IMAGE:-/tmp/minix-i386-smoke.img}"
SMOKE_GATE_TIMEOUT="${SMOKE_GATE_TIMEOUT:-300}"

passed=0
failed=0
skipped=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}[INFO]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; passed=$((passed + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; failed=$((failed + 1)); }
log_skip() { echo -e "${YELLOW}[SKIP]${NC} $*"; skipped=$((skipped + 1)); }

pick_tooldir() {
  local best="" d mt
  for d in "${OBJDIR}"/tooldir.*; do
    [[ -d "${d}" ]] || continue
    [[ -x "${d}/bin/i586-elf32-minix-gcc" ]] || continue
    mt="$(stat -c %Y "${d}" 2>/dev/null || echo 0)"
    if [[ -z "${best}" ]] || (( mt >= $(stat -c %Y "${best}" 2>/dev/null || echo 0) )); then
      best="${d}"
    fi
  done
  printf '%s' "${best}"
}

run_build_gate() {
  log_info "Test: i386 distribution artifacts"
  if [[ -x "${BOOT_KERNEL}" ]]; then
    log_pass "boot kernel present"
  else
    log_fail "missing ${BOOT_KERNEL}"
  fi
  if ls "${DESTDIR}/boot/minix/.temp"/mod* >/dev/null 2>&1; then
    log_pass "boot modules present"
  else
    log_fail "missing boot modules under ${DESTDIR}/boot/minix/.temp"
  fi
  if [[ -f "${KERNEL}" ]]; then
    log_pass "kernel ELF present"
  else
    log_fail "missing kernel ELF: ${KERNEL}"
  fi

  log_info "Test: i386 architecture recognition"
  if ./build.sh -m i386 list-arch 2>/dev/null | grep -q i386; then
    log_pass "Architecture recognition"
  else
    log_fail "Architecture recognition"
  fi

  log_info "Test: i386 kernel arch directory"
  if [[ -d "${MINIX_ROOT}/minix/kernel/arch/i386" ]]; then
    log_pass "Kernel arch directory exists"
    for file in head.S exception.c kernel.lds memory.c; do
      if [[ -f "${MINIX_ROOT}/minix/kernel/arch/i386/${file}" ]]; then
        log_pass "Kernel file: ${file}"
      else
        log_fail "Kernel file: ${file}"
      fi
    done
  else
    log_fail "Kernel arch directory"
  fi

  if [[ -x "${QEMU_SCRIPT}" ]]; then
    log_pass "qemu-i386.sh present"
  else
    log_fail "qemu-i386.sh missing"
  fi
}

run_user_tests() {
  local cc="" tooldir
  tooldir="$(pick_tooldir)"
  if [[ -n "${tooldir}" ]]; then
    cc="${tooldir}/bin/i586-elf32-minix-gcc"
  fi
  if [[ -z "${cc}" ]] || ! command -v "${cc}" >/dev/null 2>&1; then
    log_skip "i586 cross-compiler not found"
    return 0
  fi

  log_info "Using compiler: ${cc}"
  local sysroot_flags=""
  if [[ -d "${DESTDIR}" ]]; then
    sysroot_flags="--sysroot=${DESTDIR} -I${DESTDIR}/usr/include"
  fi

  local test_src="${SCRIPT_DIR}/test_arch_flags.c"
  if [[ ! -f "${test_src}" ]]; then
    log_skip "user compile smoke (no test source)"
    return 0
  fi

  log_info "Test: user-space compile smoke"
  if ${cc} ${sysroot_flags} -O2 -Wall -std=gnu99 -c "${test_src}" \
    -o /tmp/i386_user_smoke.o 2>/dev/null; then
    log_pass "user-space compile smoke"
    rm -f /tmp/i386_user_smoke.o
  else
    log_fail "user-space compile smoke"
  fi
}

run_native_gate() {
  local root="${DESTDIR}"
  local missing=()

  for entry in \
    usr/lib/libgcc.a \
    usr/lib/libstdc++.a \
    usr/include/stdio.h; do
    if [[ ! -e "${root}/${entry}" ]]; then
      missing+=("${entry}")
    fi
  done

  if [[ ! -x "${root}/usr/bin/gcc" && ! -x "${root}/usr/bin/cc" ]]; then
    missing+=("usr/bin/(gcc|cc)")
  fi

  if [[ "${#missing[@]}" -ne 0 ]]; then
    log_fail "native toolchain payload missing: ${missing[*]}"
    return 0
  fi
  log_pass "native toolchain payload"
}

run_kernel_tests() {
  if [[ ! -x "${QEMU_SCRIPT}" ]]; then
    log_skip "kernel boot (qemu-i386.sh missing)"
    return 0
  fi
  if ! command -v qemu-system-i386 >/dev/null 2>&1; then
    log_skip "kernel boot (qemu-system-i386 missing)"
    return 0
  fi
  if [[ ! -f "${KERNEL}" ]]; then
    log_skip "kernel boot (kernel missing)"
    return 0
  fi
  if [[ ! -d "${DESTDIR}" ]]; then
    log_skip "kernel boot (DESTDIR missing)"
    return 0
  fi

  log_info "Test: kernel boot"
  set +e
  timeout "${TIMEOUT}" "${QEMU_SCRIPT}" -s -k "${KERNEL}" -B "${DESTDIR}" \
    > /tmp/i386_boot_test.log 2>&1
  local boot_rc=$?
  set -e

  if [[ "${boot_rc}" -ne 0 && "${boot_rc}" -ne 124 ]]; then
    log_fail "kernel boot (runner rc=${boot_rc})"
  elif grep -Eq 'VFS: init_root done|exec path="/bin/sh"|init: exec /bin/sh|login:' \
    /tmp/i386_boot_test.log 2>/dev/null; then
    log_pass "kernel boot"
  else
    log_fail "kernel boot"
  fi
}

ensure_smoke_disk() {
  log_info "Creating smoke disk: ${SMOKE_DISK_IMAGE}"
  mkdir -p "$(dirname "${SMOKE_DISK_IMAGE}")"
  rm -f "${SMOKE_DISK_IMAGE}"
  OBJDIR="${OBJDIR}" DESTDIR="${DESTDIR}" OUTPUT="${SMOKE_DISK_IMAGE}" \
    "${MINIX_ROOT}/minix/releasetools/i386/mkdisk.sh" \
    -d "${OBJDIR}" -o "${SMOKE_DISK_IMAGE}" -D "${DESTDIR}"
}

run_qemu_gate() {
  if [[ ! -x "${QEMU_SCRIPT}" ]]; then
    log_skip "QEMU i386 boot smoke"
    return 0
  fi
  if ! command -v qemu-system-i386 >/dev/null 2>&1; then
    log_skip "QEMU i386 boot smoke"
    return 0
  fi
  if [[ ! -f "${RUNTIME_PROBE}" ]]; then
    log_skip "QEMU i386 boot smoke"
    return 0
  fi

  ensure_smoke_disk

  log_info "Test: QEMU i386 boot smoke"
  local attempt rc=1
  for attempt in 1 2 3; do
    pkill -9 qemu-system-i386 2>/dev/null || true
    sleep 2
    if [[ "${attempt}" -gt 1 ]]; then
      log_info "QEMU i386 boot smoke retry ${attempt}/3"
      rm -f "${SMOKE_DISK_IMAGE}"
      ensure_smoke_disk
    fi
    if python3 "${RUNTIME_PROBE}" \
      --qemu-script "${QEMU_SCRIPT}" \
      --kernel "${BOOT_KERNEL}" \
      --destdir "${DESTDIR}" \
      --disk "${SMOKE_DISK_IMAGE}" \
      --timeout "${SMOKE_GATE_TIMEOUT}"; then
      log_pass "QEMU i386 boot smoke"
      return 0
    fi
    rc=$?
    if [[ "${rc}" -eq 2 ]]; then
      log_skip "QEMU i386 boot smoke"
      return 0
    fi
  done
  log_fail "QEMU i386 boot smoke"
}

run_gate() {
  run_build_gate
  run_qemu_gate
}

TARGET="${1:-all}"
case "${TARGET}" in
  build) run_build_gate ;;
  user) run_user_tests ;;
  native) run_native_gate ;;
  kernel) run_kernel_tests ;;
  gate) run_gate ;;
  qemu) run_qemu_gate ;;
  all)
    run_build_gate
    echo ""
    run_user_tests
    echo ""
    run_native_gate
    echo ""
    run_kernel_tests
    echo ""
    run_qemu_gate
    ;;
  *)
    echo "Usage: $0 [build|user|kernel|native|gate|qemu|all]" >&2
    exit 1
    ;;
esac

echo ""
echo "========================================="
echo "i386 Test Summary"
echo "========================================="
echo -e "Passed:  ${GREEN}${passed}${NC}"
echo -e "Failed:  ${RED}${failed}${NC}"
echo -e "Skipped: ${YELLOW}${skipped}${NC}"
echo "========================================="

if [[ "${failed}" -ne 0 ]]; then
  exit 1
fi
if [[ "${passed}" -eq 0 && "${skipped}" -eq 0 ]]; then
  exit 2
fi
exit 0
