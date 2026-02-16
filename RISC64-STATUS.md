# MINIX RISC-V 64-bit Port Status / MINIX RISC-V 64 位移植状态

**Date / 日期**: 2026-01-31  
**Version / 版本**: 1.3  
**Status / 状态**: Phase 1 in progress — buildable with workarounds, runtime unstable  
**Progress / 进度**: ~60% (core kernel present; VM/IO issues outstanding)

## Summary / 摘要

**中文**
- 构建可通过（需使用绕过项与特定构建变量），详见 `README-RISCV64.md`。
- QEMU 可启动并进入 shell，但用户态仍不稳定（`minix-service` 启动 virtio_blk_mmio 时 SIGSEGV）。
- 关键风险集中在页表根传参、UART、TLB 刷新与 SBI IPI/fence 路径（见 `issue.md`）。
- 2026-01-31 已完成 tools + distribution 构建并运行 `run_tests.sh all`。
  用户态编译测试全部通过；内核启动与定时器测试通过；SMP 跳过；virtio 块设备 I/O smoke 失败。

**English**
- Build passes with workaround flags; see `README-RISCV64.md` for exact commands.
- QEMU reaches a shell prompt, but user space remains unstable (`minix-service` SIGSEGV when starting virtio_blk_mmio).
- Key risks are in page-table root handoff, UART, TLB flush, and SBI IPI/fence paths (see `issue.md`).
- 2026-01-31: tools + distribution built and `run_tests.sh all` executed.
  User-level compile tests pass; kernel boot + timer pass; SMP skipped; virtio block I/O smoke fails.

## Build Status / 构建状态

**中文**
- 基线命令：使用 GCC、禁用 LLVM/C++、放宽 `checkflist`（见 `README-RISCV64.md`）。
- 产物：`minix/kernel/obj/kernel` 与 `obj/destdir.evbriscv64`。
- 限制：`CHECKFLIST_FLAGS='-m -e'` 为临时绕过，需在 sets 完整后移除。
- 补充：tools 可在修复 LLVM `ValueMap.h` 后构建；内核可用 GCC + `MAKEOBJDIRPREFIX` 重建
  （`RISCV_ARCH_FLAGS='-march=RV64IMAFD -mcmodel=medany'`，当前工具链不接受 `-mabi=lp64d`）。

**English**
- Baseline: GCC, LLVM/C++ disabled, relaxed `checkflist` (see `README-RISCV64.md`).
- Outputs: `minix/kernel/obj/kernel` and `obj/destdir.evbriscv64`.
- Limitation: `CHECKFLIST_FLAGS='-m -e'` is a temporary workaround until sets are complete.
- Note: tools now build with LLVM after the `ValueMap.h` fix; kernel rebuild works with GCC +
  `MAKEOBJDIRPREFIX` (`RISCV_ARCH_FLAGS='-march=RV64IMAFD -mcmodel=medany'`, toolchain rejects `-mabi=lp64d`).

## Runtime Status / 运行状态

**中文**
- QEMU 可到达 shell 提示符并执行 `sysenv`/`fsck_mfs` 等命令，但仍会出现用户态崩溃。
- `minix-service -c up /service/virtio_blk_mmio -dev /dev/c0d0` 触发 SIGSEGV（`pc=0x3bb38`, `sp=0xefbffff0`），导致 virtio smoke 失败。
- SMP 初始化仍标记为跳过（not yet implemented）。

**English**
- QEMU reaches a shell prompt and can run `sysenv`/`fsck_mfs`, but userland crashes still occur.
- `minix-service -c up /service/virtio_blk_mmio -dev /dev/c0d0` triggers SIGSEGV (`pc=0x3bb38`, `sp=0xefbffff0`), causing virtio smoke failure.
- SMP initialization remains skipped (not yet implemented).

## Key Issues (Snapshot) / 关键问题（摘要）

**Critical / 严重**
- None confirmed in current workspace; PTROOT 64-bit fix is in-tree but not revalidated.

**Major / 重要**
- UART deferred replies, TLB flush after leaf splits, and SBI legacy PA fixes are in-tree but need runtime validation.
- `ld.elf_so` still missing when `MKPIC=no`, so dynamic binaries remain untested.
- SMP core (`smp.c` + arch hooks) is still unimplemented.

详见 `issue.md` 的证据与修复建议 / See `issue.md` for evidence and fixes.

## Evidence Sources / 证据来源

- `issue.md` (code review evidence with file/line references)
- `docs/RISCV64_KERNEL_BUILD_LOG.md` (build history and commands)
- `README-RISCV64.md` (boot/test notes and baseline procedures)

## Next Priorities / 下一阶段优先级

**中文**
1) 验证 UART/TLB/SBI 修复在 QEMU 下的运行时行为。
2) 恢复动态加载器（MKPIC/MKPICLIB）并验证最小动态程序。
3) 调试 `minix-service` 启动 virtio_blk_mmio 的崩溃并恢复 virtio I/O 测试。
4) 补齐 SMP 核心与 IPI 路径实现。

**English**
1) Validate UART/TLB/SBI fixes in QEMU.
2) Restore dynamic loader (MKPIC/MKPICLIB) and test a minimal dynamic binary.
3) Debug `minix-service` crash when starting virtio_blk_mmio and restore virtio I/O testing.
4) Implement SMP core and IPI paths.

## Success Criteria / 下一里程碑判定

**中文**
- QEMU 中稳定进入用户态（无 `System reset...` 循环）。
- 时钟中断驱动调度与时间推进。
- UART 阻塞读可正常返回。
- sys_vmctl PTROOT 在 >4GB 物理地址下可靠切换 SATP。

**English**
- Stable boot to userland in QEMU without reset loops.
- Timer IRQ drives scheduling/timekeeping.
- UART blocking reads return correctly.
- sys_vmctl PTROOT switches SATP reliably above 4GB physical roots.
