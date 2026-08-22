#include <stddef.h>

#if defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wreturn-local-addr"
#endif

void *
alloca(size_t size)
{
	return __builtin_alloca(size);
}

#if defined(__GNUC__)
#pragma GCC diagnostic pop
#endif
