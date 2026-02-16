/*
 * RISC-V 64 architecture constants for MINIX
 */

#ifndef _RISCV64_ARCHCONST_H
#define _RISCV64_ARCHCONST_H

/* Clock frequency (Hz) - default for QEMU virt */
#define CLOCK_FREQ      10000000
#define DEFAULT_HZ      1000

/* User address space limits (Sv39, 256 GB user range). */
#define USR_DATATOP     0x0000003FF0000000ULL
#define USR_STACKTOP    0x0000003FF0000000ULL
#define USR_DATATOP_COMPACT USR_DATATOP
#define USR_STACKTOP_COMPACT USR_STACKTOP

#endif /* _RISCV64_ARCHCONST_H */
