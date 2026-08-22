# MINIX RISC-V 64-bit Port Status / MINIX RISC-V 64 位移植状态

**Date / 日期**: 2026-08-22  
**Version / 版本**: 1.47
**Status / 状态**: Phase 2 stabilization — boots to shell; P0 closed and key P1 hygiene fixes landed
**Progress / 进度**: ~80% (boot/userland path stabilized; runtime-aware gate hardened; core follow-ups remain)

## Summary / 摘要

**中文**
- 构建可通过（GCC + workaround 组合），详见 `README-RISCV64.md`。
- QEMU 可稳定进入 shell，并已通过交互冒烟：`echo SMOKE_OK`、`ps -aux`、`cat /proc/meminfo`。
- 系统大版本已滚动到 `Minix Cat 4.0.0`（`OS_RELEASE=4.0.0`，
  `MINIX_VERSION=4.0.0-riscv64`）。
- ramdisk 现在内置 `neofetch`（`pfetch` 为兼容包装），默认通过 `/proc/service`
  统计服务信息，避免默认走 `ps` 路径导致的噪声。
- P0 复验：基于 GCC 重建内核的 QEMU 冒烟中，`ps -aux`、`cat /proc/meminfo`、
  `minix-service sysctl srv_status` 均返回 `RC=0`，未见 `SIGSEGV`/kernel panic。
- 已验证 `obj.intrgcc` 独立链路可完成 `tools -> distribution -> QEMU`，并消除此前
  `Boot module not found: ds` 的启动报错。
- 本轮已确认并修复 RV64 用户态 `memset` 递归导致的栈顶 SIGSEGV（见 `issue.md` A3 进展）。
- 含盘 smoke 复测通过：`virtio_blk_mmio` 报告 capacity/initialized，未再出现
  `device not found` / `Request 0x700 to RS failed` / `couldn't start virtio_blk_mmio`。
- `minix/releasetools/riscv64/mkdisk.sh` 已重构为非 root 可产出 U-Boot 自动探测镜像
  （含 `boot.scr.uimg` + `/boot/kernel.bin` + 模块/`modinfo` 载荷）。
- A4 已闭环：U-Boot 纯磁盘路径在正确 S-mode 链路
  （`-bios default -kernel /usr/lib/u-boot/qemu-riscv64_smode/uboot.elf`）下
  可进入 MINIX shell（见 `issue.md` A4 归档）。
- 已完成 source-driven 复现门禁全链路：`repro_build_gate.sh` 在同一 `obj.intrgcc`
  跑通 `tools -> distribution -> smoke`（无需手工补丁/手工拷贝产物）。
- 多轮自动门禁通过：`minix/tests/riscv64/multi_smoke_gate.sh --rounds 2 --timeout 90`
  在无盘+带盘共 4 轮全部通过，`safecopy` 首错被自动定性为 `acceptable_noise`。
- #26 已修复：RS `do_up`/`do_update` 在 `init_slot()` 后失败路径补齐 slot 清理，
  并修正 regular-update `create_service` 失败时的 `r_new_rp/r_old_rp` 链接回滚。
- 门禁脚本已加固为“每轮独立可复现”：`multi_smoke_gate.sh` 默认按轮创建
  `...roundN.img`，仅在显式 `--reuse-disk` 时复用单镜像。
- 门禁进一步收敛为“启动 + 运行时”双阶段：
  `multi_smoke_gate.sh` 默认执行 `qemu_runtime_probe.py`，每轮要求
  `cat /proc/meminfo`、`ps -aux`、`minix-service sysctl srv_status` 成功；
  带盘轮次额外校验 `/dev/c0d0` 存在。
- `repro_build_gate.sh` 的 relax 行为探针改为
  `ld -r --whole-archive ... --no-whole-archive`，避免空对象误通过。
- #24 已缓解：in-tree binutils 增加 `R_RISCV_RELAX` 兼容补丁，`ld` 不再因 `0x33` 中断链接。
- 本轮已修复 RV64 FDT 启动指针命名空间错配（`__k_unpaged__boot_fdt` 与 `_boot_fdt`）；
  内存探测恢复到完整 256MB，日志显示 `Memory: 0x80000000 - 0x90000000`，
  `neofetch` 的 `Mem(raw)` 总页数提升到 `61767`。
- 已完成一次完整 `riscv64` 套件回归：`run_tests.sh all` 结果为
  `Passed=21, Failed=0, Skipped=1`，其中 `multi_smoke_gate` 为
  `4/4` 通过，runtime probe `4/4` 通过。
- 本轮网络权限链路修复：`service lwip` IPC 白名单补充 `pm` 后，
  raw socket 鉴权恢复，`ping/ping6` 不再因 `Permission denied` 失败
  （详见 `issue.md` `#34`）。
- 本轮网络子系统修复（`issue.md` `#39`）：`virtio_net_mmio.conf` 已与 RISC-V
  `system.conf` 对齐（`PRIVCTL`、IRQ 1-8、完整 MMIO 窗口），磁盘轮廓也能映射
  网卡；QEMU `-n` 支持 `NET_HOSTFWD=none`，并新增 `qemu_net_smoke.py`。
- 本轮按 FreeBSD `if_vtnet` 对齐用户态 virtio-net datapath（`issue.md` `#40`）：
  VirtIO 1.0 使用 12 字节 `virtio_net_hdr`，独立 RX/TX 缓冲，协商 CSUM/
  GUEST_CSUM/CTRL_RX，并处理 config ISR 链路变化。
