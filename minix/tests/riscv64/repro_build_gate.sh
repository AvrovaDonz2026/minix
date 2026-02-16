#!/bin/bash
#
# Reproducible build + smoke gate for riscv64.
# Verifies that the pipeline is source-driven (tracked patch in-tree) and
# then runs isolated build.sh steps followed by multi-run smoke.
#

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MINIX_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SMOKE_GATE="$SCRIPT_DIR/multi_smoke_gate.sh"

OBJDIR="${OBJDIR:-obj.repro}"
JOBS="${JOBS:-$(nproc)}"
SMOKE_ROUNDS=2
SKIP_TOOLS=0
SKIP_DISTRIBUTION=0
WITHOUT_DISK=0
SMOKE_TIMEOUT=140
DISK_IMAGE=""

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --objdir NAME                 Isolated objdir (default: obj.repro)
  --jobs N                      Parallel jobs for distribution (default: nproc)
  --smoke-rounds N              Multi-run smoke rounds (default: 2)
  --smoke-timeout SEC           Per-run smoke timeout (default: 140)
  --skip-tools                  Skip build.sh tools
  --skip-distribution           Skip build.sh distribution
  --without-disk                Smoke only diskless profile
  --disk-image PATH             Disk image path for smoke
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --objdir) OBJDIR="$2"; shift 2 ;;
        --jobs) JOBS="$2"; shift 2 ;;
        --smoke-rounds) SMOKE_ROUNDS="$2"; shift 2 ;;
        --smoke-timeout) SMOKE_TIMEOUT="$2"; shift 2 ;;
        --skip-tools) SKIP_TOOLS=1; shift ;;
        --skip-distribution) SKIP_DISTRIBUTION=1; shift ;;
        --without-disk) WITHOUT_DISK=1; shift ;;
        --disk-image) DISK_IMAGE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

cd "$MINIX_ROOT"

if [ ! -f "./build.sh" ]; then
    echo "build.sh not found in $MINIX_ROOT" >&2
    exit 1
fi

if ! git ls-files --error-unmatch external/gpl3/binutils/patches/0011-riscv-relax-compat.patch >/dev/null 2>&1; then
    echo "tracked binutils relax compatibility patch is missing from git index" >&2
    exit 1
fi

COMMON_BUILD_FLAGS=(
  -V AVAILABLE_COMPILER=gcc
  -V ACTIVE_CC=gcc
  -V ACTIVE_CPP=gcc
  -V ACTIVE_CXX=gcc
  -V ACTIVE_OBJC=gcc
  -V RISCV_ARCH_FLAGS=-march=RV64IMAFD\ -mcmodel=medany
  -V NOGCCERROR=yes
  -V MKPIC=no
  -V MKPICLIB=no
  -V MKPICINSTALL=no
  -V MKCXX=no
  -V MKLIBSTDCXX=no
  -V MKATF=no
  -V USE_PCI=no
  -V CHECKFLIST_FLAGS=-m\ -e
)

if [ "$SKIP_TOOLS" -eq 0 ]; then
    MKPCI=no HOST_CFLAGS="-O -fcommon" HAVE_GOLD=no HAVE_LLVM=no MKLLVM=no \
    ./build.sh -U -m evbriscv64 -O "$OBJDIR" \
        "${COMMON_BUILD_FLAGS[@]}" \
        -V MKGCC=yes -V MKGCCCMDS=yes \
        tools
fi

if [ "$SKIP_DISTRIBUTION" -eq 0 ]; then
    MKPCI=no HOST_CFLAGS="-O -fcommon" HAVE_GOLD=no HAVE_LLVM=no MKLLVM=no \
    ./build.sh -U -u -j"$JOBS" -m evbriscv64 -O "$OBJDIR" \
        "${COMMON_BUILD_FLAGS[@]}" \
        distribution
fi

DESTDIR="$MINIX_ROOT/$OBJDIR/destdir.evbriscv64"
KERNEL="$MINIX_ROOT/$OBJDIR/minix/kernel/kernel"

for path in \
    service/ds \
    service/rs \
    service/pm \
    service/sched \
    service/vfs \
    service/memory \
    service/tty \
    service/mib \
    service/vm \
    service/pfs \
    service/mfs \
    sbin/init; do
    if [ ! -f "$DESTDIR/$path" ]; then
        echo "required boot module missing: $DESTDIR/$path" >&2
        exit 1
    fi
done

if [ ! -f "$KERNEL" ]; then
    echo "kernel missing: $KERNEL" >&2
    exit 1
fi

SMOKE_ARGS=(
  --kernel "$KERNEL"
  --destdir "$DESTDIR"
  --rounds "$SMOKE_ROUNDS"
  --timeout "$SMOKE_TIMEOUT"
)

if [ "$WITHOUT_DISK" -eq 1 ]; then
    SMOKE_ARGS+=(--without-disk)
fi
if [ -n "$DISK_IMAGE" ]; then
    SMOKE_ARGS+=(--disk-image "$DISK_IMAGE")
fi

"$SMOKE_GATE" "${SMOKE_ARGS[@]}"
