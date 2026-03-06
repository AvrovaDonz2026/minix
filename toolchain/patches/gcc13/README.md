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
  compatibility links, compiler ABI glue, etc.

## Current workspace patch set

- `workspace/0001-tools-gcc-host-cxx11.patch`
  - Switch host C++ mode from `gnu++98` to `gnu++11` for GCC13 configure.
- `workspace/0002-tools-gcc-target-triplet-override.patch`
  - Override `MACHINE_GNU_PLATFORM` to `riscv64-unknown-elf` in the GCC tools
    wrapper for spike-only compatibility.

## Current GCC dist patch set

- `gcc-dist/0001-gcc13-config-gcc-add-minix-riscv-target.patch`
  - Add generic `*-*-minix*` OS defaults in `gcc/config.gcc`.
  - Wire the RISC-V MINIX target through `minix-spec.h`, `minix.h`, `t-minix`,
    and the new arch-specific target header.
- `gcc-dist/0002-gcc13-libgcc-add-riscv-minix-host-case.patch`
  - Add an explicit `riscv*-*-minix*` stanza in `libgcc/config.host`.
  - Keep TF soft-fp support available in `libgcc` for compatibility shims.
- `gcc-dist/0004-gcc13-riscv-add-minix-target-header.patch`
  - Add `gcc/config/riscv/minix.h` to force the historical MINIX RISC-V
    `long double` ABI (`64-bit`) and preserve MINIX CPU builtins.

These `gcc-dist` patches are the compiler-side ABI glue required for native
`riscv64-elf32-minix` GCC13 builds. The shim-mode workspace override remains
available for spike experiments, but the native workflow should now exercise
true MINIX target settings instead of inheriting the upstream generic RISC-V
`long double=128` default.
