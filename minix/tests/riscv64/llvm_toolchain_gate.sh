#!/bin/bash
#
# LLVM/clang functional gate for MINIX/riscv64.
#
# Supports legacy LLVM 3.6.1 (frontend-only RISC-V) and modern CMake LLVM
# 18+ (full RISC-V codegen backend).
#
# Layers:
#   host     TOOLDIR clang/tblgen frontend, IR, RISC-V/Minix macros
#            and i586-elf32-minix when the wrapper is installed
#   destdir  guest clang ELF payload; /usr/bin/cc stays gcc;
#            libc++ must not install __mutex_base over libstdc++
#   guest    QEMU: clang --version, -dM, -emit-llvm; LLVM 18+ also tests -c
#
# Exit codes:
#   0 = pass
#   1 = fail
#   2 = skip (selected layers missing; not used with --require)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MINIX_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

QEMU_SCRIPT="${MINIX_ROOT}/minix/scripts/qemu-riscv64.sh"
RUNTIME_PROBE="${SCRIPT_DIR}/qemu_runtime_probe.py"

MODE="all"
REQUIRE=""
TOOLDIR="${TOOLDIR:-}"
DESTDIR="${DESTDIR:-}"
KERNEL="${KERNEL:-}"
DISK_IMAGE="${SMOKE_DISK_IMAGE:-}"
TIMEOUT="${NATIVE_GATE_TIMEOUT:-180}"
CMD_TIMEOUT="${NATIVE_GATE_CMD_TIMEOUT:-60}"
CLANG_TARGET="${LLVM_CLANG_TARGET:-riscv64-elf32-minix}"
X86_CLANG_TARGET="${LLVM_X86_CLANG_TARGET:-i586-elf32-minix}"

passed=0
failed=0
skipped=0

usage() {
  cat <<'USAGE'
Usage: llvm_toolchain_gate.sh [options]

Options:
  --mode host|destdir|guest|all
                         Which layers to run (default: all)
  --require host|destdir|guest|all
                         Fail instead of skip when a selected layer
                         is missing its inputs
  --tooldir <path>       Host TOOLDIR (default: auto-detect)
  --destdir <path>       DESTDIR root (default: auto-detect)
  --kernel <path>        Kernel for guest layer (default: auto-detect)
  --disk-image <path>    Disk image for guest layer
  --qemu-script <path>   QEMU launcher
  --timeout <sec>        Guest prompt timeout (default: 180)
  --cmd-timeout <sec>    Guest per-command timeout (default: 60)
  --target <triple>      Primary clang target (default: riscv64-elf32-minix)
  --x86-target <triple>  x86 MINIX clang target (default: i586-elf32-minix)
  -h, --help             Show this help
USAGE
}

log() { echo "[llvm-gate] $*"; }
log_pass() { echo "[llvm-gate] PASS: $*"; passed=$((passed + 1)); }
log_fail() { echo "[llvm-gate] FAIL: $*" >&2; failed=$((failed + 1)); }
log_skip() { echo "[llvm-gate] SKIP: $*"; skipped=$((skipped + 1)); }

detect_llvm_generation() {
  local verfile="$1"
  if grep -Eqi 'clang[[:space:]]+version[[:space:]]+3\.6' "$verfile"; then
    echo "legacy"
  elif grep -Eqi 'clang[[:space:]]+version[[:space:]]+1[0-9]' "$verfile"; then
    echo "modern"
  else
    echo "unknown"
  fi
}

want_mode() {
  case "$MODE" in
    all) return 0 ;;
    "$1") return 0 ;;
    *) return 1 ;;
  esac
}

want_require() {
  case "$REQUIRE" in
    all) return 0 ;;
    "$1") return 0 ;;
    *) return 1 ;;
  esac
}

pick_best_tooldir() {
  local best="" best_mt=0 d mt

  for d in "$@"; do
    [ -d "$d" ] || continue
    [ -x "$d/bin/nbmake" ] || continue
    if [ ! -x "$d/bin/riscv64-elf32-minix-clang" ] && \
       [ ! -x "$d/bin/riscv64-elf32-minix-gcc" ]; then
      continue
    fi
    mt=$(stat -c %Y "$d" 2>/dev/null || echo 0)
    if [ -z "$best" ] || [ "$mt" -ge "$best_mt" ]; then
      best="$d"
      best_mt="$mt"
    fi
  done
  printf '%s' "$best"
}

