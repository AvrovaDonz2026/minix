#!/bin/bash
#
# Build modern LLVM/clang via CMake for MINIX cross-toolchain.
#
# Produces host clang with RISC-V and x86 codegen backends.  Installs into
# TOOLDIR with riscv64-elf32-minix-* and i586-elf32-minix-* wrappers
# expected by llvm_toolchain_gate.sh.
#
# Environment:
#   TOOLDIR          install prefix (required)
#   LLVM_VERSION     default 18.1.8
#   LLVM_JOBS        parallel jobs (default: nproc)
#   LLVM_SRCDIR      override source tree
#   LLVM_BUILDDIR    override build directory
#   LLVM_SKIP_FETCH  set non-empty to skip download
#

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

LLVM_VERSION="${LLVM_VERSION:-18.1.8}"
LLVM_JOBS="${LLVM_JOBS:-$(nproc 2>/dev/null || echo 4)}"
LLVM_TARBALL="llvm-project-${LLVM_VERSION}.src.tar.xz"
LLVM_URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/${LLVM_TARBALL}"

LLVM_VENDOR="${REPO_ROOT}/external/apache2/llvm-cmake"
LLVM_SRCDIR="${LLVM_SRCDIR:-${LLVM_VENDOR}/dist/llvm-project-${LLVM_VERSION}.src}"
LLVM_BUILDDIR="${LLVM_BUILDDIR:-${LLVM_VENDOR}/build/llvm-${LLVM_VERSION}}"
PATCH_DIR="${REPO_ROOT}/external/apache2/llvm-cmake/patches"

