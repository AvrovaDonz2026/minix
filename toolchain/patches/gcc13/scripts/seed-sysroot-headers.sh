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
