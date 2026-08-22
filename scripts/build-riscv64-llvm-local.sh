#!/bin/bash
#
# Local MINIX riscv64 LLVM packaging build (mirrors packaging-riscv64-llvm.yml).
#
# Usage:
#   ./scripts/build-riscv64-llvm-local.sh tools
#   ./scripts/build-riscv64-llvm-local.sh distribution
#   ./scripts/build-riscv64-llvm-local.sh all
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

TARGET="${1:-all}"
OBJDIR="${OBJDIR:-obj.intrgcc}"
MACHINE="${MACHINE:-evbriscv64}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
DIST_JOBS="${DIST_JOBS:-1}"  # parallel cross-as aborts on Ubuntu hosts
LOG_DIR="${LOG_DIR:-/tmp/minix-riscv64-llvm}"

mkdir -p "${LOG_DIR}"

# Ubuntu cloud images default cc -> clang; host tool configure (gmp, etc.) needs gcc.
export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
export HOST_CC=gcc
export HOST_CXX=g++
export LIBRARY_PATH="${LIBRARY_PATH:-/usr/lib/gcc/$(gcc -dumpmachine)/$(gcc -dumpversion):/usr/lib/$(gcc -dumpmachine)}"

HARDENING_OFF="-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 -fno-stack-protector"
COMMON_FLAGS=(
  -m "${MACHINE}"
  -O "${OBJDIR}"
  -V AVAILABLE_COMPILER=gcc
  -V ACTIVE_CC=gcc
  -V ACTIVE_CPP=gcc
  -V ACTIVE_CXX=gcc
  -V ACTIVE_OBJC=gcc
  -V RISCV_ARCH_FLAGS='-march=RV64IMAFD -mcmodel=medany'
  -V NOGCCERROR=yes
  -V MKGCC=yes
  -V MKGCCCMDS=yes
  -V MKLLVM=yes
  -V MKLLVM_CMAKE=yes
  -V MKLLVMCMDS=yes
  -V HAVE_LIBGCC=yes
  -V HAVE_LIBGCC_EH=yes
  -V MKCXX=yes
  -V MKLIBSTDCXX=yes
  -V MKLIBCXX=no
  -V MKLIBOBJC=no
  -V MKLIBGOMP=no
  -V MKATF=no
  -V USE_PCI=no
  -V CHECKFLIST_FLAGS='-m -e'
)

run_tools() {
  echo "[local] cleaning stale tool objects under ${OBJDIR}"
  rm -rf "${OBJDIR}/tooldir."* "${OBJDIR}/tools"

  echo "[local] building tools -> ${LOG_DIR}/tools.log"
  MKPCI=no HOST_CFLAGS="-O -fcommon ${HARDENING_OFF}" \
    HOST_CXXFLAGS="-O -std=c++11 -fno-rtti -fno-exceptions ${HARDENING_OFF}" \
    HAVE_GOLD=no MKLLVM=yes \
    ./build.sh -U -j"${JOBS}" "${COMMON_FLAGS[@]}" tools \
    2>&1 | tee "${LOG_DIR}/tools.log"

  local tooldir
  tooldir="$(ls -d "${OBJDIR}"/tooldir.* 2>/dev/null | head -1)"
  [[ -x "${tooldir}/bin/riscv64-elf32-minix-clang" ]] || {
    echo "[local] ERROR: missing ${tooldir}/bin/riscv64-elf32-minix-clang" >&2
    exit 1
  }
  echo "[local] TOOLDIR=${tooldir}"
  TOOLDIR="${tooldir}" ./minix/tests/riscv64/llvm_toolchain_gate.sh \
    --mode host --require host --tooldir "${tooldir}"
}

run_distribution() {
  echo "[local] building distribution (jobs=${DIST_JOBS}) -> ${LOG_DIR}/distribution.log"
  MKPCI=no HOST_CFLAGS="-O -fcommon ${HARDENING_OFF}" \
    HOST_CXXFLAGS="-O -std=c++11 -fno-rtti -fno-exceptions ${HARDENING_OFF}" \
    HAVE_GOLD=no MKLLVM=yes \
    ./build.sh -U -u -V MKUPDATE=yes -j"${DIST_JOBS}" "${COMMON_FLAGS[@]}" distribution \
    2>&1 | tee "${LOG_DIR}/distribution.log"
}

case "${TARGET}" in
  tools) run_tools ;;
  distribution) run_distribution ;;
  all)
    run_tools
    run_distribution
    ;;
  *)
    echo "usage: $0 [tools|distribution|all]" >&2
    exit 1
    ;;
esac

echo "[local] done (${TARGET})"
