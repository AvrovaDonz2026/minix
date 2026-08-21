/* $NetBSD: s_fabs.S,v 1.2 2015/03/27 23:35:40 matt Exp $ */

/* The contents of this file are in the public domain. */

#include <machine/asm.h>
#include <machine/math.h>

#ifndef __HAVE_LONG_DOUBLE
STRONG_ALIAS(fabsl, fabs)
#endif

ENTRY(fabs)
	fabs.d	fa0, fa0
	ret
END(fabs)
