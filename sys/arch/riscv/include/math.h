/*	$NetBSD$	*/

#define	__HAVE_NANF
/*
 * RISC-V lp64/lp64d uses IEEE binary128 long double. Without this,
 * s_copysign.c is replaced by arch/riscv/s_copysign.S (no _copysignl
 * alias) and s_copysignl.c emits nothing, so libm.so has an undefined
 * _copysignl (lua and other -lm links fail).
 */
#define	__HAVE_LONG_DOUBLE	128
