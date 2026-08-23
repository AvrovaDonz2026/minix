#!/bin/bash
#
# QEMU launch script for MINIX/i386 (multiboot + initrd modules).
#
# Usage:
#   ./qemu-i386.sh [options]
#
# Options:
#   -d          Debug mode (wait for GDB on :1234)
#   -m SIZE     Memory size (default: 256M)
#   -k KERNEL   Kernel image path
#   -i IMAGE    Disk image path (root/usr/home MFS layout)
#   -B DIR      Boot module directory (default: DESTDIR/boot/minix/.temp)
#   -a ARGS     Extra kernel append string
#   -r          Boot from ramdisk (bootramdisk=1)
#   -s          Single CPU (ignored; kept for probe compatibility)
#

set -euo pipefail

MEMORY="256M"
DEBUG=0
KERNEL=""
DISK=""
MODROOT=""
APPEND_EXTRA=""
RAMDISK_BOOT=0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MINIX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$MINIX_ROOT/.." && pwd)"

if [[ -n "${OBJDIR:-}" ]]; then
  OBJDIR="$(cd "${OBJDIR}" && pwd)"
else
  OBJDIR="${REPO_ROOT}/obj.i386"
fi

DESTDIR_RESOLVED=""
if [[ -n "${DESTDIR:-}" && -d "${DESTDIR}" ]]; then
  DESTDIR_RESOLVED="$(cd "${DESTDIR}" && pwd)"
elif [[ -d "${OBJDIR}/destdir.i386" ]]; then
  DESTDIR_RESOLVED="${OBJDIR}/destdir.i386"
fi

QEMU="${QEMU:-qemu-system-i386}"
# Deterministic TCG (icount) avoids timer/APIC boot hangs under QEMU in CI.
KVM_ARGS=()

# Serial console on COM1; skip ACPI userspace (hangs in QEMU) and virtio PCI
# block (QEMU i386 uses PIIX IDE).  Matches releasetools/x86_hdimage.sh.
QEMU_APPEND_DEFAULTS="${QEMU_APPEND_DEFAULTS:-cttyline=0 acpi=no virtio_blk=no}"

usage() {
  echo "Usage: $0 [-d] [-m size] [-k kernel] [-i image] [-B moddir] [-a append] [-r]" >&2
  exit 1
}

while getopts "dm:k:i:B:a:rs" opt; do
  case "$opt" in
    d) DEBUG=1 ;;
    m) MEMORY="$OPTARG" ;;
    k) KERNEL="$OPTARG" ;;
    i) DISK="$OPTARG" ;;
    B) MODROOT="$OPTARG" ;;
    a) APPEND_EXTRA="$OPTARG" ;;
    r) RAMDISK_BOOT=1 ;;
    s) ;;
    *) usage ;;
  esac
done

if [[ -n "${MODROOT}" && -d "${MODROOT}/boot/minix/.temp" ]]; then
  MODROOT="${MODROOT}/boot/minix/.temp"
fi

resolve_destdir() {
  if [[ -n "${DESTDIR_RESOLVED}" ]]; then
    echo "${DESTDIR_RESOLVED}"
    return 0
  fi
  return 1
}

DESTDIR_RESOLVED="$(resolve_destdir || true)"
if [[ -z "${MODROOT}" ]]; then
  if [[ -n "${DESTDIR_RESOLVED}" ]]; then
    MODROOT="${DESTDIR_RESOLVED}/boot/minix/.temp"
  fi
fi

if [[ -z "${KERNEL}" ]]; then
  if [[ -n "${MODROOT}" && -x "${MODROOT}/kernel" ]]; then
    KERNEL="${MODROOT}/kernel"
  elif [[ -f "${OBJDIR}/minix/kernel/kernel" ]]; then
    KERNEL="${OBJDIR}/minix/kernel/kernel"
  fi
fi

if [[ -z "${KERNEL}" || ! -f "${KERNEL}" ]]; then
  echo "Kernel not found. Pass -k or build distribution first." >&2
  exit 1
fi
KERNEL="$(cd "$(dirname "${KERNEL}")" && pwd)/$(basename "${KERNEL}")"

if [[ -n "${DISK}" && -f "${DISK}" ]]; then
  DISK="$(cd "$(dirname "${DISK}")" && pwd)/$(basename "${DISK}")"
fi

if [[ -z "${MODROOT}" || ! -d "${MODROOT}" ]]; then
  echo "Boot module directory not found: ${MODROOT:-<unset>}" >&2
  exit 1
fi

mods="$(cd "${MODROOT}" && ls -1 mod* 2>/dev/null | paste -sd, - || true)"
if [[ -z "${mods}" ]]; then
  echo "No mod* boot modules under ${MODROOT}" >&2
  exit 1
fi

if (( RAMDISK_BOOT == 1 )); then
  APPEND="bootramdisk=1 ${QEMU_APPEND_DEFAULTS}"
else
  APPEND="rootdevname=c0d0p0 ${QEMU_APPEND_DEFAULTS}"
fi
if [[ -n "${APPEND_EXTRA}" ]]; then
  APPEND="${APPEND} ${APPEND_EXTRA}"
fi

QEMU_ARGS=(
  "${KVM_ARGS[@]}"
  -machine pc
  -accel tcg
  -icount shift=auto,align=off,sleep=on
  -m "${MEMORY}"
  -nographic
  -serial mon:stdio
  -display none
)

KERNEL_ARG="${KERNEL}"
if [[ -n "${MODROOT}" && "${KERNEL}" == "${MODROOT}/"* ]]; then
  KERNEL_ARG="${KERNEL#${MODROOT}/}"
fi

QEMU_ARGS+=(
  -kernel "${KERNEL_ARG}"
  -append "${APPEND}"
  -initrd "${mods}"
)

if [[ -n "${DISK}" ]]; then
  QEMU_ARGS+=(-drive "file=${DISK},format=raw,if=ide")
fi

if (( DEBUG == 1 )); then
  QEMU_ARGS+=(-S -gdb "tcp::1234")
  echo "Waiting for GDB on port 1234..."
fi

echo "Kernel: ${KERNEL}"
echo "Modules: ${MODROOT} (${mods})"
[[ -n "${DISK}" ]] && echo "Disk: ${DISK}"
echo "Append: ${APPEND}"
echo "Starting: ${QEMU} ${QEMU_ARGS[*]}"

cd "${MODROOT}"
exec "${QEMU}" "${QEMU_ARGS[@]}"
