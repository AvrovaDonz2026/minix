#!/usr/bin/env bash
set -euo pipefail

patch_dir="${1:?usage: apply-workspace-patches.sh <patch-dir>}"

shopt -s nullglob
patches=("${patch_dir}"/*.patch)
if (( ${#patches[@]} == 0 )); then
  echo "No workspace patch files found in ${patch_dir}."
  exit 0
fi

for p in "${patches[@]}"; do
  echo "Applying workspace patch ${p}"
  patch -p1 < "${p}"
done
