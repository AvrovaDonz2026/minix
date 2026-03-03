#!/usr/bin/env bash
set -euo pipefail

as_bin="${1:?usage: wrap-legacy-riscv-as.sh <triplet-as-path>}"
as_real="${as_bin}.real"

if [[ -x "${as_real}" ]]; then
  echo "Assembler wrapper already installed at ${as_bin}"
  exit 0
fi

if [[ ! -x "${as_bin}" ]]; then
  echo "Missing assembler binary: ${as_bin}" >&2
  exit 1
fi

mv "${as_bin}" "${as_real}"

cat > "${as_bin}" <<'EOF'
#!/usr/bin/env bash
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