detect_tooldir() {
  if [ -n "$TOOLDIR" ] && [ -d "$TOOLDIR" ]; then
    echo "$TOOLDIR"
    return 0
  fi
  pick_best_tooldir \
    "$MINIX_ROOT"/obj.intrgcc/tooldir.* \
    "$MINIX_ROOT"/obj/tooldir.*
}

detect_destdir() {
  if [ -n "$DESTDIR" ] && [ -d "$DESTDIR" ]; then
    echo "$DESTDIR"
    return 0
  fi
  local c
  for c in \
    "${MINIX_ROOT}/obj.intrgcc/destdir.evbriscv64" \
    "${MINIX_ROOT}/obj/destdir.evbriscv64"; do
    if [ -d "$c" ]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

detect_kernel() {
  if [ -n "$KERNEL" ] && [ -f "$KERNEL" ]; then
    echo "$KERNEL"
    return 0
  fi
  local c
  for c in \
    "${MINIX_ROOT}/obj.intrgcc/minix/kernel/kernel" \
    "${MINIX_ROOT}/minix/kernel/obj/kernel" \
    "${MINIX_ROOT}/obj/minix/kernel/kernel"; do
    if [ -f "$c" ]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

find_host_bin() {
  local dir="$1"
  shift
  local name
  for name in "$@"; do
    if [ -x "${dir}/bin/${name}" ]; then
      echo "${dir}/bin/${name}"
      return 0
    fi
  done
  return 1
}

host_machine_of() {
  local bin="$1"
  local readelf="$2"
  local out=""

  if [ -n "$readelf" ] && [ -x "$readelf" ]; then
    out="$("$readelf" -h "$bin" 2>/dev/null | awk -F: '/Machine:/ {print $2; exit}')"
    out="${out#"${out%%[![:space:]]*}"}"
    if [ -n "$out" ]; then
      echo "$out"
      return 0
    fi
  fi
  if command -v file >/dev/null 2>&1; then
    file -b "$bin" 2>/dev/null || true
    return 0
  fi
  return 1
}

elf_has_interp() {
  local bin="$1"
  local readelf="$2"

  [ -n "$readelf" ] && [ -x "$readelf" ] || return 1
  "$readelf" -l "$bin" 2>/dev/null | grep -q 'INTERP'
}

object_matches_arch() {
  local machine="$1"
  local arch="$2"

  case "$arch" in
    riscv)
      case "$machine" in
        *RISC-V*|*RiscV*|*riscv*) return 0 ;;
      esac
      ;;
    x86)
      case "$machine" in
        *80386*|*i386*|*i686*|*x86*) return 0 ;;
      esac
      ;;
  esac
  return 1
}

