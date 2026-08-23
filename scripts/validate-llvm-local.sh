#!/bin/bash
#
# Local LLVM validation (mirrors CI gates without full distribution).
# Run from repo root after tools build completes.
#
# Usage:
#   ./scripts/validate-llvm-local.sh [host|link|all]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

MODE="${1:-all}"
OBJDIR="${OBJDIR:-obj.intrgcc}"
MACHINE="${MACHINE:-evbriscv64}"

log() { echo "[validate] $*"; }
die() { echo "[validate] ERROR: $*" >&2; exit 1; }

pick_tooldir() {
  if [[ -n "${TOOLDIR:-}" && -d "${TOOLDIR}" ]]; then
    if [[ -x "${TOOLDIR}/bin/nbmake" || -x "${TOOLDIR}/bin/riscv64-elf32-minix-clang" ]]; then
      echo "${TOOLDIR}"
      return 0
    fi
  fi
  local best="" best_mt=0 d mt
  for d in "${OBJDIR}"/tooldir.*; do
    [[ -d "$d" ]] || continue
    [[ -x "$d/bin/nbmake" ]] || continue
    mt=$(stat -c %Y "$d" 2>/dev/null || echo 0)
    if [[ -z "$best" || "$mt" -ge "$best_mt" ]]; then
      best="$d"
      best_mt="$mt"
    fi
  done
  [[ -n "$best" ]] || die "no tooldir under ${OBJDIR}"
  echo "$best"
}

validate_host_gate() {
  local tooldir
  tooldir="$(pick_tooldir)"
  log "host gate with TOOLDIR=${tooldir}"
  [[ -x "${tooldir}/bin/riscv64-elf32-minix-clang" ]] || \
    die "missing riscv64-elf32-minix-clang (run tools build with MKLLVM_CMAKE=yes)"
  [[ -x "${tooldir}/bin/i586-elf32-minix-clang" ]] || \
    die "missing i586-elf32-minix-clang (run tools build with MKLLVM_CMAKE=yes)"
  ./minix/tests/riscv64/llvm_toolchain_gate.sh \
    --mode host \
    --require host \
    --tooldir "${tooldir}"
  log "host gate PASS"
}

destdir_ready_for_link() {
  local destdir="$1"
  [[ -f "${destdir}/usr/lib/libstdc++.a" ]] || return 1
  [[ -f "${destdir}/usr/lib/crt0.o" || -f "${destdir}/usr/lib/crt1.o" ]] || return 1
  [[ -d "${destdir}/usr/include/g++" || -d "${destdir}/usr/include/c++" ]] || return 1
  return 0
}

validate_link_mk() {
  local tooldir cxx ld destdir cxxinc
  tooldir="$(pick_tooldir)"
  cxx="${tooldir}/bin/riscv64-elf32-minix-g++"
  ld="${tooldir}/bin/riscv64-elf32-minix-ld"
  destdir="${REPO_ROOT}/${OBJDIR}/destdir.${MACHINE}"

  [[ -x "$cxx" ]] || die "missing cross g++"
  [[ -x "$ld" ]] || die "missing cross ld"

  if ! destdir_ready_for_link "${destdir}"; then
    log "link.mk probe SKIP: destdir missing libstdc++/crt (run distribution first)"
    return 0
  fi

  if [[ -d "${destdir}/usr/include/g++" ]]; then
    cxxinc="${destdir}/usr/include/g++"
  else
    cxxinc="${destdir}/usr/include/c++"
  fi

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  cat >"${tmp}/test.cc" <<'EOF'
#include <string>
int main() { std::string s = "ok"; return s.size() == 2 ? 0 : 1; }
EOF

  log "link.mk probe: guest-style link with -lstdc++ (MKLIBCXX=no)"
  if ! "$cxx" --sysroot="${destdir}" \
      -isystem"${cxxinc}" \
      -march=RV64IMAFD -mcmodel=medany \
      -fno-use-linker-plugin \
      "${tmp}/test.cc" -o "${tmp}/test.elf" \
      -lstdc++ 2>"${tmp}/err"; then
    cat "${tmp}/err" >&2
    die "cross link with -lstdc++ failed"
  fi

  if ! "$ld" -r "${tmp}/test.elf" -o /dev/null 2>/dev/null; then
    file "${tmp}/test.elf"
  fi
  log "link.mk probe PASS"
}

case "$MODE" in
  host) validate_host_gate ;;
  link) validate_link_mk ;;
  all)
    validate_host_gate
    validate_link_mk
    ;;
  *)
    die "unknown mode: $MODE (use host|link|all)"
    ;;
esac

log "done ($MODE)"