- 本轮修复 GitHub-hosted packaging CI（`issue.md` `#41`）：`tools` 前丢掉
  带 `/home/donz/minix` 路径的 `obj.intrgcc/tooldir.*` 与 `tools`；并行
  binutils 前先生成 `bfd.h`；gcc 4.8.5 dist 上跳过 gcc13 才有的 libstdc++
  头文件名；full-suite 仅在 tools/distribution 成功后运行；net smoke 不再
  把 OpenSBI ASCII art 的 `\ ` 当成 shell prompt。
- 本轮继续修 hosted packaging CI 的 distribution 失败（`issue.md` `#43` / `#44` / `#48`）：
  gcc 4.8.5 dist 上跳过 gcc13 才有的 `params.opt`。`#44` 曾把 RISC-V
  long double 标成 128 位以补 `_copysignl`；gcc 4.8.5 实际是 64 位
  （`__LDBL_MANT_DIG__==53`），nightly `32483868137` 在 `s_cbrtl.c`
  失败。`#48` 去掉该标记，在 `s_copysign.S` / `s_fabs.S` / `s_fma.S`
  上 alias `*l`。
- `417e7bd94` 的 hosted tools 在 top-level configure 之后因
  `bfd Makefile missing after configure` 立刻失败（`issue.md` `#45`）。
  去掉过早的 nbmake `bfd.h` 依赖，改由宿主 GNU make 先 `configure-bfd`
  再编 `all-binutils`。
- 本轮继续按 FreeBSD `if_vtnet` 加深 virtio-net datapath（`issue.md` `#46`）：
  协商 MRG_RXBUF 与 EVENT_IDX，单缓冲 RX（头在缓冲区开头），环深 128，
  并 ACK GUEST_ANNOUNCE。
- 本轮继续按 FreeBSD `if_vtnet` 加深 virtio-net（`issue.md` `#49`）：
  RX/TX 环深 256，协商 `CTRL_MAC` / `CTRL_RX_EXTRA`，`ndr_set_hwaddr`
  走 `CTRL_MAC_ADDR_SET`，并设置 `CTRL_RX_NOBCAST`。net smoke 要求
  `rx 256`。
- 本轮修 virtio-net EVENT_IDX 灌环空洞（`issue.md` `#73`）：
  `#46` 在 `to_queue` 里按 `vring_need_event` 抑制 kick，256 槽 RX
  refill 只通知第一槽，QEMU slirp 的 `ping 10.0.2.2` 100% 丢包。
  RX 灌环、TX 发包、CTRL 命令之后补一次无条件 `QUEUE_NOTIFY`。
- 本轮修 virtio-net EVENT_IDX used 环通知（`issue.md` `#74`）：
  `#73` kick 之后 hosted nightly 的 `ping 10.0.2.2` 仍 100% 丢包。
  virtio-blk 在 `from_queue` 上 busy-wait，网卡却只在 IRQ 上收包；
  每次 consume 都写 `used_event` 会在错过第一次 used 通知后让 QEMU
  永久抑制后续中断。TX kick 之后与 10 Hz tick 排空 used 环，drain
  之后按 Linux `virtqueue_enable_cb` 发布 `used_event`，MMIO IRQ
  使用 `IRQ_REENABLE`，MAC 改为按字节读取。
- 本轮新增本地/CI virtio EVENT_IDX 宿主测试与 net smoke MAC/pcap 探测
  （`issue.md` `#75`）：`run_tests.sh build` 编译并运行
  `test_virtio_event_idx.c` 覆盖 `#73`/`#74` 的 `vring_need_event` 用例；
  `qemu_net_smoke.py` 要求 `virtio-net-mmio: mac 52:54:00:12:34:56`，
  可选 `NET_PCAP` 解析 ARP/echo 并在 `ping_gw` 失败时提示 TX vs RX。
  本地 QEMU 8.2.2 对重建 ramdisk 已跑：init/MAC/mrg/event_idx/rx256/
  ifconfig/ping6 通过；`#75` 时 pcap 只有 guest ARP who-has。`#76` 修好
  slirp IPv4 之后 `ping_gw` 通过。
- 本轮修 QEMU user-net IPv4（`issue.md` `#76`）：QEMU 8.2 只写 `ipv6=on`
  会把 `ipv4` 清掉，slirp 不答 ARP。`-netdev` 改为 `ipv4=on,ipv6=on`。
  本地 QEMU 8.2.2 net smoke `ping_gw` 通过（`echo_req=2 echo_rep=2`）。
