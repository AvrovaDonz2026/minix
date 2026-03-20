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
  if [[ "${base}" =~ ^00(1[3-9]|2[0-9]|3[0-9])- ]]; then
    echo "Skipping repo-integrated backend workspace patch ${p}"
    continue
  fi
  if patch --dry-run -p1 < "${p}" >/dev/null 2>&1; then
    echo "Applying workspace patch ${p}"
    patch -p1 < "${p}"
    continue
  fi

  if patch --dry-run -R -p1 < "${p}" >/dev/null 2>&1; then
    echo "Skipping already-applied workspace patch ${p}"
    continue
  fi

  echo "Workspace patch does not apply cleanly: ${p}" >&2
  exit 1
done
