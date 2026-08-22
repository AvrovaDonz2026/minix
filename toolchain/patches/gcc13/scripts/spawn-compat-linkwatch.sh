#!/usr/bin/env bash
set -u

objdir="${1:?usage: spawn-compat-linkwatch.sh <objdir>}"

tools=(
  install ar as ld nm objcopy objdump ranlib readelf size strings strip
  addr2line c++ c++filt cc cpp g++ gcc gcov gprof elfedit
)

shopt -s nullglob
for _ in $(seq 1 180); do
  for toolbindir in "${objdir}"/tooldir.*/bin; do
    [[ -d "${toolbindir}" ]] || continue
    for tool in "${tools[@]}"; do
      ln -sf "riscv64-elf32-minix-${tool}" \
        "${toolbindir}/riscv64-unknown-elf-${tool}"
    done
    exit 0
  done
  sleep 2
done

exit 0
