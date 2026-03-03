# GCC 13 Patch Stack (Patch-Only Policy)

This directory stores MINIX GCC13 integration changes as small, scoped units.

## Layout

- `gcc-dist/`: patches for upstream GCC sources under `external/gpl3/gcc/dist`.
- `workspace/`: patches for MINIX build wrappers (for example `tools/gcc/Makefile`).
- `scripts/`: CI/runtime shims that cannot be expressed as static source patches.

## Rules

- Do not commit direct edits under `external/gpl3/gcc/dist`.
- Keep each patch focused on one behavior change.
- Apply patches in lexical order (`0001`, `0002`, ...).
- Prefer one failure domain per patch: host flags, target triple, sysroot prep,
  compatibility links, etc.

## Current workspace patch set

- `workspace/0001-tools-gcc-host-cxx11.patch`
  - Switch host C++ mode from `gnu++98` to `gnu++11` for GCC13 configure.
- `workspace/0002-tools-gcc-target-triplet-override.patch`
  - Override `MACHINE_GNU_PLATFORM` to `riscv64-unknown-elf` in the GCC tools
    wrapper for spike-only compatibility.

## Current GCC dist patch set

- No GCC13 MINIX target hooks are committed yet.