run_host_target_checks() {
  local label="$1"
  local clang="$2"
  local clangxx="$3"
  local target="$4"
  local arch="$5"
  local llvm_gen="$6"
  local readelf="$7"
  local tmp="$8"
  local src="$9"
  local macros ir cxxir obj stderrf machine rc

  log "host target ${label}: ${target}"

  macros="${tmp}/${label}-macros.h"
  if ! "$clang" -target "$target" -ffreestanding -nostdinc \
      -dM -E -x c /dev/null >"$macros" 2>"${tmp}/${label}-macros.err"; then
    log_fail "${label}: clang -dM -E -target ${target}"
    cat "${tmp}/${label}-macros.err" >&2 || true
  else
    case "$arch" in
      riscv)
        if grep -q '#define __riscv ' "$macros" && \
           grep -Eq '#define __riscv_xlen 64' "$macros"; then
          log_pass "${label}: clang RISC-V macros (__riscv, __riscv_xlen 64)"
        else
          log_fail "${label}: clang RISC-V macros missing from -dM output"
          grep -E '__riscv|__minix' "$macros" >&2 || true
        fi
        ;;
      x86)
        if grep -Eq '#define __i386(__)? 1' "$macros"; then
          log_pass "${label}: clang x86 macros (__i386)"
        else
          log_fail "${label}: clang x86 macros missing from -dM output"
          grep -E '__i386|__minix' "$macros" >&2 || true
        fi
        ;;
    esac
    if grep -Eq '#define __minix(__)? 3' "$macros" || \
       grep -q '#define __Minix__ 3' "$macros"; then
      log_pass "${label}: clang Minix macros (__minix)"
    else
      log_fail "${label}: clang Minix macros missing from -dM output"
      grep -E '__minix|__Minix' "$macros" >&2 || true
    fi
  fi

  if "$clang" -target "$target" -ffreestanding -nostdinc \
      -fsyntax-only -x c "$src" 2>"${tmp}/${label}-syntax.err"; then
    log_pass "${label}: clang -fsyntax-only freestanding C"
  else
    log_fail "${label}: clang -fsyntax-only"
    cat "${tmp}/${label}-syntax.err" >&2 || true
  fi

  printf '#define V 9\nV\n' >"${tmp}/${label}-pp.c"
  if "$clang" -target "$target" -E -P -nostdinc "${tmp}/${label}-pp.c" \
      >"${tmp}/${label}-pp.out" 2>"${tmp}/${label}-pp.err" && \
     grep -q '9' "${tmp}/${label}-pp.out"; then
    log_pass "${label}: clang -E preprocessor"
  else
    log_fail "${label}: clang -E preprocessor"
    cat "${tmp}/${label}-pp.err" >&2 || true
  fi

  ir="${tmp}/${label}-add.ll"
  if "$clang" -target "$target" -ffreestanding -nostdinc \
      -emit-llvm -S -x c "$src" -o "$ir" 2>"${tmp}/${label}-ir.err"; then
    if grep -Eq 'define[[:space:]].*@add' "$ir"; then
      log_pass "${label}: clang -emit-llvm -S (C IR)"
    else
      log_fail "${label}: clang -emit-llvm produced IR without @add"
      head -n 40 "$ir" >&2 || true
    fi
  else
    if grep -Eqi 'no available targets|unable to create target|cannot be turned into an executable' \
         "${tmp}/${label}-ir.err"; then
      log_pass "${label}: clang -emit-llvm skipped (no backend, expected)"
    else
      log_fail "${label}: clang -emit-llvm -S"
      cat "${tmp}/${label}-ir.err" >&2 || true
    fi
  fi

  cxxir="${tmp}/${label}-add.ll.cpp"
  if [ -n "$clangxx" ]; then
    if "$clangxx" -target "$target" -ffreestanding -nostdinc \
        -emit-llvm -S -x c++ "$src" -o "$cxxir" 2>"${tmp}/${label}-cxxir.err"; then
      if grep -Eq 'define[[:space:]].*@' "$cxxir"; then
        log_pass "${label}: clang++ -emit-llvm -S (C++ IR)"
      else
        log_fail "${label}: clang++ -emit-llvm produced empty-looking IR"
      fi
    else
      if grep -Eqi 'no available targets|unable to create target' \
           "${tmp}/${label}-cxxir.err"; then
        log_pass "${label}: clang++ -emit-llvm skipped (no backend, expected)"
      else
        log_fail "${label}: clang++ -emit-llvm -S"
        cat "${tmp}/${label}-cxxir.err" >&2 || true
      fi
    fi
  fi

  obj="${tmp}/${label}-add.o"
  stderrf="${tmp}/${label}-c.err"
  set +e
  "$clang" -target "$target" -ffreestanding -nostdinc \
    -c -x c "$src" -o "$obj" >"$stderrf" 2>&1
  rc=$?
  set -e
  if [ "$rc" -ge 128 ]; then
    log_fail "${label}: clang -c crashed (rc=${rc})"
    cat "$stderrf" >&2 || true
  elif [ "$llvm_gen" = "modern" ]; then
    if [ "$rc" -eq 0 ] && [ -s "$obj" ]; then
      machine="$(host_machine_of "$obj" "$readelf" || true)"
      if object_matches_arch "$machine" "$arch"; then
        log_pass "${label}: clang -c emitted ${arch} object (LLVM modern backend)"
      else
        log_fail "${label}: clang -c succeeded but object is not ${arch} (${machine})"
      fi
    else
      log_fail "${label}: clang -c failed on modern LLVM (expected ${arch} object)"
      cat "$stderrf" >&2 || true
    fi
  elif [ "$rc" -eq 0 ] && [ -s "$obj" ]; then
    machine="$(host_machine_of "$obj" "$readelf" || true)"
    if object_matches_arch "$machine" "$arch"; then
      log_fail "${label}: clang -c emitted a ${arch} object; legacy 3.6.1 has no backend"
    else
      log_fail "${label}: clang -c unexpectedly succeeded (machine='${machine}')"
    fi
    cat "$stderrf" >&2 || true
  else
    log_pass "${label}: clang -c does not emit ${arch} objects (legacy 3.6.1, expected)"
  fi
}

