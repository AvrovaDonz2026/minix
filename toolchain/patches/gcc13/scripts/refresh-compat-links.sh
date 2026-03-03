#!/usr/bin/env bash
set -euo pipefail

objdir="${1:?usage: refresh-compat-links.sh <objdir>}"

shopt -s nullglob
for toolbindir in "${objdir}"/tooldir.*/bin; do
  [[ -d "${toolbindir}" ]] || continue
  for src in "${toolbindir}"/riscv64-elf32-minix-*; do
    base="${src##*/riscv64-elf32-minix-}"
    ln -sf "$(basename "${src}")" "${toolbindir}/riscv64-unknown-elf-${base}"
  done
done
