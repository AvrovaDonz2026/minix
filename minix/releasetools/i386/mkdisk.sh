#!/bin/bash
#
# Create a bootable MINIX/i386 disk image from a distribution DESTDIR.
#
# Layout matches releasetools/x86_hdimage.sh (bootxx + root/usr/home MFS).
# Populates partitions from obj.i386/destdir.i386 instead of release sets.
#
# Usage:
#   minix/releasetools/i386/mkdisk.sh -d obj.i386 -o /tmp/minix-i386.img
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OBJDIR="${OBJDIR:-${REPO_ROOT}/obj.i386}"
ARCH=i386
DESTDIR="${DESTDIR:-${OBJDIR}/destdir.${ARCH}}"
OUTPUT="${OUTPUT:-minix-i386.img}"
BOOTXX_SECS=32
ROOT_SIZE=$((64 * 1024 * 1024))
USR_SIZE=$((128 * 1024 * 1024))
HOME_SIZE=$((32 * 1024 * 1024))
EFI_SIZE=0

usage() {
  cat <<EOF
Usage: $0 [-d OBJDIR] [-o OUTPUT] [-D DESTDIR]

Create MINIX/i386 MFS disk image from distribution DESTDIR.
EOF
  exit 1
}

while getopts "d:o:D:h" opt; do
  case "$opt" in
    d) OBJDIR="$OPTARG" ;;
    o) OUTPUT="$OPTARG" ;;
    D) DESTDIR="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

log() { echo "[mkdisk-i386] $*"; }
die() { echo "[mkdisk-i386] ERROR: $*" >&2; exit 1; }

[[ -d "${DESTDIR}" ]] || die "DESTDIR not found: ${DESTDIR}"
[[ -x "${DESTDIR}/boot/minix/.temp/kernel" ]] || \
  die "missing boot kernel; run distribution first"

tooldir=""
for d in "${OBJDIR}"/tooldir.*; do
  [[ -d "${d}" ]] || continue
  [[ -x "${d}/bin/nbmkfs.mfs" ]] || continue
  tooldir="${d}"
done
[[ -n "${tooldir}" ]] || die "no tooldir with nbmkfs.mfs under ${OBJDIR}"

CROSS_TOOLS="${tooldir}/bin"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/minix-i386-mkdisk.XXXXXX")"
ROOT_DIR="${WORK_DIR}/fs"
trap 'rm -rf "${WORK_DIR}"' EXIT

mkdir -p "${ROOT_DIR}"

log "staging root filesystem from ${DESTDIR}"
rsync -a \
  --exclude '/usr/' \
  --exclude '/home/' \
  --exclude '/var/tmp/' \
  --exclude '/var/log/' \
  "${DESTDIR}/" "${ROOT_DIR}/"

mkdir -p "${ROOT_DIR}/usr" "${ROOT_DIR}/home"
rsync -a "${DESTDIR}/usr/" "${ROOT_DIR}/usr/"
if [[ -d "${DESTDIR}/home" ]]; then
  rsync -a "${DESTDIR}/home/" "${ROOT_DIR}/home/"
fi

cp "${DESTDIR}/usr/mdec/boot_monitor" "${ROOT_DIR}/boot_monitor"
cat >"${ROOT_DIR}/etc/fstab" <<'EOF'
/dev/c0d0p1	/usr		mfs	rw			0	2
/dev/c0d0p2	/home		mfs	rw			0	2
none		/sys		devman	rw,rslabel=devman	0	0
none		/dev/pts	ptyfs	rw,rslabel=ptyfs	0	0
EOF

log "building mtree specs"
"${CROSS_TOOLS}/nbmtree" -C -K uname=root -K grname=wheel \
  -p "${ROOT_DIR}" > "${WORK_DIR}/input"

grep -v '^\./usr/\|^\./home/' "${WORK_DIR}/input" | \
  "${CROSS_TOOLS}/nbtoproto" -b "${ROOT_DIR}" > "${WORK_DIR}/proto.root"

grep -E '^\./usr/|^\./usr$|^\.$' "${WORK_DIR}/input" | \
  sed 's,^\./usr,\.,' | \
  "${CROSS_TOOLS}/nbtoproto" -b "${ROOT_DIR}/usr" > "${WORK_DIR}/proto.usr"

grep -E '^\./home/|^\./home$|^\.$' "${WORK_DIR}/input" | \
  sed 's,^\./home,\.,' | \
  "${CROSS_TOOLS}/nbtoproto" -b "${ROOT_DIR}/home" > "${WORK_DIR}/proto.home"

rm -f "${OUTPUT}"
ROOTSIZEARG="-b $((${ROOT_SIZE} / 512 / 8))"
USRSIZEARG="-b $((${USR_SIZE} / 512 / 8))"
HOMESIZEARG="-b $((${HOME_SIZE} / 512 / 8))"

ROOT_START=${BOOTXX_SECS}
log "writing ROOT partition"
_ROOT_SIZE="$("${CROSS_TOOLS}/nbmkfs.mfs" -d ${ROOTSIZEARG} \
  -I $((${ROOT_START} * 512)) "${OUTPUT}" "${WORK_DIR}/proto.root")"
_ROOT_SIZE=$((${_ROOT_SIZE} / 512))

USR_START=$((${ROOT_START} + ${_ROOT_SIZE}))
log "writing USR partition"
_USR_SIZE="$("${CROSS_TOOLS}/nbmkfs.mfs" -d ${USRSIZEARG} \
  -I $((${USR_START} * 512)) "${OUTPUT}" "${WORK_DIR}/proto.usr")"
_USR_SIZE=$((${_USR_SIZE} / 512))

HOME_START=$((${USR_START} + ${_USR_SIZE}))
log "writing HOME partition"
_HOME_SIZE="$("${CROSS_TOOLS}/nbmkfs.mfs" -d ${HOMESIZEARG} \
  -I $((${HOME_START} * 512)) "${OUTPUT}" "${WORK_DIR}/proto.home")"
_HOME_SIZE=$((${_HOME_SIZE} / 512))

"${CROSS_TOOLS}/nbpartition" -m "${OUTPUT}" \
  ${BOOTXX_SECS} 81:${_ROOT_SIZE}* 81:${_USR_SIZE} 81:${_HOME_SIZE}

"${CROSS_TOOLS}/nbinstallboot" -f -m ${ARCH} "${OUTPUT}" \
  "${DESTDIR}/usr/mdec/bootxx_minixfs3"

log "disk image ready: ${OUTPUT} ($(du -h "${OUTPUT}" | awk '{print $1}'))"