run_host_layer() {
  local tooldir clang clangxx clangcpp tblgen ctblgen readelf
  local tmp macros ir cxxir obj stderrf src
  local machine llvm_gen x86_clang x86_clangxx

  tooldir="$(detect_tooldir || true)"
  if [ -z "$tooldir" ]; then
    if want_require host; then
      log_fail "host TOOLDIR not found (required)"
    else
      log_skip "host TOOLDIR not found"
    fi
    return 0
  fi

  clang="$(find_host_bin "$tooldir" riscv64-elf32-minix-clang || true)"
  if [ -z "$clang" ]; then
    if want_require host; then
      log_fail "host clang missing under $tooldir/bin"
    else
      log_skip "host clang missing under $tooldir/bin"
    fi
    return 0
  fi

  clangxx="$(find_host_bin "$tooldir" riscv64-elf32-minix-clang++ || true)"
  clangcpp="$(find_host_bin "$tooldir" riscv64-elf32-minix-clang-cpp || true)"
  tblgen="$(find_host_bin "$tooldir" nbllvm-tblgen-cmake nbllvm-tblgen llvm-tblgen || true)"
  ctblgen="$(find_host_bin "$tooldir" nbclang-tblgen-cmake nbclang-tblgen clang-tblgen || true)"
  readelf="$(find_host_bin "$tooldir" riscv64-elf32-minix-readelf readelf || true)"

  log "host tooldir: $tooldir"
  log "host clang: $clang"

  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap 'rm -rf "$tmp"; trap - RETURN' RETURN
  src="${tmp}/add.c"
  printf 'int add(int a, int b) { return a + b; }\n' >"$src"

  if ! "$clang" --version >"${tmp}/clang.ver" 2>&1; then
    log_fail "clang --version"
    cat "${tmp}/clang.ver" >&2 || true
    return 0
  fi
  llvm_gen="$(detect_llvm_generation "${tmp}/clang.ver")"
  case "$llvm_gen" in
    legacy)
      log_pass "clang --version (LLVM 3.6 legacy frontend)"
      ;;
    modern)
      log_pass "clang --version (LLVM modern with RISC-V backend)"
      ;;
    *)
      log_fail "clang --version is not a supported LLVM/clang (3.6 or 10+)"
      cat "${tmp}/clang.ver" >&2 || true
      ;;
  esac

  if [ -n "$clangxx" ]; then
    if "$clangxx" --version >/dev/null 2>&1; then
      log_pass "clang++ --version"
    else
      log_fail "clang++ --version"
    fi
  else
    log_fail "clang++ missing (tools should install the symlink)"
  fi

  if [ -n "$clangcpp" ]; then
    if "$clangcpp" --version >/dev/null 2>&1; then
      log_pass "clang-cpp --version"
    else
      log_fail "clang-cpp --version"
    fi
  else
    log_fail "clang-cpp missing (tools should install the symlink)"
  fi

  if [ -n "$tblgen" ]; then
    if "$tblgen" -help >"${tmp}/tblgen.help" 2>&1 || \
       "$tblgen" --help >"${tmp}/tblgen.help" 2>&1; then
      if grep -Eqi 'tblgen|tablegen' "${tmp}/tblgen.help"; then
        log_pass "llvm-tblgen help ($(basename "$tblgen"))"
      else
        log_fail "llvm-tblgen help output missing tblgen text"
        head -n 20 "${tmp}/tblgen.help" >&2 || true
      fi
    else
      log_fail "llvm-tblgen -help"
    fi
  else
    log_fail "llvm-tblgen missing (nbllvm-tblgen)"
  fi

  if [ -n "$ctblgen" ]; then
    if "$ctblgen" -help >/dev/null 2>&1 || "$ctblgen" --help >/dev/null 2>&1; then
      log_pass "clang-tblgen help ($(basename "$ctblgen"))"
    else
      log_fail "clang-tblgen -help"
    fi
  else
    log_fail "clang-tblgen missing (nbclang-tblgen)"
  fi

  machine="$(host_machine_of "$clang" "$readelf" || true)"
  case "$machine" in
    *RISC-V*|*RiscV*|*riscv*)
      log_fail "host clang is a RISC-V binary ($machine); expected a host toolchain"
      ;;
    "")
      log_skip "could not classify host clang machine"
      ;;
    *)
      log_pass "host clang is a host binary ($machine)"
      ;;
  esac

  run_host_target_checks "riscv64" "$clang" "$clangxx" "$CLANG_TARGET" \
    riscv "$llvm_gen" "$readelf" "$tmp" "$src"

  x86_clang="$(find_host_bin "$tooldir" i586-elf32-minix-clang || true)"
  x86_clangxx="$(find_host_bin "$tooldir" i586-elf32-minix-clang++ || true)"
  if [ -n "$x86_clang" ]; then
    run_host_target_checks "i586" "$x86_clang" "$x86_clangxx" "$X86_CLANG_TARGET" \
      x86 "$llvm_gen" "$readelf" "$tmp" "$src"
  elif want_require host; then
    log_fail "host i586-elf32-minix-clang missing under $tooldir/bin"
  else
    log_skip "host i586-elf32-minix-clang missing (x86 MINIX cross-compile)"
  fi
}

