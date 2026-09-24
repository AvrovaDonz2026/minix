#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
patch_root="$(cd "${script_dir}/.." && pwd)"
repo_root="$(cd "${patch_root}/../../.." && pwd)"

apply_patch_dir() {
  local patch_dir="$1"
  local target_dir="$2"
  local label="$3"

  shopt -s nullglob
  local patches=("${patch_dir}"/*.patch)
  shopt -u nullglob

  if (( ${#patches[@]} == 0 )); then
    echo "[guest-patches] no patches in ${patch_dir}"
    return 0
  fi

  if [[ ! -d "${target_dir}" ]]; then
    echo "[guest-patches] skip ${label}: missing ${target_dir}" >&2
    return 0
  fi

  for patch in "${patches[@]}"; do
    local base
    base="$(basename "${patch}")"
    if patch --dry-run -p1 -d "${target_dir}" < "${patch}" >/dev/null 2>&1; then
      echo "[guest-patches] applying ${label}/${base}"
      patch -p1 -d "${target_dir}" < "${patch}"
      continue
    fi
    if patch --dry-run -R -p1 -d "${target_dir}" < "${patch}" >/dev/null 2>&1; then
      echo "[guest-patches] already applied ${label}/${base}"
      continue
    fi
    echo "[guest-patches] failed to apply ${label}/${base} under ${target_dir}" >&2
    exit 1
  done
}

apply_patch_dir "${patch_root}/gcc-dist" \
  "${repo_root}/external/gpl3/gcc/dist" \
  "gcc-dist"
apply_patch_dir "${patch_root}/llvm-dist" \
  "${repo_root}/external/bsd/llvm/dist" \
  "llvm-dist"
