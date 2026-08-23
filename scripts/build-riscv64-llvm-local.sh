#!/bin/bash
#
# Local MINIX riscv64 LLVM packaging build (mirrors packaging-riscv64-llvm.yml).
#
# Usage:
#   ./scripts/build-riscv64-llvm-local.sh tools
#   ./scripts/build-riscv64-llvm-local.sh distribution
#   ./scripts/build-riscv64-llvm-local.sh all
#   ./scripts/build-riscv64-llvm-local.sh servers   # vm+kernel after tree edits
#   ./scripts/build-riscv64-llvm-local.sh image     # mkdisk only
#   DIST_JOBS=<n>         distribution parallelism (default: nproc)
#   TOOLS_CPU_COUNT=<n>    cap tools -j (default: min(nproc, 8))
#   WORLD_CPU_COUNT=<n>    override distribution -j
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

TARGET="${1:-all}"
OBJDIR="${OBJDIR:-obj.intrgcc}"
MACHINE="${MACHINE:-evbriscv64}"
VISIBLE_CPUS="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
# Mirror packaging-riscv64-llvm.yml: tools capped, world/distribution uses all CPUs.
JOBS="${JOBS:-${TOOLS_CPU_COUNT:-${VISIBLE_CPUS}}}"
if (( JOBS > 8 )) && [[ -z "${TOOLS_CPU_COUNT:-}" ]]; then
  JOBS=8
fi
DIST_JOBS="${DIST_JOBS:-${WORLD_CPU_COUNT:-${VISIBLE_CPUS}}}"
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
  -V MKPIC=yes
  -V MKPICLIB=yes
  -V MKPICINSTALL=yes
  -V CHECKFLIST_FLAGS='-m -e'
)

GUEST_PATCH_SCRIPT="${REPO_ROOT}/toolchain/patches/riscv64-guest/scripts/apply-guest-dist-patches.sh"

install_cross_as_flock_wrapper() {
  local tooldir="$1"
  local lock="/tmp/minix-cross-as-${OBJDIR//\//-}.lock"
  local as

  wrap_one_as() {
    local as_abs
    as="$1"
    [[ -e "${as}" || -x "${as}.real" ]] || return 0
    as_abs="$(cd "$(dirname "${as}")" && pwd)/$(basename "${as}")"
    [[ -x "${as_abs}.real" ]] || mv "${as_abs}" "${as_abs}.real"
    cat > "${as_abs}" <<EOF
#!/bin/bash
exec flock -w 600 ${lock} ${as_abs}.real "\$@"
EOF
    chmod +x "${as_abs}"
  }

  # nbmake may invoke either path; serialize both under one lock.
  wrap_one_as "${tooldir}/riscv64-elf32-minix/bin/as"
  wrap_one_as "${tooldir}/bin/riscv64-elf32-minix-as"
}

install_cross_as_flock_wrapper_all() {
  local tooldir
  for tooldir in "${OBJDIR}"/tooldir.*; do
    [[ -d "${tooldir}" ]] || continue
    install_cross_as_flock_wrapper "${tooldir}"
  done
}

apply_guest_dist_patches() {
  [[ -x "${GUEST_PATCH_SCRIPT}" ]] || {
    echo "[local] ERROR: missing ${GUEST_PATCH_SCRIPT}" >&2
    exit 1
  }
  bash "${GUEST_PATCH_SCRIPT}"
}

prepare_libstdcxx_guest() {
  local destdir_root="${REPO_ROOT}/${OBJDIR}/destdir.evbriscv64"
  local functexcept_src="${REPO_ROOT}/external/gpl3/gcc/dist/libstdc++-v3/src/c++11/functexcept.cc"

  strip_libcxx_from_destdir

  sanitize_cxxconfig() {
    local cfg="$1"
    [[ -f "${cfg}" ]] || return 0
    sed -i -E \
      's@^#define[[:space:]]+_GLIBCXX_HAS_GTHREADS([[:space:]]+.*)?$@/* #undef _GLIBCXX_HAS_GTHREADS */@' \
      "${cfg}"
  }

  sanitize_cxxconfig "${REPO_ROOT}/external/gpl3/gcc/lib/libstdc++-v3/arch/riscv64/c++config.h"
  if [[ -d "${destdir_root}/usr/include/g++" ]]; then
    while IFS= read -r -d '' cfg; do
      sanitize_cxxconfig "${cfg}"
    done < <(find "${destdir_root}/usr/include/g++" -type f -name 'c++config.h' -print0)
  fi

  apply_guest_dist_patches

  [[ -f "${functexcept_src}" ]] || {
    echo "[local] ERROR: missing ${functexcept_src}" >&2
    exit 1
  }
  if ! grep -q '__throw_system_error(__i);' "${functexcept_src}"; then
    echo "[local] ERROR: no MINIX future fallback in ${functexcept_src}" >&2
    exit 1
  fi
  echo "[local] libstdc++ guest prep: functexcept no-future profile ok"
}

strip_libcxx_from_destdir() {
  local destdir_root="${REPO_ROOT}/${OBJDIR}/destdir.evbriscv64"
  rm -rf "${destdir_root}/usr/include/c++"
  rm -f \
    "${destdir_root}/usr/lib/libc++.a" \
    "${destdir_root}/usr/lib/libc++_pic.a"
}

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
  install_cross_as_flock_wrapper "${tooldir}"
  TOOLDIR="${tooldir}" ./minix/tests/riscv64/llvm_toolchain_gate.sh \
    --mode host --require host --tooldir "${tooldir}"
}