- 本轮继续修 native gcc 在 gcc 4.8.5 dist 上的缺口（`issue.md` `#47` / `#50` / `#52` / `#53` / `#55` / `#56` / `#57` / `#58` / `#59` / `#60` / `#61` / `#62` / `#63` / `#64` / `#65` / `#67` / `#68` / `#69` / `#70` / `#71` / `#72`）：
  gcov 跳过 `json.cc`；common-target 跳过 gcc13 才有的源或把 `.cc` 映射到 `.c`。
  `#50`：backend 生成器按 dist 选择 `.cc`/`.c`。`#52`：丢掉 4.8.5
  没有的 `gcc/common.md`，只把存在的 `.md` 传给生成器。`#53`：tools gcc
  4.8.5 不生成 `version.h` 时改为合成头文件。`#54`：4.8.5 `genmodes` 没有
  `-i`，改为空的 `insn-modes-inline.h`；frontend/cc1 的 `.cc` 映射到 `.c`。
  `#55`：`G_GCC_H` 在 tools 没有 `version.h` 时改依赖本地合成文件。
  `#56`：`Makefile.hooks` 把 gcc13 的 `genhooks.cc` 映射到 4.8.5 的
  `genhooks.c`。`#57`：4.8.5 的 gengtype 仍链 `version.c`，并且有
  `gengtype-state.c`；GTY 产出是 `gtype-desc.c` 而不是 gcc13 的 `.cc`。
  `#58`：riscv64 `gtyp-input.list` 是 gcc13 的 `.cc` 清单，4.8.5 上会
  丢掉实现源；改为用 `defs.mk` 的 `G_GTFILES` 生成输入，gcc13 路径把
  `.cc` 映射到 `.c`。`#59`：`#58` 的 `.for` 被 `{ \` 续行交给 shell，
  改为每条 `G_GTFILES` 单独 recipe。`#60`：独立 recipe 里的
  `printf '%s\n'` 被 make 拆成真换行，改为 `echo`。`#61`：gcc13
  路径无条件丢掉 `cpp-id-data.h`，4.8.5 上改为文件存在就保留。`#62`：
  `GENERATOR_FILE` 下把 `config.h` 转到 arch `bconfig.h`，避免
  `hash-table.c` 踩 host/build 护栏。`#63`：`#62` 编过 `hash-table.lo`
  后，libcpp 仍按 gcc13 要 `charset.cc`；4.8.5 只有 `libcpp/*.c`，按
  dist 把 `G_libcpp_a_OBJS` 映射到 `.c`。`#64`：`#63` 编出 `libcpp.a`
  后，4.8.5 `gcov-io.h` 仍要 `gcov-iov.h`；usr.bin 补上 libgcov arch 的
  `-I`，与 backend 一致。`#65`：`#64` 的 `${.PARSEDIR}` 展开为空，编译
  行变成 `-I/../lib/...`；改为从 `NETBSDSRCDIR` 解析绝对路径。`#67`：
  `#65` 编过 gcov.c 后，libcommon.a 只有 `input.o`；按 common-target
  把 diagnostic/pretty-print/intl/input/version 映射到 4.8.5 的 `.c`。
  `#68`：`#67` 编过 gcov 后，原生 cpp 把 gcpp 链成三份 `ggc-none.o`；
  `Makefile.cc2c` 的 `+= ${_gcc_cc2c}` 被 bmake 延迟展开，改为直接
  追加 `${s}` / `${s:R}.c`。
  `#69`：`#68` 链上 `cppspec.o gcc.o ggc-none.o` 后，缺 4.8.5
  `params.c` 的 `global_init_params`；common-target 补回该源。静态
  链接把 `-lintl` 放在 libcpp.a 之前，frontend 在档案后再链一次。
  `#70`：`#69` 链上 `gcpp`（`-lintl` 在 `libdecnumber.a` 之后）后，
  nightly `32532469511` 在 `lto1` 报 `don't know how to make lto1.1`。
  `#54` 把 `Makefile.cc2c` 放在程序 Makefile 顶部，先于 `NOMAN`
  拉入 `bsd.own.mk`，`MKMAN` 钉成 yes；在 `lto1` / `cc1` /
  `cc1obj` / `cc1plus` 里先设 `NOMAN`。
  `#71`：`#70` 链上 `lto1` 后，nightly `32534503524` 缺
  `pointer_set_*` / `lto_symtab_*` / `dump_insn_slim` / `insn_data`。
  `:Mininsn-*` 实际匹配 `ininsn-*`，生成的 `insn-*.o` 未进档案；
  改为 `:Minsn-*`，并补回 gcc13 `G_OBJS` 丢掉的 4.8.5 对象。
  MINIX 上 `config.h` 关掉 `HAVE_MADVISE`。
  `#72`：`#71` 链上 `lto1` 后，nightly `32537278919` 链 `cc1`
  缺 `mudflap_init()` / `_cpp_preprocess_dir_only`。gcc13
  `G_C_OBJS` 丢掉 `tree-mudflap.o`，`G_libcpp_a_OBJS` 丢掉
  `directives-only.o`；在 `Makefile.inc` 按 dist 补回，并恢复
  `cc1plus` 的 `cp/repo.o`。
- Native toolchain 进入 Stage N1/N2 推进：已新增构建入口
  `minix/tests/riscv64/native_toolchain_build.sh` 与自动验收脚本
  `minix/tests/riscv64/native_toolchain_gate.sh`，用于来宾内验证
  `as/ld/ar/ranlib` 与本地 `hello.c` 编译运行闭环。
- 仍有待闭环风险：`procfs` safecopy 回退噪声（#17）。
- Nightly 与 Release 两条 OS 打包 CI 现已在每次提交时运行，作为完整性与可复现性
  门禁；GitHub Release / nightly tag 发布仍仅限官方触发（tag、`workflow_dispatch`、
  nightly 的 schedule / `master` push）。Runner 为 GitHub-hosted `ubuntu-24.04`。

**English**
- Build passes with GCC + workaround flags; see `README-RISCV64.md` for exact commands.
- QEMU now reaches a stable shell and passes interactive smoke commands:
  `echo SMOKE_OK`, `ps -aux`, and `cat /proc/meminfo`.
- The system major version is now `Minix Cat 4.0.0`
  (`OS_RELEASE=4.0.0`, `MINIX_VERSION=4.0.0-riscv64`).
- Ramdisk now ships `neofetch` (`pfetch` kept as compatibility wrapper);
  default service summary uses `/proc/service` to avoid noisy default `ps` probing.
