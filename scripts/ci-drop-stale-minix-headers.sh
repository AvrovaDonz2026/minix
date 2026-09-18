#!/bin/sh
# Drop tracked DESTDIR MINIX headers so MKUPDATE cannot keep a snapshot
# whose mtime is newer than source (content still stale). `make includes`
# then reinstalls from this tree.
#
# Usage: ci-drop-stale-minix-headers.sh DESTDIR_ROOT [MINIX_INCLUDE_DIR]

set -eu

destdir_root="${1:?usage: $0 DESTDIR_ROOT [MINIX_INCLUDE_DIR]}"
src_inc="${2:-${PWD}/minix/include}"
inc="${destdir_root}/usr/include"

mkdir -p "${inc}"

rm -f \
	"${inc}/libexec.h" \
	"${inc}/lib.h" \
	"${inc}/libutil.h" \
	"${inc}/varargs.h" \
	"${inc}/configfile.h" \
	"${destdir_root}/usr/lib/libexec.a" \
	"${destdir_root}/usr/lib/libexec_pic.a"

rm -rf \
	"${inc}/minix" \
	"${inc}/ddekit" \
	"${inc}/libdde" \
	"${inc}/net"

if [ -d "${src_inc}/sys" ]; then
	for f in "${src_inc}/sys/"*.h; do
		[ -f "${f}" ] || continue
		rm -f "${inc}/sys/$(basename "${f}")"
	done
fi

# minix/include/arch/<cpu>/include installs to /usr/include/<cpu>, with
# extra copies under MACHINE (evbriscv64). <machine/vm.h> follows these.
for arch in riscv64 i386 earm evbriscv64; do
	rm -rf "${inc}/${arch}"
done