run_distribution() {
  local tooldir
  tooldir="$(ls -d "${OBJDIR}"/tooldir.* 2>/dev/null | head -1)"
  [[ -n "${tooldir}" ]] && install_cross_as_flock_wrapper "${tooldir}"

  prepare_libstdcxx_guest

  echo "[local] building distribution (jobs=${DIST_JOBS}) -> ${LOG_DIR}/distribution.log"
  install_cross_as_flock_wrapper "${tooldir}"
  export MAKEFLAGS="-j${DIST_JOBS}"
  MKPCI=no HOST_CFLAGS="-O -fcommon ${HARDENING_OFF}" \
    HOST_CXXFLAGS="-O -std=c++11 -fno-rtti -fno-exceptions ${HARDENING_OFF}" \
    HAVE_GOLD=no MKLLVM=yes \
    ./build.sh -U -u -V MKUPDATE=yes -j"${DIST_JOBS}" "${COMMON_FLAGS[@]}" distribution \
    2>&1 | tee "${LOG_DIR}/distribution.log"

  strip_libcxx_from_destdir
  echo "[local] stripped stale libc++ artifacts from DESTDIR"
}

pick_tooldir() {
  local tooldir="" d mt best=0
  for d in "${OBJDIR}"/tooldir.*; do
    [[ -d "${d}" ]] || continue
    [[ -x "${d}/bin/nbmake" ]] || continue
    mt="$(stat -c %Y "${d}" 2>/dev/null || echo 0)"
    if (( mt >= best )); then
      best="${mt}"
      tooldir="${d}"
    fi
  done
  [[ -n "${tooldir}" ]] || {
    echo "[local] ERROR: no TOOLDIR under ${OBJDIR}" >&2
    exit 1
  }
  printf '%s' "${tooldir}"
}

run_servers() {
  local tooldir nbmake
  tooldir="$(pick_tooldir)"
  nbmake="${tooldir}/bin/nbmake-${MACHINE}"
  export MKPCI=no
  export MAKEOBJDIR='${.CURDIR:C,^'${REPO_ROOT}','${REPO_ROOT}'/'${OBJDIR}',}'

  echo "[local] rebuilding vm + kernel (STATELEN / server fixes)"
  "${nbmake}" -C minix/servers/vm -j"${JOBS}"
  "${nbmake}" -C minix/servers/vm install
  "${nbmake}" -C minix/kernel -j"${JOBS}"
}

run_image() {
  local image="${IMAGE_PATH:-${LOG_DIR}/minix-riscv64-llvm.img}"
  echo "[local] mkdisk -> ${image}"
  minix/releasetools/riscv64/mkdisk.sh \
    -d "${OBJDIR}" \
    -o "${image}" \
    -s 1024 \
    -u 768 \
    -U
  echo "[local] IMAGE=${image}"
}

run_verify() {
  local tooldir log="${LOG_DIR}/verify.log"
  local image="${IMAGE_PATH:-${LOG_DIR}/minix-riscv64-llvm.img}"
  tooldir="$(pick_tooldir)"
  install_cross_as_flock_wrapper "${tooldir}"
  strip_libcxx_from_destdir

  : >"${log}"
  export TOOLDIR="${tooldir}"
  export KERNEL="${REPO_ROOT}/${OBJDIR}/minix/kernel/kernel"
  export DESTDIR="${REPO_ROOT}/${OBJDIR}/destdir.evbriscv64"
  export SMOKE_DISK_IMAGE="${image}"
  export SMOKE_DD_UNSAFE=1
  export LLVM_GATE_REQUIRE=all

  echo "[local] verify log: ${log}"

  run_gate() {
    local name="$1"
    shift
    echo "[local] >>> ${name}" | tee -a "${log}"
    if "$@" >>"${log}" 2>&1; then
      echo "[local] ${name}: PASS" | tee -a "${log}"
    else
      local rc=$?
      echo "[local] ${name}: FAIL (rc=${rc})" | tee -a "${log}"
      tail -n 80 "${log}" >&2 || true
      exit "${rc}"
    fi
  }

  [[ -x "${DESTDIR}/usr/bin/clang" ]] || {
    echo "[local] ERROR: ${DESTDIR}/usr/bin/clang missing; run distribution first" >&2
    exit 1
  }
  [[ -f "${KERNEL}" ]] || {
    echo "[local] ERROR: ${KERNEL} missing; run servers or distribution" >&2
    exit 1
  }

  run_gate host ./minix/tests/riscv64/llvm_toolchain_gate.sh \
    --mode host --require host --tooldir "${tooldir}"
  run_gate destdir ./minix/tests/riscv64/llvm_toolchain_gate.sh \
    --mode destdir --require destdir --destdir "${DESTDIR}"

  if [[ ! -f "${image}" ]]; then
    run_image
  fi

  run_gate llvm-guest ./minix/tests/riscv64/llvm_toolchain_gate.sh \
    --mode guest --require guest \
    --tooldir "${tooldir}" \
    --destdir "${DESTDIR}" \
    --kernel "${KERNEL}" \
    --disk-image "${image}"

  echo "[local] verify: all PASS (see ${log})"
}

case "${TARGET}" in
  tools) run_tools ;;
  distribution) run_distribution ;;
  servers) run_servers ;;
  image) run_image ;;
  verify) run_verify ;;
  all)
    run_tools
    run_distribution
    run_servers
    run_image
    run_verify
    ;;
  *)
    echo "usage: $0 [tools|distribution|servers|image|verify|all]" >&2
    exit 1
    ;;
esac

echo "[local] done (${TARGET})"