- P0 revalidation: with a GCC-rebuilt kernel, QEMU smoke confirms
  `ps -aux`, `cat /proc/meminfo`, and `minix-service sysctl srv_status`
  all return `RC=0` without `SIGSEGV` or kernel panic signatures.
- The isolated `obj.intrgcc` path now completes `tools -> distribution -> QEMU`, and
  the previous `Boot module not found: ds` startup failure is no longer reproduced.
- This cycle confirms and mitigates the RV64 userland `memset` recursion SIGSEGV signature
  (see `issue.md` A3 update).
- With-disk smoke now passes: `virtio_blk_mmio` reports capacity/initialized and no longer logs
  `device not found`, `Request 0x700 to RS failed`, or `couldn't start virtio_blk_mmio`.
- `minix/releasetools/riscv64/mkdisk.sh` has been reworked to create a non-root
  U-Boot autodiscovery image (`boot.scr.uimg` + `/boot/kernel.bin` +
  module/modinfo payloads).
- A4 is now closed: the disk-only U-Boot path reaches MINIX shell when using the
  correct S-mode chain
  (`-bios default -kernel /usr/lib/u-boot/qemu-riscv64_smode/uboot.elf`);
  see archived A4 notes in `issue.md`.
- A source-driven reproducibility gate now passes end-to-end:
  `repro_build_gate.sh` completes `tools -> distribution -> smoke`
  on the same `obj.intrgcc` without manual patching/artifact injection.
- Multi-run automated gate now passes: `minix/tests/riscv64/multi_smoke_gate.sh --rounds 2 --timeout 90`
  completes 4/4 passes across diskless + with-disk runs, and safecopy first-error
  triage reports `acceptable_noise`.
- #26 is fixed: RS `do_up`/`do_update` now clean up allocated slots on post-`init_slot()`
  failures, and regular-update linkage is rolled back on `create_service` failure.
- Gate behavior is now per-round reproducible by default:
  `multi_smoke_gate.sh` creates `...roundN.img` images unless `--reuse-disk` is set.
- Gate now enforces a two-stage signal by default (boot + runtime probe):
  `multi_smoke_gate.sh` runs `qemu_runtime_probe.py` each round and requires
  successful `meminfo/ps/srv_status` commands, plus `/dev/c0d0` existence in with-disk rounds.
- `repro_build_gate.sh` relax probe now uses
  `ld -r --whole-archive ... --no-whole-archive` to exercise real archive-member paths.
- #24 is now mitigated: in-tree binutils has a compatibility patch for `R_RISCV_RELAX`,
  and `ld` no longer aborts on relocation `0x33`.
- This cycle fixes RV64 FDT boot-pointer namespace mismatch
  (`__k_unpaged__boot_fdt` vs `_boot_fdt`); memory detection returns to the
  full 256MB range (`Memory: 0x80000000 - 0x90000000`), and `neofetch`
  `Mem(raw)` total pages rise to `61767`.
- A full `riscv64` regression has been completed:
  `run_tests.sh all` reports `Passed=21, Failed=0, Skipped=1`,
  with `multi_smoke_gate` `4/4` pass and runtime probe `4/4` pass.
- This cycle fixes raw-socket credential lookup permissioning for networking:
  `service lwip` now allows IPC to `pm`, removing false `ping/ping6`
  `Permission denied` failures (`issue.md` `#34`).
- This cycle repairs NIC bring-up on disk profiles (`issue.md` `#39`):
  `virtio_net_mmio.conf` now matches RISC-V `system.conf` (`PRIVCTL`, IRQs
  1-8, full MMIO window). QEMU `-n` honors `NET_HOSTFWD=none`, and
  `qemu_net_smoke.py` covers `vio0` / `ping`.
- This cycle aligns the userspace virtio-net datapath with FreeBSD
  `if_vtnet` (`issue.md` `#40`): VirtIO 1.0 12-byte headers, dedicated
  RX/TX rings, CSUM/GUEST_CSUM/CTRL_RX, and config-change link status.
- This cycle unblocks GitHub-hosted packaging CI (`issue.md` `#41`): wipe
  tracked host `obj.intrgcc/tooldir.*` and `tools` before `build.sh tools`,
  generate `bfd.h` before parallel RISC-V binutils, skip gcc13-only
  libstdc++ headers on the gcc 4.8.5 dist, run the full suite only after
  a successful tools/distribution path, and stop treating OpenSBI's `\ `
  banner as a MINIX shell prompt.
- Hosted packaging CI after tools (`issue.md` `#43` / `#44` / `#48`): skip
  gcc13-only `params.opt` on the gcc 4.8.5 dist. `#44` set
  `__HAVE_LONG_DOUBLE 128` to export `_copysignl`; gcc 4.8.5 long double
  is 64-bit (`__LDBL_MANT_DIG__==53`), and nightly `32483868137` failed
  in `s_cbrtl.c`. `#48` drops that flag and aliases `*l` from the RISC-V
  `.S` files that replace the C sources.
- Hosted tools `417e7bd94` aborted after top-level configure looking for
  `build/bfd/Makefile` (`issue.md` `#45`). Tools binutils now runs GNU
  `configure-bfd` then `all-binutils` and does not depend on `bfd.h` at
  that point.
- This cycle deepens the userspace virtio-net datapath toward FreeBSD
  `if_vtnet` (`issue.md` `#46`): MRG_RXBUF, EVENT_IDX, 128-deep rings,
  header-at-start RX buffers, and GUEST_ANNOUNCE ACK.
