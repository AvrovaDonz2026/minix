#ifndef __ARCH_SMP_H__
#define __ARCH_SMP_H__

#include "archconst.h"

#ifndef __ASSEMBLY__

extern int riscv_hart_to_cpu[256];
extern unsigned char riscv_cpu_to_hart[CONFIG_MAX_CPUS];
extern unsigned bsp_cpu_id;

int cpu_number(void);

static inline int riscv_cpuid(void)
{
	int hart = cpu_number();
	int cpu;

	if (hart >= 0 && hart < 256)
		cpu = riscv_hart_to_cpu[hart];
	else
		cpu = -1;
	if (cpu < 0)
		cpu = (int)bsp_cpu_id;
	return cpu;
}

static inline int riscv_current_hart(void)
{
	return cpu_number();
}

#define cpuid	riscv_cpuid()

#define smp_single_cpu_fallback() do {		\
	bsp_cpu_id = 0;				\
	ncpus = 1;				\
	bsp_finish_booting();			\
} while(0)

#define barrier() do {				\
	__asm__ __volatile__("fence rw, rw" ::: "memory"); \
} while(0)

void riscv_ipi_ack(void);

#define ipi_ack()	riscv_ipi_ack()

#endif /* __ASSEMBLY__ */

#endif /* __ARCH_SMP_H__ */
