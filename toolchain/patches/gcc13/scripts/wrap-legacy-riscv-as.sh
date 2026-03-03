#!/usr/bin/env bash
set -euo pipefail

as_bin="${1:?usage: wrap-legacy-riscv-as.sh <triplet-as-path>}"
as_real="${as_bin}.real"
wrapper_marker="MINIX_GCC13_LEGACY_RISCV_AS_WRAPPER"

is_wrapper_installed() {
  local target="$1"
  [[ -f "${target}" ]] || return 1
  grep -q "${wrapper_marker}" "${target}" 2>/dev/null \
    || grep -q 'real="\${self}\.real"' "${target}" 2>/dev/null
}

if [[ -x "${as_real}" ]]; then
  if is_wrapper_installed "${as_bin}"; then
    echo "Assembler wrapper already installed at ${as_bin}"
    exit 0
  fi

  # The wrapped assembler can be replaced later by a tools reinstall.
  # If that happens, preserve the newest assembler payload as .real and
  # regenerate the wrapper script.
  if [[ -x "${as_bin}" ]]; then
    mv -f "${as_bin}" "${as_real}"
  fi
else
  if [[ ! -x "${as_bin}" ]]; then
    echo "Missing assembler binary: ${as_bin}" >&2
    exit 1
  fi
  mv "${as_bin}" "${as_real}"
fi

cat > "${as_bin}" <<'EOF'
#!/usr/bin/env bash
# MINIX_GCC13_LEGACY_RISCV_AS_WRAPPER
set -euo pipefail

self="$0"
real="${self}.real"

if [[ ! -x "${real}" ]]; then
  echo "Missing wrapped assembler: ${real}" >&2
  exit 1
fi

args=()
for arg in "$@"; do
  case "${arg}" in
    -march=rv32*|-march=rv64*)
      isa="${arg#-march=rv32}"
      if [[ "${isa}" == "${arg}" ]]; then
        isa="${arg#-march=rv64}"
      fi
      isa="${isa%%_*}"
      isa="${isa^^}"
      args+=("-march=${isa}")
      ;;
    *)
      args+=("${arg}")
      ;;
  esac
done

exec "${real}" "${args[@]}"
EOF

chmod +x "${as_bin}"
echo "Installed assembler wrapper at ${as_bin}"
