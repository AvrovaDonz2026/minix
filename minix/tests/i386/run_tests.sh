#!/bin/bash
#
# MINIX/i386 test runner (distribution + QEMU smoke).
#
# Usage:
#   ./run_tests.sh [build|gate|qemu|all]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MINIX_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
OBJDIR="${OBJDIR:-${MINIX_ROOT}/obj.i386}"
ARCH=i386
DESTDIR="${DESTDIR:-${OBJDIR}/destdir.${ARCH}}"
KERNEL="${KERNEL:-${OBJDIR}/minix/kernel/kernel}"
QEMU_SCRIPT="${MINIX_ROOT}/minix/scripts/qemu-i386.sh"
RUNTIME_PROBE="${SCRIPT_DIR}/qemu_runtime_probe.py"
TIMEOUT="${TIMEOUT:-180}"
CMD_TIMEOUT="${CMD_TIMEOUT:-60}"
SMOKE_DISK_IMAGE="${SMOKE_DISK_IMAGE:-/tmp/minix-i386-smoke.img}"

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

run_build_gate() {
  log_info "Test: i386 distribution artifacts"
  if [[ -x "${DESTDIR}/boot/minix/.temp/kernel" ]]; then
    log_pass "boot kernel present"
  else
    log_fail "missing ${DESTDIR}/boot/minix/.temp/kernel"
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
}

run_qemu_gate() {
  if [[ ! -x "${QEMU_SCRIPT}" ]]; then
    log_skip "qemu-i386.sh missing"
    return 0
  fi
  if ! command -v qemu-system-i386 >/dev/null 2>&1; then
    log_skip "qemu-system-i386 not installed"
    return 0
  fi
  if [[ ! -f "${SMOKE_DISK_IMAGE}" ]]; then
    log_info "Creating smoke disk: ${SMOKE_DISK_IMAGE}"
    mkdir -p "$(dirname "${SMOKE_DISK_IMAGE}")"
    OBJDIR="${OBJDIR}" DESTDIR="${DESTDIR}" OUTPUT="${SMOKE_DISK_IMAGE}" \
      "${MINIX_ROOT}/minix/releasetools/i386/mkdisk.sh" \
      -d "${OBJDIR}" -o "${SMOKE_DISK_IMAGE}" -D "${DESTDIR}"
  fi
  if [[ ! -f "${RUNTIME_PROBE}" ]]; then
    log_skip "runtime probe missing"
    return 0
  fi

  log_info "Test: QEMU i386 boot smoke"
  if python3 "${RUNTIME_PROBE}" \
    --qemu-script "${QEMU_SCRIPT}" \
    --kernel "${DESTDIR}/boot/minix/.temp/kernel" \
    --destdir "${DESTDIR}" \
    --disk "${SMOKE_DISK_IMAGE}" \
    --timeout "${TIMEOUT}" \
    --cmd-timeout "${CMD_TIMEOUT}" \
    --cmd 'login_detect=/bin/echo minix_i386_smoke_ok'; then
    log_pass "QEMU i386 boot smoke"
  else
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
      log_skip "QEMU i386 boot smoke"
    else
      log_fail "QEMU i386 boot smoke"
    fi
  fi
}

TARGET="${1:-all}"
case "${TARGET}" in
  build) run_build_gate ;;
  gate) run_build_gate; run_qemu_gate ;;
  qemu) run_qemu_gate ;;
  all)
    run_build_gate
    run_qemu_gate
    ;;
  *)
    echo "Usage: $0 [build|gate|qemu|all]" >&2
    exit 1
    ;;
esac

echo "[i386-tests] summary: passed=${passed} failed=${failed} skipped=${skipped}"
if [[ "$failed" -ne 0 ]]; then
  exit 1
fi
if [[ "$passed" -eq 0 ]]; then
  exit 2
fi
