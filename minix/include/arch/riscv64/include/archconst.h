/*
 * RISC-V 64 architecture constants for MINIX
 */

#ifndef _RISCV64_ARCHCONST_H
#define _RISCV64_ARCHCONST_H

/* Clock frequency (Hz) - default for QEMU virt */
#define CLOCK_FREQ      10000000
#define DEFAULT_HZ      1000

/*
 * User address space limits.
 * Userland is currently built with the rv64 ilp32 ABI (32-bit pointers),
 * so user virtual addresses must stay below 4GB.
 */
/*
 * Keep the top below 2GB so sign-extension of 32-bit user pointers on RV64
 * will still map into the same canonical low address range.
 */
#define USR_DATATOP     0x70000000UL
#define USR_STACKTOP    0x70000000UL
#define USR_DATATOP_COMPACT USR_DATATOP
#define USR_STACKTOP_COMPACT USR_STACKTOP

#endif /* _RISCV64_ARCHCONST_H */