- Follow-up (`issue.md` `#49`): 256-slot RX/TX rings, `CTRL_MAC` /
  `CTRL_RX_EXTRA`, `ndr_set_hwaddr` via `CTRL_MAC_ADDR_SET`, and
  `CTRL_RX_NOBCAST`. Net smoke requires `rx 256`.
- Follow-up (`issue.md` `#73`): `#46` EVENT_IDX in `to_queue` only
  kicks the first buffer of a burst (`avail_event` starts at 0), so a
  256-slot RX refill left QEMU looking at one buffer and
  `ping 10.0.2.2` lost every packet. Kick RX after refill, TX after
  send, and CTRL after `to_queue`.
- Follow-up (`issue.md` `#74`): `#73` kicks were not enough. Hosted
  nightly `32546187525` still lost every slirp ping. virtio-blk
  busy-waits on `from_queue`; virtio-net only drained RX from the
  VRING IRQ, and `from_queue` wrote `used_event` on every consume, so
  a missed first used-notify suppressed later interrupts. Drain RX
  after TX and on a 10 Hz tick, publish `used_event` with Linux
  `virtqueue_enable_cb`, `IRQ_REENABLE` the MMIO line, and read the
  MAC a byte at a time.
- Follow-up (`issue.md` `#75`): hosted nightly still needs 30+ minutes to
  rediscover EVENT_IDX avail/used notify bugs. `run_tests.sh build` now
  compiles and runs host `test_virtio_event_idx.c` for `#73`/`#74`
  `vring_need_event` cases; `qemu_net_smoke.py` requires QEMU MAC
  `52:54:00:12:34:56` and optional `NET_PCAP` dumps classify `ping_gw`
  failures as TX vs RX. Local QEMU 8.2.2 against a rebuilt ramdisk
  passed init/MAC/mrg/event_idx/rx256/ifconfig/ping6; `#75` pcap had
  guest ARP who-has only. `#76` restored slirp IPv4 and `ping_gw`
  passed.
- Follow-up (`issue.md` `#76`): QEMU 8.2 `net_init_slirp()` clears IPv4
  when `ipv6=on` is set without `ipv4=on`, so slirp ignores ARP.
  `qemu-riscv64.sh` now passes `ipv4=on,ipv6=on`. Local QEMU 8.2.2 net
  smoke passed `ping -c 2 10.0.2.2` (`echo_req=2 echo_rep=2`).
- Native gcc on the gcc 4.8.5 dist (`issue.md` `#47` / `#50` / `#52` / `#53` / `#55` / `#56` / `#57` / `#58` / `#59` / `#60` / `#61` / `#62` / `#63` / `#64` / `#65` / `#67` / `#68` / `#69` / `#70` / `#71` / `#72`): gcov skips
  `json.cc`; common-target skips gcc13-only sources or maps `.cc` to `.c`.
  `#50`: backend generators resolve `.cc`/`.c` from dist.
  `#52`: drop gcc13 `gcc/common.md` when the 4.8.5 dist lacks it.
  `#53`: synthesize `version.h` when tools gcc 4.8.5 does not emit it.
  `#54`: stub `insn-modes-inline.h` because 4.8.5 `genmodes` has no `-i`,
  and map remaining frontend/cc1 `.cc` sources to `.c`.
  `#55`: if tools gcc has no `version.h`, `G_GCC_H` depends on the local stub.
  `#56`: `Makefile.hooks` maps gcc13 `genhooks.cc` to gcc 4.8.5 `genhooks.c`.
  `#57`: 4.8.5 `gengtype` still links `version.c` and has `gengtype-state.c`;
  GTY output is `gtype-desc.c`, not gcc13 `.cc`.
  `#58`: riscv64 `gtyp-input.list` is gcc13 `.cc` names, which 4.8.5
  drops; build the input from `defs.mk` `G_GTFILES` and map `.cc` to `.c`
  on the gcc13 path.
  `#59`: `#58` put `.for` inside a `{ \' continuation so the shell saw
  it; emit one recipe line per `G_GTFILES` word.
  `#60`: a standalone recipe `printf '%s\n'` is split by make; echo
  each `G_GTFILES` word instead.
  `#61`: keep `cpp-id-data.h` on gcc 4.8.5; only drop it when the
  file is absent.
  `#62`: wrap `config.h` so `-DGENERATOR_FILE` includes arch
  `bconfig.h` (gcc 4.8.5 `hash-table.c` includes `config.h`
  unconditionally).
  `#63`: after `#62` compiled `hash-table.lo`, native libcpp still
  asked for gcc13 `charset.cc`; map `G_libcpp_a_OBJS` onto
  `libcpp/*.c` on gcc 4.8.5.
  `#64`: after `#63` built `libcpp.a`, 4.8.5 `gcov-io.h` still
  includes `gcov-iov.h`; add the libgcov arch `-I` in usr.bin so
  gcov and cc1 see the mknative header.
  `#65`: `#64` `${.PARSEDIR}` expanded empty (`-I/../lib/...`);
  resolve the include from `NETBSDSRCDIR` instead.
  `#67`: after `#65` compiled gcov.c, `libcommon.a` contained only
  `input.o`; map diagnostic/pretty-print/intl/input/version like
  common-target and restore gcc 4.8.5 `version.c`.
  `#68`: after `#67` compiled gcov, native cpp linked gcpp as
  `ggc-none.o` three times (`32527820716` / `c952fa0c1`).
  `Makefile.cc2c` `+= ${_gcc_cc2c}` is delayed by bmake; add
  `${s}` / `${s:R}.c` directly.
  `#69`: after `#68` linked `cppspec.o gcc.o ggc-none.o`, gcpp
  missed gcc 4.8.5 `params.c` (`global_init_params`) and libcpp
  `dgettext` (`32530101083` / `92237adf3`). Map `params.cc` onto
  `params.c` in common-target, and repeat `-lintl` after frontend
  archives.
  `#70`: after `#69` linked `gcpp` with `-lintl` after
  `libdecnumber.a`, nightly `32532469511` (`9cb398c22`) died
  `don't know how to make lto1.1`. `#54` put `Makefile.cc2c` at
  the top of `lto1` / `cc1` / `cc1obj` / `cc1plus`, so
  `bsd.own.mk` ran before `NOMAN` and `MKMAN` stayed yes. Set
  `NOMAN` first, matching `lto-wrapper`.
  `#71`: after `#70` linked `lto1`, nightly `32534503524`
  (`88ec45927`) missed `pointer_set_*`, `lto_symtab_*`,
  `dump_insn_slim`, and `insn_data` / `gen_*`. `:Mininsn-*`
  matches `ininsn-*`, so generated `insn-*.o` never entered
  `libbackend.a`. Use `:Minsn-*` and add 4.8.5-only objects
  gcc13 `G_OBJS` dropped. Undef `HAVE_MADVISE` in native
  `config.h`.
  `#72`: after `#71` linked `lto1`, nightly `32537278919`
  (`6954a7e6c`) linked `cc1` then missed `mudflap_init()` and
  `_cpp_preprocess_dir_only`. gcc13 dropped `tree-mudflap.o`
  from `G_C_OBJS` and `directives-only.o` from
  `G_libcpp_a_OBJS`. Restore them (and `cp/repo.o` for
  `cc1plus`) in `usr.bin/Makefile.inc` when dist source exists.
