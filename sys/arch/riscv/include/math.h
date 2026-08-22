/*	$NetBSD$	*/

#define	__HAVE_NANF
/*
 * In-tree gcc 4.8.5 for RISC-V uses 64-bit long double
 * (__SIZEOF_LONG_DOUBLE__ == 8, __LDBL_MANT_DIG__ == 53).  Do not set
 * __HAVE_LONG_DOUBLE to 128: that compiles s_cbrtl.c and friends as
 * IEEE binary128 against float.h values that default to double
 * (LDBL_MANT_DIG 53), which #error.  Provide *l aliases from the
 * arch/riscv .S files that replace the C sources.
 */
