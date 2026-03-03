#!/usr/bin/env bash
set -u

if [[ $# -lt 1 ]]; then
  echo "usage: watch-legacy-riscv-as-wrap.sh <triplet-as-path> [<triplet-as-path> ...]" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
wrap_script="${script_dir}/wrap-legacy-riscv-as.sh"
timeout_sec="${WATCH_TIMEOUT_SEC:-1800}"
interval_sec="${WATCH_INTERVAL_SEC:-2}"

start_ts="$(date +%s)"
while true; do
  now_ts="$(date +%s)"
  if (( now_ts - start_ts >= timeout_sec )); then
    exit 0
  fi

  for as_bin in "$@"; do
    # Wrapper script tolerates re-wrap, and can recover if tools reinstall
    # has replaced the wrapper with a fresh assembler binary.
    if [[ -x "${as_bin}" || -x "${as_bin}.real" ]]; then
      bash "${wrap_script}" "${as_bin}" >/dev/null 2>&1 || true
    fi
  done

  sleep "${interval_sec}"
done
