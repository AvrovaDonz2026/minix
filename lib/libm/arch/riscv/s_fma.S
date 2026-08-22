/* $NetBSD: s_fma.S,v 1.2 2015/03/27 23:35:40 matt Exp $ */

/* The contents of this file are in the public domain. */

#include <machine/asm.h>
#include <machine/math.h>

#ifndef __HAVE_LONG_DOUBLE
STRONG_ALIAS(fmal, fma)
#endif

ENTRY(fma)
	fmadd.d	fa0, fa0, fa1, fa2
	ret
END(fma)