log() { echo "[llvm-cmake] $*"; }
die() { echo "[llvm-cmake] ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

fetch_sources() {
  if [ -n "${LLVM_SKIP_FETCH:-}" ] && [ -d "${LLVM_SRCDIR}/llvm" ]; then
    log "using existing sources at ${LLVM_SRCDIR}"
    return 0
  fi

  mkdir -p "${LLVM_VENDOR}/dist"
  local archive="${LLVM_VENDOR}/dist/${LLVM_TARBALL}"

  if [ ! -f "${archive}" ]; then
    log "downloading ${LLVM_URL}"
    require_cmd curl
    curl -fL --retry 3 -o "${archive}" "${LLVM_URL}"
  fi

  if [ ! -d "${LLVM_SRCDIR}/llvm" ]; then
    log "extracting ${archive}"
    require_cmd tar
    tar -C "${LLVM_VENDOR}/dist" -xf "${archive}"
  fi
}

apply_patches() {
  local stamp="${LLVM_SRCDIR}/.minix-patches-applied"
  if [ -f "${stamp}" ]; then
    log "patches already applied"
    return 0
  fi

  if [ ! -d "${PATCH_DIR}" ]; then
  log "no patch directory ${PATCH_DIR}; skipping"
    touch "${stamp}"
    return 0
  fi

  local patch
  shopt -s nullglob
  for patch in "${PATCH_DIR}"/*.patch; do
    log "applying $(basename "${patch}")"
    patch -p1 -d "${LLVM_SRCDIR}" < "${patch}"
  done
  shopt -u nullglob
  touch "${stamp}"
}

build_llvm() {
  [ -n "${TOOLDIR:-}" ] || die "TOOLDIR is not set"

  require_cmd cmake
  require_cmd ninja

  mkdir -p "${LLVM_BUILDDIR}" "${TOOLDIR}/bin" "${TOOLDIR}/lib"

  # build.sh exports DESTDIR for the target rootfs; host LLVM must install
  # into TOOLDIR only (DESTDIR would prefix CMAKE_INSTALL_PREFIX).
  local saved_destdir="${DESTDIR:-}"
  DESTDIR=
  export DESTDIR

  log "configuring LLVM ${LLVM_VERSION} (jobs=${LLVM_JOBS})"
  export LIBRARY_PATH="${LIBRARY_PATH:-/usr/lib/gcc/$(gcc -dumpmachine)/$(gcc -dumpversion):/usr/lib/$(gcc -dumpmachine)}"
  cmake -G Ninja -S "${LLVM_SRCDIR}/llvm" -B "${LLVM_BUILDDIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${TOOLDIR}/llvm-${LLVM_VERSION}" \
    -DCMAKE_CXX_COMPILER="${CXX:-g++}" \
    -DCMAKE_C_COMPILER="${CC:-gcc}" \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_TARGETS_TO_BUILD="RISCV;X86" \
    -DLLVM_ENABLE_TERMINFO=OFF \
    -DLLVM_ENABLE_ZLIB=ON \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
    -DCLANG_ENABLE_ARCMT=OFF \
    -DLLVM_INSTALL_UTILS=ON

  log "building"
  ninja -C "${LLVM_BUILDDIR}" -j"${LLVM_JOBS}" clang lld

  log "installing to ${TOOLDIR}/llvm-${LLVM_VERSION}"
  DESTDIR= ninja -C "${LLVM_BUILDDIR}" install

  install_wrappers

  if [ -n "${saved_destdir}" ]; then
    DESTDIR="${saved_destdir}"
    export DESTDIR
  else
    unset DESTDIR
  fi
}

install_wrappers() {
  local prefix="${TOOLDIR}/llvm-${LLVM_VERSION}"
  local bindir="${TOOLDIR}/bin"
  local clang="${prefix}/bin/clang"
  local clangxx="${prefix}/bin/clang++"
  local clangcpp="${prefix}/bin/clang-cpp"
  local lld="${prefix}/bin/ld.lld"
  local triple

  [ -x "${clang}" ] || die "installed clang not found: ${clang}"

  mkdir -p "${bindir}"

  write_wrapper() {
    local dest="$1"
    local bin="$2"
    local triple_target="$3"
    cat > "${dest}" <<EOF
#!/bin/sh
exec "${bin}" --target=${triple_target} \\
  -D__minix=3 -D__minix__=3 -D__Minix__=3 "\$@"
EOF
    chmod 755 "${dest}"
  }

  for triple in riscv64-elf32-minix i586-elf32-minix; do
    write_wrapper "${bindir}/${triple}-clang" "${clang}" "${triple}"
    write_wrapper "${bindir}/${triple}-clang++" "${clangxx}" "${triple}"
    write_wrapper "${bindir}/${triple}-clang-cpp" "${clangcpp}" "${triple}"
    if [ -x "${lld}" ]; then
      ln -sf "${lld}" "${bindir}/${triple}-ld"
    fi
  done

  for tool in llvm-tblgen clang-tblgen; do
    if [ -x "${prefix}/bin/${tool}" ]; then
      ln -sf "${prefix}/bin/${tool}" "${bindir}/nb${tool}-cmake"
    fi
  done

  log "installed wrappers:"
  ls -l "${bindir}/riscv64-elf32-minix-clang"* \
    "${bindir}/i586-elf32-minix-clang"* \
    "${bindir}/nbllvm-tblgen-cmake" 2>/dev/null || true
  "${bindir}/riscv64-elf32-minix-clang" --version | head -n 3
  "${bindir}/i586-elf32-minix-clang" --version | head -n 3
}

install_destdir() {
  [ -n "${DESTDIR:-}" ] || return 0
  local prefix="${TOOLDIR}/llvm-${LLVM_VERSION}"
  local root="${DESTDIR}"
  local clang="${prefix}/bin/clang"
  local clangxx="${prefix}/bin/clang++"
  local clangcpp="${prefix}/bin/clang-cpp"

  [ -x "${clang}" ] || die "cannot install DESTDIR: clang missing"

  mkdir -p "${root}/usr/bin"

  write_guest_wrapper() {
    local dest="$1"
    local bin="$2"
    cat > "${dest}" <<EOF
#!/bin/sh
exec "${bin}" --target=riscv64-elf32-minix \\
  -D__minix=3 -D__minix__=3 -D__Minix__=3 "\$@"
EOF
    chmod 755 "${dest}"
  }

  write_guest_wrapper "${root}/usr/bin/clang" "${clang}"
  write_guest_wrapper "${root}/usr/bin/clang++" "${clangxx}"
  write_guest_wrapper "${root}/usr/bin/clang-cpp" "${clangcpp}"

  log "installed guest clang wrappers under ${root}/usr/bin"
}

main() {
  log "LLVM ${LLVM_VERSION} CMake build for MINIX (riscv64 + i586)"
  log "TOOLDIR=${TOOLDIR:-unset} DESTDIR=${DESTDIR:-unset}"

  if [ -n "${LLVM_INSTALL_ONLY:-}" ]; then
    install_destdir
    log "DESTDIR install only; done"
    return 0
  fi

  fetch_sources
  apply_patches
  build_llvm

  if [ -n "${LLVM_DESTDIR_INSTALL:-}" ] && [ -n "${DESTDIR:-}" ]; then
    install_destdir
  fi

  log "done"
}

main "$@"
