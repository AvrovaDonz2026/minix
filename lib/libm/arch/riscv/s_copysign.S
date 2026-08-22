/* $NetBSD: s_copysign.S,v 1.4 2015/03/27 23:35:40 matt Exp $ */

/* The contents of this file are in the public domain. */

#include <machine/asm.h>
#include <machine/math.h>

#ifndef __HAVE_LONG_DOUBLE
STRONG_ALIAS(_copysignl, copysign)
WEAK_ALIAS(copysignl, _copysignl)
#endif

ENTRY(copysign)
	fsgnj.d	fa0, fa0, fa1
	ret
END(copysign)
