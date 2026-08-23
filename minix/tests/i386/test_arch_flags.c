/*
 * i386 user-space compile smoke.
 *
 * Built with the i586 cross compiler against the distribution sysroot to
 * verify headers and basic C99 compilation for the guest toolchain.
 */

#include <stdint.h>

uint32_t
arch_flags_smoke(void)
{
	return (uint32_t)sizeof(void *);
}
