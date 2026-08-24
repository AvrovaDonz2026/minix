#!/usr/bin/env bash
#
# MINIX local development environment for macOS (Homebrew, Apple Silicon).
# Source this file from the repository root:
#   source scripts/env/macos.sh
#

_minix_brew_prefix="${HOMEBREW_PREFIX:-/opt/homebrew}"
if [[ ! -x "${_minix_brew_prefix}/bin/brew" ]]; then
	echo "Homebrew was not found at ${_minix_brew_prefix}." >&2
	return 1
fi

export PATH="${_minix_brew_prefix}/opt/coreutils/libexec/gnubin:${_minix_brew_prefix}/opt/gnu-sed/libexec/gnubin:${_minix_brew_prefix}/opt/make/libexec/gnubin:${_minix_brew_prefix}/opt/bison/bin:${_minix_brew_prefix}/opt/flex/bin:${_minix_brew_prefix}/opt/llvm/bin:${_minix_brew_prefix}/bin:${PATH}"
export PKG_CONFIG_PATH="${_minix_brew_prefix}/opt/flex/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# Preserve explicit compiler choices from the calling shell.
export CC="${CC:-${_minix_brew_prefix}/opt/llvm/bin/clang}"
export CXX="${CXX:-${_minix_brew_prefix}/opt/llvm/bin/clang++}"
export HOST_CC="${HOST_CC:-${CC}}"
export HOST_CXX="${HOST_CXX:-${CXX}}"

# The full tree is memory-intensive on laptops. Callers can raise this.
export TOOLS_CPU_COUNT="${TOOLS_CPU_COUNT:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
export WORLD_CPU_COUNT="${WORLD_CPU_COUNT:-4}"

unset _minix_brew_prefix

echo "MINIX macOS environment enabled"
echo "CC=${CC}"
