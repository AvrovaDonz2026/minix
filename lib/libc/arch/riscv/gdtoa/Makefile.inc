#	$NetBSD: Makefile.inc,v 1.1 2014/09/19 17:36:25 matt Exp $

# MINIX keeps the 64-bit long double ABI on RISC-V, so strtold uses the
# generic double-precision alias path from lib/libc/gdtoa/strtod.c.
SRCS+=	strtof.c
