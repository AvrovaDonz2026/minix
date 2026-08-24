/* Provide __global_pointer$ for toolchains that only export _gp. */
#if defined(__riscv)
__asm__(".globl __global_pointer$\n"
    ".set __global_pointer$, _gp\n");
#endif
