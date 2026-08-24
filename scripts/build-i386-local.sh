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
GUEST_PATCH_SCRIPT="${REPO_ROOT}/toolchain/patches/riscv64-guest/scripts/apply-guest-dist-patches.sh"

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
  MKPCI=yes HOST_CFLAGS="-O -fcommon ${HARDENING_OFF}" \
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

prepare_libstdcxx_guest() {
  local destdir_root="${REPO_ROOT}/${OBJDIR}/destdir.${ARCH}"
  local src_include_root="${REPO_ROOT}/external/gpl3/gcc/dist/libstdc++-v3/include"
  local functexcept_src="${REPO_ROOT}/external/gpl3/gcc/dist/libstdc++-v3/src/c++11/functexcept.cc"

  [[ -d "${src_include_root}" ]] || {
    echo "[i386] ERROR: missing libstdc++ include tree: ${src_include_root}" >&2
    exit 1
  }
  mkdir -p "${destdir_root}/usr/include/gcc-4.8" "${destdir_root}/usr/include/g++"
  while IFS= read -r -d '' src_dir; do
    mkdir -p "${destdir_root}/usr/include/g++/${src_dir#${src_include_root}/}"
  done < <(find "${src_include_root}" -mindepth 1 -type d -print0)

  rm -rf "${REPO_ROOT}/${OBJDIR}/minix/drivers/storage/ramdisk"
  rm -rf "${REPO_ROOT}/${OBJDIR}/external/gpl3/gcc/lib/libstdc++-v3"
  rm -f \
    "${destdir_root}/usr/lib/libstdc++.a" \
    "${destdir_root}/usr/lib/libstdc++_pic.a" \
    "${destdir_root}/usr/include/g++/bits/c++config.h"
  rm -rf "${destdir_root}/usr/include/c++"
  rm -f \
    "${destdir_root}/usr/lib/libc++.a" \
    "${destdir_root}/usr/lib/libc++_pic.a"

  sanitize_cxxconfig() {
    local cfg="$1"
    [[ -f "${cfg}" ]] || return 0
    sed -i -E \
      's@^#define[[:space:]]+_GLIBCXX_HAS_GTHREADS([[:space:]]+.*)?$@/* #undef _GLIBCXX_HAS_GTHREADS */@' \
      "${cfg}"
  }

  sanitize_cxxconfig "${REPO_ROOT}/external/gpl3/gcc/lib/libstdc++-v3/arch/i386/c++config.h"
  if [[ -d "${destdir_root}/usr/include/g++" ]]; then
    while IFS= read -r -d '' cfg; do
      sanitize_cxxconfig "${cfg}"
    done < <(find "${destdir_root}/usr/include/g++" -type f -name 'c++config.h' -print0)
  fi

  [[ -x "${GUEST_PATCH_SCRIPT}" ]] || {
    echo "[i386] ERROR: missing ${GUEST_PATCH_SCRIPT}" >&2
    exit 1
  }
  bash "${GUEST_PATCH_SCRIPT}"

  [[ -f "${functexcept_src}" ]] || {
    echo "[i386] ERROR: missing ${functexcept_src}" >&2
    exit 1
  }
  if ! grep -q '__throw_system_error(__i);' "${functexcept_src}"; then
    echo "[i386] ERROR: no MINIX future fallback in ${functexcept_src}" >&2
    exit 1
  fi
  echo "[i386] libstdc++ guest prep: functexcept no-future profile ok"
}

run_distribution() {
  local tooldir
  tooldir="$(pick_tooldir)" || {
    echo "[i386] ERROR: run tools first" >&2
    exit 1
  }

  prepare_libstdcxx_guest

  echo "[i386] building distribution (jobs=${DIST_JOBS}) -> ${LOG_DIR}/distribution.log"
  export MAKEFLAGS="-j${DIST_JOBS}"
  MKPCI=yes HOST_CFLAGS="-O -fcommon ${HARDENING_OFF}" \
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

  verify_native_payload "${destdir}"
  verify_libstdcxx_profile "${destdir}" "${tooldir}"
}

verify_native_payload() {
  local root="$1" entry
  local missing=()
  for bin in cc c++ cpp as ld ar ranlib nm objcopy objdump readelf strip; do
    [[ -x "${root}/usr/bin/${bin}" || ( "${bin}" == cc && -x "${root}/usr/bin/gcc" ) || ( "${bin}" == c++ && -x "${root}/usr/bin/g++" ) || ( "${bin}" == cpp && -x "${root}/usr/bin/gcpp" ) ]] || missing+=("usr/bin/${bin}")
  done
  for entry in usr/lib/libgcc.a usr/lib/libgcc_eh.a usr/lib/libstdc++.a usr/include/stdio.h usr/include/g++/bits/c++config.h; do
    [[ -e "${root}/${entry}" ]] || missing+=("${entry}")
  done
  [[ ${#missing[@]} -eq 0 ]] || { echo "[i386] ERROR: native payload missing: ${missing[*]}" >&2; exit 1; }
  echo "[i386] native payload check PASS"
}

verify_libstdcxx_profile() {
  local root="$1" tooldir="$2" tmp
  local ar="${tooldir}/bin/i586-elf32-minix-ar"
  local nm="${tooldir}/bin/i586-elf32-minix-nm"
  local lib="${root}/usr/lib/libstdc++.a"
  [[ -x "${ar}" && -x "${nm}" && -f "${lib}" ]] || { echo "[i386] ERROR: libstdc++ profile inputs missing" >&2; exit 1; }
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN
  (cd "${tmp}" && "${ar}" x "${lib}" functexcept.o && "${nm}" -u functexcept.o > undef.txt)
  if grep -Eq 'future_category|future_error' "${tmp}/undef.txt"; then
    echo "[i386] ERROR: libstdc++ functexcept.o references future_*" >&2
    cat "${tmp}/undef.txt" >&2
    exit 1
  fi
  echo "[i386] libstdc++ profile check PASS"
}

run_image() {
  local objdir="${OBJDIR}"
  case "${objdir}" in
  /*) ;;
  *) objdir="${REPO_ROOT}/${objdir}" ;;
  esac
  echo "[i386] mkdisk -> ${IMAGE_PATH}"
  OBJDIR="${objdir}" DESTDIR="${objdir}/destdir.${ARCH}" \
    OUTPUT="${IMAGE_PATH}" \
    minix/releasetools/i386/mkdisk.sh -d "${objdir}" -o "${IMAGE_PATH}"
  echo "[i386] IMAGE=${IMAGE_PATH}"
}

run_qemu() {
  local image="${IMAGE_PATH}"
  local objdir="${OBJDIR}"
  [[ -f "${image}" ]] || {
    echo "[i386] ERROR: disk image missing: ${image} (run image first)" >&2
    exit 1
  }
  case "${objdir}" in
  /*) ;;
  *) objdir="${REPO_ROOT}/${objdir}" ;;
  esac
  OBJDIR="${objdir}" \
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
