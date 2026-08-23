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

QEMU="${QEMU:-qemu-system-i386}"
KVM_ARGS=()
if [[ "${QEMU_KVM:-auto}" != "0" ]] && [[ -r /dev/kvm ]] && groups | grep -q '\bkvm\b'; then
  KVM_ARGS=(-enable-kvm)
fi

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
  if [[ -n "${DESTDIR:-}" && -d "${DESTDIR}" ]]; then
    echo "${DESTDIR}"
    return 0
  fi
  if [[ -d "${OBJDIR}/destdir.i386" ]]; then
    echo "${OBJDIR}/destdir.i386"
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
  APPEND="bootramdisk=1"
else
  APPEND="rootdevname=c0d0p0"
fi
if [[ -n "${APPEND_EXTRA}" ]]; then
  APPEND="${APPEND} ${APPEND_EXTRA}"
fi

QEMU_ARGS=(
  "${KVM_ARGS[@]}"
  -m "${MEMORY}"
  -kernel "${KERNEL}"
  -append "${APPEND}"
  -initrd "${mods}"
  -nographic
  -serial mon:stdio
  -display none
)

if [[ -n "${DISK}" ]]; then
  QEMU_ARGS+=(-hda "${DISK}")
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