- Native toolchain work has entered Stage N1/N2 with both a build helper
  (`minix/tests/riscv64/native_toolchain_build.sh`) and an automated in-guest
  gate (`minix/tests/riscv64/native_toolchain_gate.sh`) to validate
  `as/ld/ar/ranlib` and native `hello.c` compile-and-run closure.
- Remaining open risk: procfs safecopy retry noise (#17).
- Nightly and Release OS packaging CIs now run on every commit as
  completeness/reproducibility gates; GitHub Release / nightly tag publish
  remains gated to official triggers (tag, `workflow_dispatch`, nightly
  schedule / `master` push). Runners are GitHub-hosted `ubuntu-24.04`.

## Build Status / 构建状态

**中文**
- 基线命令：使用 GCC、禁用 LLVM/C++、放宽 `checkflist`（见 `README-RISCV64.md`）。
- 产物：`minix/kernel/obj/kernel` 与 `obj/destdir.evbriscv64`。
- 已补充 `obj.intrgcc` 自举输出：`obj.intrgcc/minix/kernel/kernel` 与
  `obj.intrgcc/destdir.evbriscv64` 可直接用于 QEMU。
- 限制：`CHECKFLIST_FLAGS='-m -e'` 为临时绕过，需在 sets 完整后移除。
- ramdisk 更新：新增 `/bin/neofetch`（`pfetch` 兼容包装）与 `/etc/build-id` 注入。
- 工具链进展：in-tree `ld`（NetBSD binutils 2.23.2）已通过补丁兼容
  `R_RISCV_RELAX`（见 `issue.md` #24）。
- 更新：#25 已在当前工作树修复；riscv64 默认编译参数已收敛为
  `-march=RV64IMAFD -mcmodel=medany`，避免默认 `-mabi=lp64d` 兼容性分歧。

**English**
- Baseline: GCC, LLVM/C++ disabled, relaxed `checkflist` (see `README-RISCV64.md`).
- Outputs: `minix/kernel/obj/kernel` and `obj/destdir.evbriscv64`.
- Added validated self-bootstrap outputs: `obj.intrgcc/minix/kernel/kernel` and
  `obj.intrgcc/destdir.evbriscv64` are bootable in QEMU.
- Limitation: `CHECKFLIST_FLAGS='-m -e'` is a temporary workaround until sets are complete.
- Ramdisk update: adds `/bin/neofetch` (with `pfetch` compatibility wrapper)
  and injects `/etc/build-id`.
- Toolchain update: in-tree `ld` (NetBSD binutils 2.23.2) now accepts `R_RISCV_RELAX`
  via a compatibility patch; see `issue.md` #24.
- Update: #25 is fixed in the current working tree; riscv64 default compile flags
  now use `-march=RV64IMAFD -mcmodel=medany` to avoid default `-mabi=lp64d`
  compatibility drift.

## Runtime Status / 运行状态

**中文**
- 启动链路已稳定可进入 `#` 提示符，`init` 与核心服务可完成基本握手。
- 交互复测通过：`ps -aux` 返回进程列表；`cat /proc/meminfo` 可返回内存信息。
- 使用 `./minix/scripts/qemu-riscv64.sh -k obj.intrgcc/minix/kernel/kernel -B obj.intrgcc/destdir.evbriscv64`
  可直接进入 shell，验证 `obj.intrgcc` 轮廓启动可用。
- `/proc/meminfo` 路径仍可见一次可恢复 safecopy 回退（先失败后重试成功），属于已知噪声问题（#17）。
- 新一轮 `qemu-p0-smoke`（`/tmp/qemu-p0-smoke.log`）同样显示 procfs/safecopy 可恢复回退噪声，
  但命令返回保持成功（`RC=0`）。
- 含盘 smoke（`/tmp/qemu-smoke-disk.log`）已验证 `virtio_blk_mmio` 初始化成功；
  `-i` 轮廓下未复现 `device not found` / `Request 0x700 ... not alive` 告警。
- U-Boot 纯磁盘路径已可自动发现并执行 `/boot.scr.uimg`，并在
  `-bios default -kernel /usr/lib/u-boot/qemu-riscv64_smode/uboot.elf`
  链路下进入 shell（`/tmp/qemu-uboot-diskonly-new-smode.log`）。
- 多轮日志门禁输出位于 `/tmp/minix-smoke-gate-20260216-221610/` 与
  `/tmp/minix-smoke-gate-20260216-224157/`，含每轮 `.log` 与 `.triage.txt`，
  可用于回归比较与首错审计。
- 每轮独立镜像复验通过：`multi_smoke_gate.sh --rounds 2 --timeout 60`
  在 `/tmp/minix-smoke-gate-indep-20260216-234830/` 生成
  `...round1.img` 与 `...round2.img`，并完成 4/4 通过。
- `repro_build_gate.sh --objdir obj.intrgcc --smoke-rounds 1 --smoke-timeout 60 --without-disk`
  全链路通过，产出日志 `/tmp/minix-smoke-gate-20260216-223948/`（diskless 1/1 通过）。
- `repro_build_gate.sh --objdir obj.intrgcc --skip-tools --skip-distribution
  --smoke-rounds 1 --smoke-timeout 45 --without-disk` 复验通过，
  日志位于 `/tmp/minix-smoke-gate-20260217-000150/`。
- 严格门禁复测：
  `multi_smoke_gate.sh --rounds 1 --timeout 70 --runtime-timeout 70 --runtime-cmd-timeout 35`
  在 `/tmp/minix-smoke-gate-20260217-070246/` 完成
  `Passed: 2, Failed: 0, Runtime passed: 2, Runtime failed: 0`。
- 最新全量回归（`/tmp/minix-full-riscv64-tests.log`）通过：
  `Passed: 21, Failed: 0, Skipped: 1`；
  其中门禁日志在 `/tmp/minix-smoke-gate-20260217-165805/`，结果为
  `Passed: 4, Failed: 0, Runtime passed: 4, Runtime failed: 0`。
- FDT 启动指针桥接修复后，启动日志恢复完整内存窗口
  `Memory: 0x80000000 - 0x90000000`，`neofetch` 显示
  `Mem(raw): 4096 61767 52676 48338 1185`
  （见 `/tmp/qemu-memfix.log` 与 `/tmp/qemu-neofetch-memfix.log`）。
- `neofetch` 默认服务探测模式已从 `off` 切换为 `auto`，优先读取 `/proc/service`；
  `NEOFETCH_SERVICE_PROBE=ps` 仍可显式启用旧 `ps` 探测路径。
- 2026-02-20：修复 VM `alloc_pages()` 在 RV64 上的 `NO_MEM` 哨兵宽度/符号扩展问题
  （`minix/servers/vm/alloc.c`），消除 `native_as_stdin` 与 `cc -c` 路径的 VM panic 触发点。
  在 fresh native 镜像
  （`.ci-artifact-test/minix-native-gcc-test-fixed.img`）上，
  `native_toolchain_gate.sh` 全链路通过（含 `native_as_stdin`、`native_hello_build`）。
  同时 release/nightly 流水中的 native gate 已升级为阻断式（blocking）。
- `#75` 增加宿主可执行 `test_virtio_event_idx.c` 与 net smoke pcap。
- `#76` 发现 QEMU 8.2 只写 `ipv6=on` 会关掉 IPv4；改为 `ipv4=on,ipv6=on`
  后本地 `ping 10.0.2.2` 通过。

**English**
- Boot path is stable to the `#` shell prompt; init and core services complete basic startup handshake.
- Interactive retest passes: `ps -aux` returns process list; `cat /proc/meminfo` returns data.
- `./minix/scripts/qemu-riscv64.sh -k obj.intrgcc/minix/kernel/kernel -B obj.intrgcc/destdir.evbriscv64`
  now boots directly to shell, validating the `obj.intrgcc` runtime profile.
- `/proc/meminfo` still shows one recoverable safecopy fallback (fail-then-retry-success),
  tracked as known noise in #17.
- The latest `qemu-p0-smoke` run (`/tmp/qemu-p0-smoke.log`) shows the same recoverable
  procfs/safecopy fallback noise while command return codes remain successful (`RC=0`).
- The with-disk smoke run (`/tmp/qemu-smoke-disk.log`) confirms `virtio_blk_mmio`
  initialization and does not reproduce the previous startup warning signature.
- U-Boot disk-only boot now auto-discovers and executes `/boot.scr.uimg`, and
  reaches shell when launched via the S-mode chain
  (`-bios default -kernel /usr/lib/u-boot/qemu-riscv64_smode/uboot.elf`);
  see `/tmp/qemu-uboot-diskonly-new-smode.log`.
- Multi-run gate artifacts are under `/tmp/minix-smoke-gate-20260216-221610/` and
  `/tmp/minix-smoke-gate-20260216-224157/` with per-round `.log` and `.triage.txt`
  outputs for regression auditing.
- Per-round disk-image reproducibility revalidation passes with
  `multi_smoke_gate.sh --rounds 2 --timeout 60`; logs under
  `/tmp/minix-smoke-gate-indep-20260216-234830/` show distinct
  `...round1.img` / `...round2.img` images and 4/4 pass.
- `repro_build_gate.sh --objdir obj.intrgcc --smoke-rounds 1 --smoke-timeout 60 --without-disk`
  also passed end-to-end, with artifacts under `/tmp/minix-smoke-gate-20260216-223948/`.
- `repro_build_gate.sh --objdir obj.intrgcc --skip-tools --skip-distribution
  --smoke-rounds 1 --smoke-timeout 45 --without-disk` also passed with artifacts
  under `/tmp/minix-smoke-gate-20260217-000150/`.
- Strict gate revalidation:
  `multi_smoke_gate.sh --rounds 1 --timeout 70 --runtime-timeout 70 --runtime-cmd-timeout 35`
  passed under `/tmp/minix-smoke-gate-20260217-070246/` with
  `Passed: 2, Failed: 0, Runtime passed: 2, Runtime failed: 0`.
- Latest full regression (`/tmp/minix-full-riscv64-tests.log`) passes with
  `Passed: 21, Failed: 0, Skipped: 1`;
  the embedded gate run under `/tmp/minix-smoke-gate-20260217-165805/` reports
  `Passed: 4, Failed: 0, Runtime passed: 4, Runtime failed: 0`.
- After the FDT boot-pointer bridge fix, boot logs restore the full memory span
  `Memory: 0x80000000 - 0x90000000`, and `neofetch` reports
  `Mem(raw): 4096 61767 52676 48338 1185`
  (see `/tmp/qemu-memfix.log` and `/tmp/qemu-neofetch-memfix.log`).
- `neofetch` default service probe switched from `off` to `auto`, preferring
  `/proc/service`; the old `ps` path remains available via
  `NEOFETCH_SERVICE_PROBE=ps`.
- 2026-02-20: fixed RV64 `NO_MEM` sentinel width/sign-extension mismatch in
  VM `alloc_pages()` (`minix/servers/vm/alloc.c`), removing the VM panic
  reproducer on `native_as_stdin` and `cc -c`.
  Strict revalidation passes on a fresh native image
  (`.ci-artifact-test/minix-native-gcc-test-fixed.img`) with full
  `native_toolchain_gate.sh` coverage.
  Native toolchain gate in release/nightly workflows is now blocking.
- `#75` adds a host-run `test_virtio_event_idx.c` and net-smoke pcap probes.
- `#76` keeps QEMU slirp IPv4 enabled alongside IPv6; local `ping 10.0.2.2`
  now succeeds.

## Key Issues (Snapshot) / 关键问题（摘要）

**Critical / 严重**
- None newly confirmed in current workspace.

**Major / 重要**
- #16: VFS service endpoint pre-resync path still needs stricter generation-safe validation.
- #17: recoverable safecopy fallback noise on `/proc/*` path remains.
- #23: RV64 `vm_memset` recovery plumbing is implemented and smoke-validated; targeted
  fault-injection validation is still required for full closure.

详见 `issue.md` 的证据与修复建议 / See `issue.md` for evidence and fixes.

## Evidence Sources / 证据来源

- `issue.md` (code review evidence with file/line references)
- `docs/RISCV64_KERNEL_BUILD_LOG.md` (build history and commands)
- `README-RISCV64.md` (boot/test notes and baseline procedures)

## Next Priorities / 下一阶段优先级

**中文**
1) 修复 #16：收敛 VFS 服务端点“先写后验”路径，补齐代际安全校验。
2) 继续收敛 #17（统计/限流 + 负载下验证），区分噪声与真实功能缺陷。
3) 将 native toolchain 阻断门禁持续运行在 release/nightly，并补充可写介质场景下
   的可选 `link+run` 验收（规避 root mfs inode 上限带来的假阴性）。
