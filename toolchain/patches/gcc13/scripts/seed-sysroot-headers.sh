#!/usr/bin/env bash
set -euo pipefail

objdir="${1:?usage: seed-sysroot-headers.sh <objdir> <machine> [seed-objdir]}"
machine="${2:?usage: seed-sysroot-headers.sh <objdir> <machine> [seed-objdir]}"
seed_objdir="${3:-obj.intrgcc}"

destdir_root="${objdir}/destdir.${machine}"
mkdir -p "${destdir_root}/usr/include"

seed_include="${seed_objdir}/destdir.${machine}/usr/include"
if [[ -d "${seed_include}" ]]; then
  cp -a "${seed_include}/." "${destdir_root}/usr/include/"
fi

overlay_header() {
  local src="$1"
  local dst_rel="$2"
  local dst="${destdir_root}/usr/include/${dst_rel}"

  mkdir -p "$(dirname "${dst}")"
  cp -f "${src}" "${dst}"
}

# Keep ABI-sensitive headers in sync with source changes even when the
# bootstrap sysroot is seeded from committed obj.intrgcc artifacts.
overlay_header include/stddef.h stddef.h
overlay_header sys/sys/ansi.h sys/ansi.h
overlay_header sys/sys/stdarg.h sys/stdarg.h