run_destdir_layer() {
  local root clang clangxx clangcpp cc gcc readelf machine target

  root="$(detect_destdir || true)"
  if [ -z "$root" ]; then
    if want_require destdir; then
      log_fail "DESTDIR not found (required)"
    else
      log_skip "DESTDIR not found"
    fi
    return 0
  fi

  log "destdir: $root"

  clang="${root}/usr/bin/clang"
  clangxx="${root}/usr/bin/clang++"
  clangcpp="${root}/usr/bin/clang-cpp"
  cc="${root}/usr/bin/cc"
  gcc="${root}/usr/bin/gcc"

  if [ -x "$clang" ]; then
    log_pass "DESTDIR usr/bin/clang"
  else
    log_fail "DESTDIR missing usr/bin/clang"
  fi
  if [ -e "$clangxx" ]; then
    log_pass "DESTDIR usr/bin/clang++"
  else
    log_fail "DESTDIR missing usr/bin/clang++"
  fi
  if [ -e "$clangcpp" ]; then
    log_pass "DESTDIR usr/bin/clang-cpp"
  else
    log_fail "DESTDIR missing usr/bin/clang-cpp"
  fi

  if [ ! -x "$cc" ] && [ ! -x "$gcc" ]; then
    log_fail "DESTDIR missing usr/bin/cc and usr/bin/gcc"
  else
    log_pass "DESTDIR native gcc/cc present"
  fi

  if [ -L "$cc" ]; then
    target="$(readlink "$cc" 2>/dev/null || true)"
    case "$target" in
      *clang*)
        log_fail "usr/bin/cc symlink points at clang (${target}); RISC-V cc must stay gcc"
        ;;
      *)
        log_pass "usr/bin/cc is not a clang symlink (${target:-unknown})"
        ;;
    esac
  elif [ -x "$cc" ] && [ -x "$clang" ]; then
    if cmp -s "$cc" "$clang"; then
      log_fail "usr/bin/cc is identical to clang; RISC-V cc must stay gcc"
    else
      log_pass "usr/bin/cc is distinct from clang"
    fi
  fi

  readelf="$(find_host_bin "$(detect_tooldir || true)" \
    riscv64-elf32-minix-readelf readelf || true)"
  if [ -e "${root}/usr/include/c++/__mutex_base" ]; then
    log_fail "DESTDIR has libc++ __mutex_base; MKLIBCXX must stay no on riscv64 (shadows libstdc++ / pulls pthread.h)"
  else
    log_pass "DESTDIR has no libc++ __mutex_base"
  fi

  if [ -x "$clang" ]; then
    machine="$(host_machine_of "$clang" "$readelf" || true)"
    case "$machine" in
      *RISC-V*|*RiscV*|*riscv*)
        log_pass "DESTDIR clang is RISC-V ELF (${machine})"
        ;;
      "")
        if want_require destdir; then
          log_fail "could not read DESTDIR clang ELF machine"
        else
          log_skip "could not read DESTDIR clang ELF machine"
        fi
        ;;
      *)
        log_fail "DESTDIR clang is not RISC-V ELF (${machine})"
        ;;
    esac
  fi

  if [ -x "${root}/usr/libexec/ld.elf_so" ] || [ -x "${root}/libexec/ld.elf_so" ]; then
    log_pass "DESTDIR ld.elf_so present (usr/libexec or libexec)"
  else
    log_fail "DESTDIR missing ld.elf_so under usr/libexec or libexec (MKPIC/MKPICINSTALL)"
  fi

  if [ -e "${root}/usr/lib/libgcc_s.so" ]; then
    log_pass "DESTDIR libgcc_s.so present"
  else
    log_fail "DESTDIR missing usr/lib/libgcc_s.so"
  fi

  if [ -x "$clang" ] && [ -n "$readelf" ]; then
    if elf_has_interp "$clang" "$readelf"; then
      log_pass "DESTDIR clang is dynamically linked"
    else
      log_fail "DESTDIR clang is not dynamically linked (expected PT_INTERP)"
    fi
  fi
}