4) 在 clean 环境做一次从 `fetch.sh` 到 `tools/binutils` 的复验，确认 #24 补丁可重复生效。
5) 在稳定后恢复动态装载链路（`MKPIC/MKPICLIB`）并验证最小动态程序。
6) 将 `repro_build_gate.sh` 纳入例行流水（至少每日一次），验证构建链路不依赖手工注入。

**English**
1) Fix #16 by tightening VFS endpoint-generation validation on service remap paths.
2) Continue closing #17 with counters/rate-limit + stress validation.
3) Keep native toolchain gate blocking in release/nightly and add optional
   writable-filesystem `link+run` acceptance to avoid false negatives from
   root mfs inode limits.
4) Re-run from clean `fetch.sh` to `tools/binutils` and confirm #24 patch reproducibility.
5) Restore dynamic loader path (`MKPIC/MKPICLIB`) and test a minimal dynamic binary.
6) Run `repro_build_gate.sh` in routine CI (at least daily) to enforce source-driven reproducibility.

## Success Criteria / 下一里程碑判定

**中文**
- 无盘与含盘两种 QEMU 轮廓在连续回归中稳定进入 shell，且含盘场景保持 `virtio_blk_mmio` 初始化成功。
- `ps -aux`、`cat /proc/meminfo` 在连续回归中稳定通过。
- 增量重建可在不替换链接器的前提下完成（不再出现 `R_RISCV_RELAX` 链接错误）。
- `procfs` 路径 safecopy 错误噪声降到可接受水平并有计数证据。

**English**
- Diskless and with-disk QEMU profiles keep reaching shell across regressions, with
  `virtio_blk_mmio` initialization preserved in with-disk runs.
- `ps -aux` and `cat /proc/meminfo` pass consistently across regressions.
- Incremental rebuild works without ad-hoc linker substitution (`R_RISCV_RELAX` link failures gone).
- procfs safecopy noise is reduced to an acceptable level with measurable counters.
