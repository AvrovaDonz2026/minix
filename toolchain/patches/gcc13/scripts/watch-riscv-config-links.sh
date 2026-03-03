#!/usr/bin/env bash
set -u

script_dir="$(cd "$(dirname "$0")" && pwd)"
ensure_script="${script_dir}/ensure-riscv-config-links.sh"
timeout_sec="${WATCH_TIMEOUT_SEC:-1800}"
interval_sec="${WATCH_INTERVAL_SEC:-2}"

start_ts="$(date +%s)"
while true; do
  now_ts="$(date +%s)"
  if (( now_ts - start_ts >= timeout_sec )); then
    exit 0
  fi

  bash "${ensure_script}" >/dev/null 2>&1 || true
  sleep "${interval_sec}"
done