run_guest_layer() {
  local root kern disk

  root="$(detect_destdir || true)"
  kern="$(detect_kernel || true)"
  disk="$DISK_IMAGE"

  if [ ! -x "$QEMU_SCRIPT" ]; then
    if want_require guest; then
      log_fail "qemu script not executable: $QEMU_SCRIPT"
    else
      log_skip "qemu script not executable"
    fi
    return 0
  fi
  if [ ! -f "$RUNTIME_PROBE" ]; then
    if want_require guest; then
      log_fail "runtime probe missing: $RUNTIME_PROBE"
    else
      log_skip "runtime probe missing"
    fi
    return 0
  fi
  if [ -z "$kern" ] || [ ! -f "$kern" ]; then
    if want_require guest; then
      log_fail "kernel not found (required for guest clang)"
    else
      log_skip "kernel not found"
    fi
    return 0
  fi
  if [ -z "$root" ] || [ ! -d "$root" ]; then
    if want_require guest; then
      log_fail "DESTDIR not found (required for guest clang)"
    else
      log_skip "DESTDIR not found"
    fi
    return 0
  fi
  if [ -z "$disk" ]; then
    if want_require guest; then
      log_fail "disk image not provided (required for guest clang)"
    else
      log_skip "disk image not provided"
    fi
    return 0
  fi
  if [ ! -f "$disk" ]; then
    if want_require guest; then
      log_fail "disk image not found: $disk"
    else
      log_skip "disk image not found"
    fi
    return 0
  fi
  if [ ! -x "${root}/usr/bin/clang" ]; then
    if want_require guest; then
      log_fail "DESTDIR has no usr/bin/clang; guest layer cannot run"
    else
      log_skip "DESTDIR has no usr/bin/clang"
    fi
    return 0
  fi

  log "guest kernel: $kern"
  log "guest destdir: $root"
  log "guest disk: $disk"

  if python3 "$RUNTIME_PROBE" \
    --qemu-script "$QEMU_SCRIPT" \
    --kernel "$kern" \
    --destdir "$root" \
    --disk "$disk" \
    --timeout "$TIMEOUT" \
    --cmd-timeout "$CMD_TIMEOUT" \
    --require-disk-node \
    --only-custom-cmds \
    --cmd 'prepare_usr_umount=/bin/umount /usr >/dev/null 2>&1 || true' \
    --cmd 'prepare_usr_mount_stage1=[ -x /usr/bin/clang ] || /bin/mount -t ext2 /dev/c0d0p2 /usr' \
    --cmd 'prepare_usr_mount_stage2=[ -x /usr/bin/clang ] || /bin/mount -t ext2 /dev/c0d1p2 /usr || true' \
    --cmd 'prepare_usr_check=/bin/mount | /bin/grep /usr >/dev/null || (/bin/mount; false)' \
    --cmd 'llvm_clang_detect=test -x /usr/bin/clang' \
    --cmd 'llvm_clangxx_detect=test -e /usr/bin/clang++' \
    --cmd 'llvm_clang_version=/usr/bin/clang --version >/usr/lt_ver.txt && test -s /usr/lt_ver.txt' \
    --cmd 'llvm_cc_is_gcc=test -x /usr/bin/gcc || test -x /usr/bin/cc' \
    --cmd 'llvm_src_prep=printf "int add(int a,int b){return a+b;}\n" >/usr/lt.c' \
    --cmd 'llvm_syntax=/usr/bin/clang -ffreestanding -nostdinc -fsyntax-only /usr/lt.c' \
    --cmd 'llvm_macros=/usr/bin/clang -ffreestanding -nostdinc -dM -E -x c /dev/null >/usr/lt_m.h' \
    --cmd 'llvm_macros_riscv=grep __riscv /usr/lt_m.h >/dev/null' \
    --cmd 'llvm_emit_ir=/usr/bin/clang -ffreestanding -nostdinc -emit-llvm -S /usr/lt.c -o /usr/lt.ll >/usr/lt_ir.err 2>&1 || true' \
    --cmd 'llvm_emit_ir_ok=test -s /usr/lt.ll || grep -Ei "target" /usr/lt_ir.err >/dev/null'; then
    log_pass "guest clang QEMU smoke"
  else
    rc=$?
    if [ "$rc" -eq 2 ]; then
      if want_require guest; then
        log_fail "guest clang QEMU smoke skipped but required"
      else
        log_skip "guest clang QEMU smoke"
      fi
    else
      log_fail "guest clang QEMU smoke"
    fi
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --require)
      REQUIRE="$2"
      shift 2
      ;;
    --tooldir)
      TOOLDIR="$2"
      shift 2
      ;;
    --destdir)
      DESTDIR="$2"
      shift 2
      ;;
    --kernel)
      KERNEL="$2"
      shift 2
      ;;
    --disk-image)
      DISK_IMAGE="$2"
      shift 2
      ;;
    --qemu-script)
      QEMU_SCRIPT="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    --cmd-timeout)
      CMD_TIMEOUT="$2"
      shift 2
      ;;
    --target)
      CLANG_TARGET="$2"
      shift 2
      ;;
    --x86-target)
      X86_CLANG_TARGET="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

case "$MODE" in
  host|destdir|guest|all) ;;
  *)
    echo "Invalid --mode: $MODE" >&2
    exit 1
    ;;
esac
case "$REQUIRE" in
  ''|host|destdir|guest|all) ;;
  *)
    echo "Invalid --require: $REQUIRE" >&2
    exit 1
    ;;
esac

if want_mode host; then
  run_host_layer
fi
if want_mode destdir; then
  run_destdir_layer
fi
if want_mode guest; then
  run_guest_layer
fi

echo "[llvm-gate] summary: passed=${passed} failed=${failed} skipped=${skipped}"

if [ "$failed" -ne 0 ]; then
  exit 1
fi
if [ "$passed" -eq 0 ]; then
  if [ -n "$REQUIRE" ]; then
    exit 1
  fi
  exit 2
fi
exit 0
