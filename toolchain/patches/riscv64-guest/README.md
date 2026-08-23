# RISC-V Guest Dist Patches

Tracked patches for MINIX riscv64 guest packaging. Apply before
`distribution` when building LLVM guest images.

## Layout

- `gcc-dist/`: patches under `external/gpl3/gcc/dist` (gitignored tree).
- `llvm-dist/`: patches under `external/bsd/llvm/dist`.
- `scripts/apply-guest-dist-patches.sh`: idempotent apply helper.

## Patches

- `gcc-dist/0001-libstdcxx-functexcept-minix-no-future.patch`
  - Guard `__throw_future_error` with `_GLIBCXX_MINIX_NO_FUTURE`.
  - Pairs with `CPPFLAGS.functexcept.cc+= -D_GLIBCXX_MINIX_NO_FUTURE=1`
    in `external/gpl3/gcc/lib/libstdc++-v3/arch/riscv64/defs.mk`.
- `llvm-dist/0001-llvm-path-getMainExecutable-minix-fallback.patch`
  - Resolve bare `argv[0]` names via `/usr/bin/<basename>` on MINIX.

## Usage

```bash
bash toolchain/patches/riscv64-guest/scripts/apply-guest-dist-patches.sh
```

Patches apply in lexical order and skip cleanly when already present.
