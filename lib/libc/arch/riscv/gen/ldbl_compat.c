/*	$NetBSD$	*/

#include <sys/cdefs.h>
#if defined(LIBC_SCCS) && !defined(lint)
__RCSID("$NetBSD$");
#endif

#include <math.h>

long double
__addtf3(long double a, long double b)
{

	return (long double)((double)a + (double)b);
}

long double
__subtf3(long double a, long double b)
{

	return (long double)((double)a - (double)b);
}

long double
__multf3(long double a, long double b)
{

	return (long double)((double)a * (double)b);
}

long double
__divtf3(long double a, long double b)
{

	return (long double)((double)a / (double)b);
}

int
__fpclassifyl(long double x)
{

	return __builtin_fpclassify(FP_NAN, FP_INFINITE,
	    FP_NORMAL, FP_SUBNORMAL, FP_ZERO, (double)x);
}
