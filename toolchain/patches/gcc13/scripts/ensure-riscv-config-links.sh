#!/usr/bin/env bash
set -euo pipefail

config_rel='../../../../dist/gcc/config'

for arch in riscv32 riscv64; do
  arch_dir="external/gpl3/gcc/usr.bin/gcc/arch/${arch}"
  link_path="${arch_dir}/config"

  if [[ ! -d "${arch_dir}" ]]; then
    continue
  fi

  if [[ -L "${link_path}" ]]; then
    if [[ "$(readlink "${link_path}")" == "${config_rel}" ]]; then
      continue
    fi
    rm -f "${link_path}"
  elif [[ -e "${link_path}" ]]; then
    echo "Expected symlink at ${link_path}, found non-symlink entry." >&2
    exit 1
  fi

  ln -s "${config_rel}" "${link_path}"
  echo "Linked ${link_path} -> ${config_rel}"
done
