/*
 * RISC-V 64 SMP support
 *
 * Secondary harts wait in head.S until _secondary_start_flag is set.
 * IPIs use SBI SEND_IPI (SSIP). Scheduling/halt IPIs share SSIP and are
 * demuxed via riscv_ipi_action[].
 */

#include <assert.h>

#include "kernel/kernel.h"
#include "kernel/smp.h"
#include "kernel/clock.h"
#include "arch_proto.h"

extern volatile u64_t _secondary_start_flag;

int riscv_hart_to_cpu[256];
unsigned char riscv_cpu_to_hart[CONFIG_MAX_CPUS];

static volatile unsigned char riscv_ipi_action[CONFIG_MAX_CPUS];

#define IPI_ACTION_NONE		0
#define IPI_ACTION_SCHED	1
#define IPI_ACTION_HALT		2

static volatile int ap_cpu_ready = -1;
static volatile int cpu_down = -1;

static int discover_harts(int max_harts)
{
	int hart;
	int bsp_hart = riscv_current_hart();

	for (hart = 0; hart < 256; hart++)
		riscv_hart_to_cpu[hart] = -1;

	riscv_hart_to_cpu[bsp_hart] = 0;
	riscv_cpu_to_hart[0] = (unsigned char)bsp_hart;
	ncpus = 1;

	for (hart = 0; hart < max_harts && ncpus < CONFIG_MAX_CPUS; hart++) {
		if (hart == bsp_hart)
			continue;
		riscv_hart_to_cpu[hart] = ncpus;
		riscv_cpu_to_hart[ncpus] = (unsigned char)hart;
		ncpus++;
	}

	bsp_cpu_id = 0;
	return ncpus;
}

static void wake_secondary_harts(void)
{
	unsigned cpu;
	unsigned long mask = 0;

	__sync_synchronize();
	_secondary_start_flag = 1;
	__sync_synchronize();

	for (cpu = 1; cpu < ncpus; cpu++)
		mask |= 1UL << riscv_cpu_to_hart[cpu];

	if (mask != 0)
		sbi_send_ipi(mask);
}

static void wait_for_ap_boot(unsigned cpu, u64_t timeout_cycles)
{
	u64_t start = arch_get_timestamp();

	while (ap_cpu_ready != (int)cpu) {
		if (arch_get_timestamp() - start > timeout_cycles) {
			printf("WARNING : CPU %u didn't boot\n", cpu);
			return;
		}
		arch_pause();
	}
	cpu_set_flag(cpu, CPU_IS_READY);
}

static void ap_finish_booting(int cpu)
{
	spinlock_lock(&boot_lock);
	BKL_LOCK();

	printf("CPU %u is online\n", cpu);

	cpu_identify();
	plic_init_cpu(riscv_cpu_to_hart[cpu]);
	exception_init();
	csr_set_sie(SIE_SSIE);
	fpu_init();

	if (app_cpu_init_timer(system_hz)) {
		panic("FATAL : failed to initialize timer on CPU %u", cpu);
	}

	get_cpulocal_var(proc_ptr) = get_cpulocal_var_ptr(idle_proc);
	get_cpulocal_var(bill_ptr) = get_cpulocal_var_ptr(idle_proc);

	ap_cpu_ready = cpu;
	ap_boot_finished(cpu);
	__asm__ __volatile__("mv tp, %0" :: "r"(
	    (unsigned long)riscv_cpu_to_hart[cpu]));
	spinlock_unlock(&boot_lock);

	switch_to_user();
	NOT_REACHABLE;
}

void riscv_smp_ap_entry(int hart_id);
void __k_unpaged_riscv_smp_ap_entry(int hart_id);

void __k_unpaged_riscv_smp_ap_entry(int hart_id)
{
	riscv_smp_ap_entry(hart_id);
}

void riscv_smp_ap_entry(int hart_id)
{
	int cpu = riscv_hart_to_cpu[hart_id];

	if (cpu < 0) {
		printf("WARNING : unknown hart %d, halting\n", hart_id);
		for (;;)
			wfi();
	}

	ap_finish_booting(cpu);
}

void riscv_smp_early_init(void)
{
	int hart;
	int i;

	__asm__ __volatile__("mv %0, tp" : "=r"(hart));
	for (i = 0; i < 256; i++)
		riscv_hart_to_cpu[i] = -1;
	riscv_hart_to_cpu[hart] = 0;
	riscv_cpu_to_hart[0] = (unsigned char)hart;
	ncpus = 1;
	bsp_cpu_id = 0;
}

void smp_init(void)
{
	int max_harts;
	int cpu;

	max_harts = bsp_get_num_cpus();
	if (max_harts < 1)
		max_harts = 1;
	if (max_harts > CONFIG_MAX_CPUS)
		max_harts = CONFIG_MAX_CPUS;

	if (discover_harts(max_harts) <= 1) {
		printf("SMP: single CPU (hart %d)\n", riscv_current_hart());
		return;
	}

	printf("SMP: booting %u CPUs (BSP hart %d, logical CPU %u)\n",
	    ncpus, riscv_current_hart(), bsp_cpu_id);

	wake_secondary_harts();

	for (cpu = 1; cpu < ncpus; cpu++)
		wait_for_ap_boot(cpu, bsp_get_timer_freq() * 5);

	printf("SMP: %u CPUs online\n", ncpus);
	csr_set_sie(SIE_SSIE);
}

void smp_ipi_handler(struct trapframe *tf)
{
	unsigned cpu = cpuid;
	unsigned action;

	(void)tf;

	action = riscv_ipi_action[cpu];
	riscv_ipi_action[cpu] = IPI_ACTION_NONE;
	barrier();

	if (action == IPI_ACTION_HALT)
		smp_ipi_halt_handler();
	else
		smp_ipi_sched_handler();
}

void riscv_ipi_ack(void)
{
	csr_clear_sip(SIP_SSIP);
}

void arch_send_smp_schedule_ipi(unsigned cpu)
{
	assert(cpu < ncpus);
	riscv_ipi_action[cpu] = IPI_ACTION_SCHED;
	barrier();
	sbi_send_ipi(1UL << riscv_cpu_to_hart[cpu]);
}

void arch_smp_halt_cpu(void)
{
	cpu_down = cpuid;
	barrier();
	BKL_UNLOCK();
	for (;;)
		wfi();
}

void smp_shutdown_aps(void)
{
	unsigned cpu;

	if (ncpus <= 1)
		return;

	BKL_UNLOCK();

	for (cpu = 0; cpu < ncpus; cpu++) {
		if (cpu == cpuid)
			continue;
		if (!cpu_test_flag(cpu, CPU_IS_READY))
			continue;

		cpu_down = -1;
		riscv_ipi_action[cpu] = IPI_ACTION_HALT;
		barrier();
		sbi_send_ipi(1UL << riscv_cpu_to_hart[cpu]);

		while (cpu_down != (int)cpu)
			arch_pause();

		printf("CPU %u is down\n", cpu);
		cpu_clear_flag(cpu, CPU_IS_READY);
	}

	ncpus = 1;
}
