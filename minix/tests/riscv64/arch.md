# minix/tests/riscv64 Directory Architecture

## Overview
This document summarizes the top-level, git-tracked contents of `minix/tests/riscv64`.

## Top-level entries
### Directories (0)
- (none)

### Files (22)
- `Makefile`
- `arch.md`
- `llvm_toolchain_gate.sh`
- `multi_smoke_gate.sh`
- `native_toolchain_build.sh`
- `native_toolchain_gate.sh`
- `qemu_io_smoke.py`
- `qemu_net_smoke.py`
- `qemu_runtime_probe.py`
- `repro_build_gate.sh`
- `run_tests.sh`
- `safecopy_triage.py`
- `test_atomic.c`
- `test_csr.c`
- `test_ipc.c`
- `test_memory.c`
- `test_sbi.c`
- `test_timer.c`
- `test_trap.c`
- `test_virtio_blk_mmio.c`
- `test_virtio_event_idx.c`
- `test_virtio_net_hdr.c`
- `test_vm.c`

## Notes
- Entries listed are tracked in git; untracked and ignored files are omitted.
- Log files (`*.log` and `*.log.*`) and `_tmp` directories are intentionally excluded.
- VCS metadata directories (.git, .hg, .svn, .bzr) are omitted.
- `__pycache__/` is untracked and must not be committed.
- `run_tests.sh` top-level targets: `build`, `user`, `kernel`, `gate`,
  `native`, `llvm`, `all`.
- `llvm_toolchain_gate.sh` is the MKLLVM host/DESTDIR/guest functional gate
  (frontend, IR, tblgen, guest clang). DESTDIR also rejects libc++
  `__mutex_base` so `/usr/include/c++` cannot shadow libstdc++. It skips
  when clang is absent so GCC-only `run_tests.sh all` still passes.
