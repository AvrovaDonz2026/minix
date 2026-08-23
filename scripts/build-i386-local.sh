#!/bin/bash
#
# Local MINIX i386 distribution build + QEMU smoke helpers.
#
# Usage:
#   ./scripts/build-i386-local.sh tools
#   ./scripts/build-i386-local.sh distribution
#   ./scripts/build-i386-local.sh image
#   ./scripts/build-i386-local.sh qemu
#   ./scripts/build-i386-local.sh verify
#   ./scripts/build-i386-local.sh all
#
# Environment:
#   OBJDIR=obj.i386
#   DIST_JOBS / TOOLS_CPU_COUNT / WORLD_CPU_COUNT
#   IMAGE_PATH=/tmp/minix-i386.img
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

TARGET="${1:-all}"
OBJDIR="${OBJDIR:-obj.i386}"
MACHINE="${MACHINE:-i386}"
ARCH="${ARCH:-i386}"
VISIBLE_CPUS="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
JOBS="${JOBS:-${TOOLS_CPU_COUNT:-${VISIBLE_CPUS}}}"
if (( JOBS > 8 )) && [[ -z "${TOOLS_CPU_COUNT:-}" ]]; then
  JOBS=8
fi
DIST_JOBS="${DIST_JOBS:-${WORLD_CPU_COUNT:-${VISIBLE_CPUS}}}"
LOG_DIR="${LOG_DIR:-/tmp/minix-i386}"
IMAGE_PATH="${IMAGE_PATH:-${LOG_DIR}/minix-i386.img}"

mkdir -p "${LOG_DIR}"

export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
export HOST_CC=gcc
export HOST_CXX=g++

HARDENING_OFF="-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 -fno-stack-protector"
COMMON_FLAGS=(
  -m "${MACHINE}"
  -O "${OBJDIR}"
  -V AVAILABLE_COMPILER=gcc
  -V ACTIVE_CC=gcc
  -V ACTIVE_CPP=gcc
  -V ACTIVE_CXX=gcc
  -V ACTIVE_OBJC=gcc
  -V NOGCCERROR=yes
  -V MKGCC=yes
  -V MKGCCCMDS=yes
  -V MKLLVM=no
  -V MKLLVM_CMAKE=no
  -V MKLLVMCMDS=no
  -V HAVE_LIBGCC=yes
  -V HAVE_LIBGCC_EH=yes
  -V MKCXX=yes
  -V MKLIBSTDCXX=yes
  -V MKLIBCXX=no
  -V MKLIBOBJC=no
  -V MKLIBGOMP=no
  -V MKATF=no
  -V CHECKFLIST_FLAGS='-m -e'
)

pick_tooldir() {
  local tooldir="" d mt best=0
  for d in "${OBJDIR}"/tooldir.*; do
    [[ -d "${d}" ]] || continue
    [[ -x "${d}/bin/nbmake" ]] || continue
    [[ -x "${d}/bin/i586-elf32-minix-gcc" ]] || continue
    mt="$(stat -c %Y "${d}" 2>/dev/null || echo 0)"
    if (( mt >= best )); then
      best="${mt}"
      tooldir="${d}"
    fi
  done
  [[ -n "${tooldir}" ]] || return 1
  printf '%s' "${tooldir}"
}

run_tools() {
  echo "[i386] cleaning stale tool objects under ${OBJDIR}"
  rm -rf "${OBJDIR}/tooldir."* "${OBJDIR}/tools"

  echo "[i386] building tools -> ${LOG_DIR}/tools.log"
  MKPCI=no HOST_CFLAGS="-O -fcommon ${HARDENING_OFF}" \
    HOST_CXXFLAGS="-O -std=c++11 -fno-rtti -fno-exceptions ${HARDENING_OFF}" \
    HAVE_GOLD=no MKLLVM=no \
    ./build.sh -U -j"${JOBS}" "${COMMON_FLAGS[@]}" tools \
    2>&1 | tee "${LOG_DIR}/tools.log"

  local tooldir
  tooldir="$(pick_tooldir)" || {
    echo "[i386] ERROR: no usable TOOLDIR under ${OBJDIR}" >&2
    exit 1
  }
  echo "[i386] TOOLDIR=${tooldir}"
}

run_distribution() {
  local tooldir
  tooldir="$(pick_tooldir)" || {
    echo "[i386] ERROR: run tools first" >&2
    exit 1
  }

  echo "[i386] building distribution (jobs=${DIST_JOBS}) -> ${LOG_DIR}/distribution.log"
  export MAKEFLAGS="-j${DIST_JOBS}"
  MKPCI=no HOST_CFLAGS="-O -fcommon ${HARDENING_OFF}" \
    HOST_CXXFLAGS="-O -std=c++11 -fno-rtti -fno-exceptions ${HARDENING_OFF}" \
    HAVE_GOLD=no MKLLVM=no \
    ./build.sh -U -u -V MKUPDATE=yes -j"${DIST_JOBS}" "${COMMON_FLAGS[@]}" distribution \
    2>&1 | tee "${LOG_DIR}/distribution.log"

  local destdir="${REPO_ROOT}/${OBJDIR}/destdir.${ARCH}"
  local moddir="${destdir}/boot/minix/.temp"
  [[ -x "${moddir}/kernel" ]] || {
    echo "[i386] ERROR: missing ${moddir}/kernel after distribution" >&2
    exit 1
  }
  echo "[i386] DESTDIR=${destdir}"
  echo "[i386] boot modules in ${moddir}"
}

run_image() {
  echo "[i386] mkdisk -> ${IMAGE_PATH}"
  OBJDIR="${OBJDIR}" DESTDIR="${REPO_ROOT}/${OBJDIR}/destdir.${ARCH}" \
    OUTPUT="${IMAGE_PATH}" \
    minix/releasetools/i386/mkdisk.sh -d "${REPO_ROOT}/${OBJDIR}" -o "${IMAGE_PATH}"
  echo "[i386] IMAGE=${IMAGE_PATH}"
}

run_qemu() {
  local image="${IMAGE_PATH}"
  [[ -f "${image}" ]] || {
    echo "[i386] ERROR: disk image missing: ${image} (run image first)" >&2
    exit 1
  }
  OBJDIR="${REPO_ROOT}/${OBJDIR}" \
    minix/scripts/qemu-i386.sh -i "${image}" -m 256M
}

run_verify() {
  export OBJDIR="${REPO_ROOT}/${OBJDIR}"
  export KERNEL="${OBJDIR}/minix/kernel/kernel"
  export DESTDIR="${OBJDIR}/destdir.${ARCH}"
  export SMOKE_DISK_IMAGE="${IMAGE_PATH}"
  export TOOLDIR
  TOOLDIR="$(pick_tooldir)"
  export TOOLDIR

  run_image
  ./minix/tests/i386/run_tests.sh gate
}

case "${TARGET}" in
  tools) run_tools ;;
  distribution|dist) run_distribution ;;
  image) run_image ;;
  qemu) run_qemu ;;
  verify) run_verify ;;
  all)
    run_tools
    run_distribution
    run_verify
    ;;
  *)
    echo "Usage: $0 [tools|distribution|image|qemu|verify|all]" >&2
    exit 1
    ;;
esac
