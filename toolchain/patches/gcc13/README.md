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

- `gcc-dist/0001-gcc13-config-gcc-add-minix-riscv-target.patch`
  - Add generic `*-*-minix*` OS defaults in `gcc/config.gcc`.
  - Add an explicit `riscv*-*-minix*` target case in `gcc/config.gcc`.
- `gcc-dist/0002-gcc13-libgcc-add-riscv-minix-host-case.patch`
  - Add an explicit `riscv*-*-minix*` stanza in `libgcc/config.host`.

These `gcc-dist` patches are the first bootstrap step toward removing the
`riscv64-unknown-elf` workspace override. They are intentionally minimal and
safe to keep enabled while the spike still uses the temporary target shim.
