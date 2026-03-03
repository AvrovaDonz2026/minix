#!/usr/bin/env bash
set -euo pipefail

patch_dir="${1:?usage: apply-workspace-patches.sh <patch-dir>}"
mode="${2:-shim}"

case "${mode}" in
  shim|native) ;;
  *)
    echo "unsupported mode: ${mode} (expected: shim|native)" >&2
    exit 1
    ;;
esac

shopt -s nullglob
patches=("${patch_dir}"/*.patch)
if (( ${#patches[@]} == 0 )); then
  echo "No workspace patch files found in ${patch_dir}."
  exit 0
fi

for p in "${patches[@]}"; do
  base="$(basename "${p}")"
  if [[ "${mode}" == "native" ]] && [[ "${base}" == *target-triplet-override* ]]; then
    echo "Skipping shim-only workspace patch ${p} for native mode"
    continue
  fi
  echo "Applying workspace patch ${p}"
  patch -p1 < "${p}"
done
