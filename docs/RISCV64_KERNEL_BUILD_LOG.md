# RISC-V MINIX Kernel Build Log / RISC-V MINIX 内核构建日志

**Last updated / 最后更新**: 2026-08-22
**Version / 版本**: 1.55
**Purpose / 用途**: Append-only record of build commands and outcomes. / 记录构建命令与结果（追加式）。

**Baseline note / 基线说明**: active build/run baseline is `obj.intrgcc`; any
`obj/...` path in older entries is historical context only. /
当前构建与运行基线为 `obj.intrgcc`；旧条目中的 `obj/...` 路径仅用于历史记录。

## Log Entries / 日志条目

### Entry 1 — Initial Attempts (date unknown) / 初始尝试（日期未知）
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64` (MACHINE_ARCH: `riscv64`)  
**Toolchain / 工具链**: `riscv64-unknown-elf-gcc` (expected in PATH)

**Steps / 过程**:
1. Create build log / 创建本日志文件。
2. Build tools (`./build.sh -U -j2 -m evbriscv64 tools`) / 构建工具链：
   - First run timed out after 120s. / 首次运行 120s 超时。
   - Second run with `HAVE_LLVM=no MKLLVM=no` failed in `tools/compat` due to missing `nbtool_config.h`.  
     Clean rerun fixed it. / 使用 `HAVE_LLVM=no MKLLVM=no` 在 `tools/compat` 失败，清理后修复。
   - Later failed in `tools/binutils` with `fatal error: bfd.h: No such file or directory`.  
     Manual `nbmake -C tools/binutils/obj/build/bfd bfd.h` succeeded after specifying the correct tooldir
     and `-m /home/donz/minix/share/mk`. / 通过指定正确的 tooldir 与 `-m /home/donz/minix/share/mk` 生成 `bfd.h`。
   - Final rerun with `-u -j1` completed and installed tools to
     `/home/donz/minix/obj/tooldir.Linux-6.6.99-09058-g594deca50d73-x86_64`.
3. Build distribution (`./build.sh -U -u -j1 -m evbriscv64 distribution`) / 构建 distribution：
   - Failed in `lib/csu` because `riscv64-elf32-minix-clang` was missing.
   - Attempt to rebuild tools with `MKGCC=yes` failed in `tools/gmake` due to missing distfiles (network blocked).

**Result / 结果**: Tools eventually built; distribution failed due to missing clang/distfiles.  
**Outcome / 结论**: Build environment needed adjustments (no clang, no network fetch).

### Entry 2 — Workaround Build Success (2026-01-02) / 绕过项构建成功
**Workspace / 工作区**: `/root/minix`  
**Command / 命令**:
```bash
MKPCI=no HOST_CFLAGS="-O -fcommon" HAVE_GOLD=no HAVE_LLVM=no MKLLVM=no \
./build.sh -j$(nproc) -m evbriscv64 \
  -V AVAILABLE_COMPILER=gcc -V ACTIVE_CC=gcc -V ACTIVE_CPP=gcc -V ACTIVE_CXX=gcc -V ACTIVE_OBJC=gcc \
  -V RISCV_ARCH_FLAGS='-march=RV64IMAFD -mcmodel=medany' \
  -V NOGCCERROR=yes \
  -V MKPIC=no -V MKPICLIB=no -V MKPICINSTALL=no \
  -V MKCXX=no -V MKLIBSTDCXX=no -V MKATF=no \
  -V USE_PCI=no \
  -V CHECKFLIST_FLAGS='-m -e' \
  distribution
```
**Outputs / 产物**:
- Kernel: `minix/kernel/obj/kernel`
- Destdir: `obj/destdir.evbriscv64`

**Notes / 说明**:
- `CHECKFLIST_FLAGS='-m -e'` relaxes missing/extra files while sets are incomplete.
- LLVM/C++ disabled due to known RISC-V build gaps.

### Entry 3 — Doc Update Only (2026-01-04) / 仅更新文档
**Action / 动作**: Documentation updates; no new build executed. / 仅更新文档，未执行新的构建。

### Entry 4 — Doc Major Version (2026-01-06) / 文档大版本更新
**Action / 动作**: Promoted docs to version 1.0; no new build executed. / 文档升级为 1.0，未执行新的构建。

### Entry 5 — Doc Sync (2026-01-07) / 文档同步
**Action / 动作**: Documentation sync only; no new build or tests executed. / 仅文档同步，未执行新的构建或测试。  
**Scope / 范围**: `README.md`, `README-RISCV64.md`, `RISC64-STATUS.md`, `issue.md`,
`docs/RISCV64_PORTING_GUIDE.md`, `docs/RISCV64_PORT_PLAN.md`.

### Entry 6 — Doc Update After Pre-01:00 Review (2026-01-07) / 复核后文档更新
**Action / 动作**: Documentation update after reviewing pre-2026-01-06 01:00 code changes; no build/tests executed.  
仅根据 2026-01-06 01:00 前代码变更补充文档，未执行新的构建或测试。
**Scope / 范围**: `README.md`, `README-RISCV64.md`, `RISC64-STATUS.md`, `issue.md`,
`docs/RISCV64_PORTING_GUIDE.md`, `docs/RISCV64_PORT_PLAN.md`.

### Entry 7 — Toolchain + Kernel Rebuild (2026-01-07) / 工具链 + 内核重建
**Workspace / 工作区**: `/root/minix`  
**Commands / 命令**:
```bash
# Rebuild tools (LLVM enabled) after ValueMap.h fix
MKPCI=no HOST_CFLAGS="-O -fcommon" HAVE_GOLD=no ./build.sh -U -m evbriscv64 tools

# Kernel rebuild with GCC toolchain + out-of-tree objdir
MAKEOBJDIRPREFIX=/root/minix/obj \
  obj/tooldir.Linux-6.12.57+deb13-amd64-x86_64/bin/nbmake-evbriscv64 \
  -C minix/kernel \
  CC=/root/minix/obj/tooldir.Linux-6.12.57+deb13-amd64-x86_64/bin/riscv64-elf32-minix-gcc \
  ACTIVE_CC=gcc \
  RISCV_ARCH_FLAGS='-march=RV64IMAFD -mcmodel=medany'
```
**Result / 结果**:
- Tools build succeeded after fixing `llvm/IR/ValueMap.h` explicit bool conversion.
- Kernel build succeeded with GCC toolchain + `MAKEOBJDIRPREFIX` setup.

### Entry 8 — RV64 memset Fix + Ramdisk/Memory Rebuild + QEMU Smoke (2026-02-16) / 修复 memset + 重建 ramdisk/memory + QEMU 冒烟
**Workspace / 工作区**: `/home/donz/minix`
**Target / 目标**: `evbriscv64`
**Toolchain / 工具链**: `obj/tooldir.Linux-6.12.63+deb13-amd64-x86_64`

**Context / 背景**:
- Interactive repro showed `ps -aux` SIGSEGV with stack-top fault (`sp=0xefbffff0`) and `pc` inside userland `memset`.
- `cat /proc/meminfo` path showed repeated safecopy fallback logs (`-14` / retry).

**Code changes linked to this run / 本轮关联代码改动**:
1. `lib/libc/arch/riscv/string/Makefile.inc`  
   Added:
   ```make
   COPTS.memset.c+= -fno-builtin-memset -fno-tree-loop-distribute-patterns
   ```
   to prevent RV64 recursive memset codegen.
2. `minix/servers/vfs/request.c`  
   Added procfs-specific magic-grant cpflag selection to avoid first-pass `CPF_TRY`
   retry churn on `/proc/*` read/stat/getdents/rdlink paths.

**Build and image steps / 构建与镜像步骤**:
```bash
# Rebuild ramdisk image from in-tree obj program paths
obj/tooldir.Linux-6.12.63+deb13-amd64-x86_64/bin/nbmake-evbriscv64 \
  -C minix/drivers/storage/ramdisk \
  MACHINE=evbriscv64 MACHINE_ARCH=riscv64 \
  NETBSDSRCDIR=$PWD DESTDIR=$PWD/obj/destdir.evbriscv64 \
  image

# Rebuild/install memory service with refreshed imgrd
obj/tooldir.Linux-6.12.63+deb13-amd64-x86_64/bin/nbmake-evbriscv64 \
  -C minix/drivers/storage/memory \
  MACHINE=evbriscv64 MACHINE_ARCH=riscv64 \
  NETBSDSRCDIR=$PWD DESTDIR=$PWD/obj/destdir.evbriscv64 \
  LDFLAGS= dependall install
```

**QEMU command / QEMU 启动命令**:
```bash
./minix/scripts/qemu-riscv64.sh \
  -s \
  -k obj.intrgcc/minix/kernel/kernel \
  -B obj.intrgcc/destdir.evbriscv64
```

备注 / Note:
- 日常验证建议使用 `obj.intrgcc/minix/kernel/kernel`，避免 `obj*/destdir.../boot/minix/.temp/kernel`
  与最新内核构建产物不同步而出现版本号回退。

**In-guest smoke commands / 来宾内冒烟命令**:
```sh
ps -aux
cat /proc/meminfo
```

**Observed result / 观察结果**:
- `ps -aux`: no SIGSEGV; process list returned and shell prompt restored.
- `cat /proc/meminfo`: prints meminfo successfully.
- A single recoverable safecopy fallback is still visible on procfs read path, tracked as `issue.md` #17.

**Toolchain note / 工具链备注**:
- In-tree linker compatibility issue with `R_RISCV_RELAX` remained visible during incremental rebuild attempts
  (`ld: unrecognized relocation (0x33)`), tracked as `issue.md` #24.

### Entry 9 — #24 `R_RISCV_RELAX` Compatibility Mitigation (2026-02-16) / #24 `R_RISCV_RELAX` 兼容性缓解
**Workspace / 工作区**: `/home/donz/minix`
**Target / 目标**: `evbriscv64`
**Toolchain / 工具链**: `obj/tooldir.Linux-6.12.63+deb13-amd64-x86_64`

**Code change / 代码改动**:
- Added tracked binutils patch:
  `external/gpl3/binutils/patches/0011-riscv-relax-compat.patch`
  to treat `R_RISCV_RELAX` as a hint/no-op in in-tree bfd paths.

**Build/validation steps / 构建与验证步骤**:
```bash
# Rebuild tools pipeline (binutils rebuilt/installed before later LLVM stages)
MKPCI=no HOST_CFLAGS='-O -fcommon' HAVE_GOLD=no ./build.sh -U -m evbriscv64 tools

# Confirm in-tree linker version
obj/tooldir.Linux-6.12.63+deb13-amd64-x86_64/riscv64-elf32-minix/bin/ld --version

# Verify RELAX relocations exist in target archives
obj/tooldir.Linux-6.12.63+deb13-amd64-x86_64/bin/riscv64-elf32-minix-readelf -r \
  obj/destdir.evbriscv64/usr/lib/libaudiodriver.a | grep R_RISCV_RELAX

# Validate in-tree ld can link RELAX-bearing archive (no 0x33 abort)
obj/tooldir.Linux-6.12.63+deb13-amd64-x86_64/riscv64-elf32-minix/bin/ld -r \
  --whole-archive obj/destdir.evbriscv64/usr/lib/libaudiodriver.a \
  --no-whole-archive -o /tmp/libaudiodriver.whole.o
```

**Observed result / 观察结果**:
- `readelf -r` shows multiple `R_RISCV_RELAX` entries in `libaudiodriver.a`.
- In-tree `ld` (NetBSD binutils 2.23.2) links the RELAX-bearing archive successfully,
  no `unrecognized relocation (0x33)` appears.
- #24 is mitigated in the current workspace and moved to fixed archive in `issue.md`.

**Follow-up note / 后续说明**:
- During forced GCC-only memory-service rebuild, a separate compiler capability issue was observed:
  `riscv64-elf32-minix-gcc: error: unrecognized command line option '-mabi=lp64d'`.
  This is distinct from #24 and should be tracked separately.

### Entry 10 — `obj.intrgcc` Self-Bootstrap Distribution + QEMU Validation (2026-02-16) / `obj.intrgcc` 自举 distribution + QEMU 验证
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Objdir / 对象目录**: `obj.intrgcc`  

**Goal / 目标**:
- Validate a fully isolated rebuild path (`tools -> distribution`) without injecting artifacts from `obj/`.
- Ensure QEMU can boot directly from `obj.intrgcc` outputs.

**Build commands / 构建命令**:
```bash
# 1) tools in isolated objdir
MKPCI=no HOST_CFLAGS="-O -fcommon" HAVE_GOLD=no HAVE_LLVM=no MKLLVM=no \
./build.sh -U -m evbriscv64 -O obj.intrgcc \
  -V AVAILABLE_COMPILER=gcc -V ACTIVE_CC=gcc -V ACTIVE_CPP=gcc -V ACTIVE_CXX=gcc -V ACTIVE_OBJC=gcc \
  tools

# 2) distribution in the same objdir
MKPCI=no HOST_CFLAGS="-O -fcommon" HAVE_GOLD=no HAVE_LLVM=no MKLLVM=no \
./build.sh -U -u -j"$(nproc)" -m evbriscv64 -O obj.intrgcc \
  -V AVAILABLE_COMPILER=gcc -V ACTIVE_CC=gcc -V ACTIVE_CPP=gcc -V ACTIVE_CXX=gcc -V ACTIVE_OBJC=gcc \
  -V RISCV_ARCH_FLAGS='-march=RV64IMAFD -mcmodel=medany' \
  -V NOGCCERROR=yes \
  -V MKPIC=no -V MKPICLIB=no -V MKPICINSTALL=no \
  -V MKCXX=no -V MKLIBSTDCXX=no -V MKATF=no \
  -V USE_PCI=no \
  -V CHECKFLIST_FLAGS='-m -e' \
  distribution
```

**QEMU command / QEMU 启动命令**:
```bash
./minix/scripts/qemu-riscv64.sh \
  -k obj.intrgcc/minix/kernel/kernel \
  -B obj.intrgcc/destdir.evbriscv64
```

**Observed result / 观察结果**:
- Distribution completed successfully on the `obj.intrgcc` path.
- QEMU reached interactive shell from `obj.intrgcc` outputs.
- `Boot module not found: ds` was no longer reproduced in this profile.

**Follow-up / 后续**:
- Keep `issue.md` `#17` (procfs safecopy fallback noise) and `#25`
  (GCC-only incremental ABI-flag compatibility) under ongoing tracking.

### Entry 11 — P0 Kernel Rebuild + QEMU Smoke Revalidation (2026-02-16) / P0 内核重建 + QEMU 冒烟复验
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Toolchain / 工具链**: `obj/tooldir.Linux-6.12.63+deb13-amd64-x86_64`  

**Goal / 目标**:
- Rebuild the riscv64 kernel with in-tree GCC after `vm_memset` fault-recovery plumbing changes.
- Revalidate P0 smoke paths in QEMU (`ps -aux`, `cat /proc/meminfo`, RS status query).

**Build command / 构建命令**:
```bash
TOOLDIR=$(echo obj/tooldir.* | awk '{print $1}')
${TOOLDIR}/bin/nbmake-evbriscv64 \
  -C minix/kernel -j"$(nproc)" dependall \
  ACTIVE_CC=gcc \
  RISCV_ARCH_FLAGS='-march=RV64IMAFD -mcmodel=medany'
```

**Build result / 构建结果**:
- `dependall` completed successfully; kernel link finished (`minix/kernel/obj/kernel`).
- Attempt without `ACTIVE_CC=gcc` selected missing `riscv64-elf32-minix-clang` and failed; rerun with GCC succeeded.

**QEMU smoke execution / QEMU 冒烟执行**:
```bash
{ sleep 35; echo 'ps -aux'; sleep 6; echo 'cat /proc/meminfo'; sleep 6; \
  echo '/sbin/minix-service sysctl srv_status'; sleep 6; } \
| timeout 220 ./minix/scripts/qemu-riscv64.sh -s \
    -k minix/kernel/obj/kernel \
    -B obj/destdir.evbriscv64 \
  > /tmp/qemu-p0-smoke.log 2>&1 || true
```

**Observed result / 观察结果**:
- In-log markers confirm all three commands returned success:
  `__RC_PS__:0`, `__RC_MEMINFO__:0`, `__RC_SRV__:0`.
- No `SIGSEGV` signature and no kernel panic were observed in this run.
- procfs/safecopy fallback noise is still visible but recoverable (commands still succeed), consistent with `issue.md` `#17`.

**Evidence / 证据**:
- Log: `/tmp/qemu-p0-smoke.log`
- Marker lines include `__P0_BEGIN__`, `__RC_PS__:0`, `__RC_MEMINFO__:0`, `__RC_SRV__:0`, `__P0_DONE__`.

### Entry 12 — `obj.intrgcc` Fully Self-Hosted GCC Toolchain Closure (2026-02-16) / `obj.intrgcc` 完全自举 GCC 工具链收敛
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Objdir / 对象目录**: `obj.intrgcc`

**Goal / 目标**:
- Close the isolated toolchain path with in-tree GCC frontend commands enabled (`MKGCCCMDS=yes`).
- Revalidate `distribution` and QEMU boot strictly from `obj.intrgcc`.

**Build commands / 构建命令**:
```bash
# 1) tools with in-tree GCC command wrappers/frontends
MKPCI=no HOST_CFLAGS='-O -fcommon' HAVE_GOLD=no HAVE_LLVM=no MKLLVM=no \
./build.sh -U -m evbriscv64 -O obj.intrgcc \
  -V AVAILABLE_COMPILER=gcc -V ACTIVE_CC=gcc -V ACTIVE_CPP=gcc -V ACTIVE_CXX=gcc -V ACTIVE_OBJC=gcc \
  -V MKGCC=yes -V MKGCCCMDS=yes \
  tools

# 2) distribution on the same isolated objdir
MKPCI=no HOST_CFLAGS='-O -fcommon' HAVE_GOLD=no HAVE_LLVM=no MKLLVM=no \
./build.sh -U -u -j"$(nproc)" -m evbriscv64 -O obj.intrgcc \
  -V AVAILABLE_COMPILER=gcc -V ACTIVE_CC=gcc -V ACTIVE_CPP=gcc -V ACTIVE_CXX=gcc -V ACTIVE_OBJC=gcc \
  -V RISCV_ARCH_FLAGS='-march=RV64IMAFD -mcmodel=medany' \
  -V NOGCCERROR=yes \
  -V MKPIC=no -V MKPICLIB=no -V MKPICINSTALL=no \
  -V MKCXX=no -V MKLIBSTDCXX=no -V MKATF=no \
  -V USE_PCI=no \
  -V CHECKFLIST_FLAGS='-m -e' \
  distribution
```

**Toolchain artifact checks / 工具链产物校验**:
```bash
TOOLDIR=$(echo obj.intrgcc/tooldir.*-x86_64)
ls -l \
  "$TOOLDIR/bin/riscv64-elf32-minix-gcc" \
  "$TOOLDIR/bin/riscv64-elf32-minix-c++" \
  "$TOOLDIR/bin/riscv64-elf32-minix-cpp" \
  "$TOOLDIR/bin/riscv64-elf32-minix-g++"
file \
  "$TOOLDIR/bin/riscv64-elf32-minix-gcc" \
  "$TOOLDIR/bin/riscv64-elf32-minix-c++" \
  "$TOOLDIR/bin/riscv64-elf32-minix-cpp" \
  "$TOOLDIR/bin/riscv64-elf32-minix-g++"
```

**QEMU validation / QEMU 验证**:
```bash
timeout 45 ./minix/scripts/qemu-riscv64.sh \
  -k obj.intrgcc/minix/kernel/kernel \
  -B obj.intrgcc/destdir.evbriscv64
```

**Observed result / 观察结果**:
- `tools` completed with `MKGCC=yes` + `MKGCCCMDS=yes` (no fallback injection from `obj/` needed).
- `riscv64-elf32-minix-{gcc,c++,cpp,g++}` were present as local ELF executables under
  `obj.intrgcc/tooldir.*/bin`.
- `distribution` completed successfully on the same `obj.intrgcc`.
- QEMU boot output listed `Boot modules (12)` including `service/ds`, reached shell prompt (`#`),
  and did not reproduce `Boot module not found: ds`.

**Notes / 备注**:
- The QEMU run was bounded by `timeout`; termination by SIGTERM at timeout boundary is expected
  for log-capture runs and does not indicate runtime crash.

### Entry 17 — Strict Runtime-Aware Smoke Gate Hardening (2026-02-17) / 严格运行时感知 smoke 门禁加固
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Raise smoke rigor from boot-only signal to boot + runtime signal.
- Make each round verify command-level usability in guest userland.

**Code updates / 代码更新**:
- Added runtime probe runner:
  `minix/tests/riscv64/qemu_runtime_probe.py`.
- Integrated runtime probe into multi-run gate with default-on behavior:
  `minix/tests/riscv64/multi_smoke_gate.sh`.
- Added probe controls:
  `--runtime-probe` / `--no-runtime-probe`,
  `--runtime-timeout`, `--runtime-cmd-timeout`.
- Fixed gate reporting bug on runtime probe failure branch (preserve non-zero probe RC).

**Commands executed / 实际执行命令**:
```bash
# 1) syntax and bytecode checks
bash -n minix/tests/riscv64/multi_smoke_gate.sh
python3 -m py_compile minix/tests/riscv64/qemu_runtime_probe.py

# 2) targeted with-disk runtime probe check
tmpimg=/tmp/minix-runtime-probe-req2.$$.img
truncate -s 128M "$tmpimg"
python3 minix/tests/riscv64/qemu_runtime_probe.py \
  --qemu-script ./minix/scripts/qemu-riscv64.sh \
  --kernel ./obj.intrgcc/minix/kernel/kernel \
  --destdir ./obj.intrgcc/destdir.evbriscv64 \
  --disk "$tmpimg" --require-disk-node \
  --timeout 70 --cmd-timeout 35
rm -f "$tmpimg"

# 3) strict multi-run gate (diskless + with-disk)
./minix/tests/riscv64/multi_smoke_gate.sh \
  --rounds 1 --timeout 70 \
  --runtime-timeout 70 --runtime-cmd-timeout 35
```

**Observed result / 观察结果**:
- Runtime probe now validates:
  `cat /proc/meminfo`, `ps -aux`, `minix-service sysctl srv_status`,
  and `/dev/c0d0` existence for with-disk rounds.
- Strict gate run passes end-to-end with summary:
  `Passed: 2`, `Failed: 0`, `Runtime passed: 2`, `Runtime failed: 0`.

**Evidence / 证据**:
- `/tmp/minix-smoke-gate-20260217-070246`

### Entry 16 — RS Leak-Path Closure + Gate Hardening Follow-up (2026-02-16) / RS 泄漏路径收敛 + 门禁加固续验
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Close issue `#26` by fixing RS slot cleanup on post-`init_slot()` failures.
- Preserve `#28` fix while restoring no-state update semantics (no payload => `size=0`).
- Harden `#31` relax probe to avoid false-positive pass on empty archive links.
- Revalidate per-round independent with-disk reproducibility.

**Commands executed / 实际执行命令**:
```bash
# 1) targeted RS rebuild
TOOLDIR=$(ls -d obj.intrgcc/tooldir.* | head -n1)
"$TOOLDIR/bin/nbmake-evbriscv64" -C minix/servers/rs

# 2) per-round reproducibility smoke (diskless + with-disk)
./minix/tests/riscv64/multi_smoke_gate.sh \
  --kernel obj.intrgcc/minix/kernel/kernel \
  --destdir obj.intrgcc/destdir.evbriscv64 \
  --rounds 2 --timeout 60 \
  --log-root /tmp/minix-smoke-gate-indep-20260216-234830

# 3) repro gate follow-up (skip rebuild, validate gate path)
./minix/tests/riscv64/repro_build_gate.sh \
  --objdir obj.intrgcc \
  --skip-tools --skip-distribution \
  --smoke-rounds 1 --smoke-timeout 45 \
  --without-disk

# 4) relax probe behavior sanity check
TOOLDIR=$(ls -d obj.intrgcc/tooldir.* | head -n1)
LD="$TOOLDIR/riscv64-elf32-minix/bin/ld"
[ -x "$LD" ] || LD="$TOOLDIR/bin/riscv64-elf32-minix-ld"
"$LD" -r --whole-archive obj.intrgcc/destdir.evbriscv64/usr/lib/libsys.a \
  --no-whole-archive -o /tmp/ld-whole-check.o
stat -c 'whole_archive_output_size=%s' /tmp/ld-whole-check.o
```

**Observed result / 观察结果**:
- `nbmake-evbriscv64 -C minix/servers/rs` rebuilds and links successfully.
- Multi-smoke passes `4/4`; logs show per-round disk images:
  `...minix-smoke-gate.round1.img` and `...minix-smoke-gate.round2.img`.
- `repro_build_gate.sh --skip-tools --skip-distribution ...` passes diskless smoke (`1/1`).
- Whole-archive probe output is non-empty (`whole_archive_output_size=206453`), confirming
  the probe now exercises real archive-member link paths.
- Code changes landed in:
  `minix/servers/rs/request.c`,
  `minix/servers/rs/manager.c`,
  `minix/tests/riscv64/repro_build_gate.sh`.

**Evidence / 证据**:
- `/tmp/minix-smoke-gate-indep-20260216-234830`
- `/tmp/minix-smoke-gate-20260217-000150`

### Entry 15 — Full Reproducibility Gate + Fresh Multi-Run Smoke (2026-02-16) / 全量复现门禁 + 新一轮多轮 smoke
**Workspace / 工作区**: `/home/donz/minix`
**Target / 目标**: `evbriscv64`
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Close the loop on source-driven reproducibility (no manual patching/copying).
- Re-run multi-round smoke after the full gate to avoid single-pass bias.

**Commands executed / 实际执行命令**:
```bash
./minix/tests/riscv64/repro_build_gate.sh \
  --objdir obj.intrgcc \
  --smoke-rounds 1 \
  --smoke-timeout 60 \
  --without-disk

./minix/tests/riscv64/multi_smoke_gate.sh \
  --kernel obj.intrgcc/minix/kernel/kernel \
  --destdir obj.intrgcc/destdir.evbriscv64 \
  --rounds 2 --timeout 90
```

**Observed result / 观察结果**:
- `repro_build_gate.sh` completed `tools -> distribution -> smoke` with `exit 0`.
- `build.sh` reported `Successful make distribution` on `obj.intrgcc` in the same run.
- Re-run multi-smoke finished `4/4` pass (diskless+with-disk x2).
- All four triage reports classify first safecopy as `acceptable_noise`
  (`first_safecopy_line=414`, `safecopy_total=8`, `safecopy_pre_shell=1`).
- With-disk rounds preserved `virtio-blk-mmio: initialized` and did not reproduce
  `device not found` / `Request 0x700 to RS failed` / `couldn't start virtio_blk_mmio`.

**Evidence / 证据**:
- Repro gate smoke log root: `/tmp/minix-smoke-gate-20260216-223948`
- Fresh multi-run gate log root: `/tmp/minix-smoke-gate-20260216-224157`

### Entry 14 — Automated Multi-Run Gate + Safecopy First-Error Triage (2026-02-16) / 自动化多轮门禁 + safecopy 首错定性
**Workspace / 工作区**: `/home/donz/minix`
**Target / 目标**: `evbriscv64`
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Convert ad-hoc smoke checks into a minimum automated gate.
- Classify safecopy first error as acceptable noise vs potential consistency issue.
- Add a reproducible-build gate entrypoint that avoids manual artifact injection.

**Added scripts / 新增脚本**:
```text
minix/tests/riscv64/safecopy_triage.py
minix/tests/riscv64/multi_smoke_gate.sh
minix/tests/riscv64/repro_build_gate.sh
```

**Hook-up / 接入**:
- `minix/tests/riscv64/run_tests.sh` adds `gate` mode:
  `./minix/tests/riscv64/run_tests.sh gate`

**Gate command executed / 实际执行命令**:
```bash
./minix/tests/riscv64/multi_smoke_gate.sh \
  --kernel obj.intrgcc/minix/kernel/kernel \
  --destdir obj.intrgcc/destdir.evbriscv64 \
  --rounds 2 --timeout 90
```

**Observed result / 观察结果**:
- 4/4 runs passed (diskless round1/2 + with-disk round1/2).
- No panic/SIGSEGV fatal signature in any round log.
- With-disk rounds kept `virtio-blk-mmio: initialized` and did not reproduce:
  `device not found`, `Request 0x700 to RS failed`, `couldn't start virtio_blk_mmio`.
- `safecopy_triage.py` on gate logs reports:
  `classification: acceptable_noise`,
  `first_safecopy_line: 414`,
  known recoverable startup fallback pattern.

**Evidence / 证据**:
- Log root: `/tmp/minix-smoke-gate-20260216-221610`
- Files include per-round `.log` and `.triage.txt`.

### Entry 13 — RS P0 Incremental Convergence + Diskless/With-Disk Smoke (2026-02-16) / RS P0 增量收敛 + 无盘/带盘冒烟
**Workspace / 工作区**: `/home/donz/minix`
**Target / 目标**: `evbriscv64`
**Objdir / 对象目录**: `obj.intrgcc`

**Goal / 目标**:
- Run a small convergence cycle after RS P0 hardening:
  incremental rebuild/install, baseline boot smoke, with-disk boot smoke,
  and first-error check.
- Confirm that with-disk startup no longer emits the previous `virtio_blk_mmio`
  startup-failure signature.

**Incremental build/install / 增量构建与安装**:
```bash
obj.intrgcc/tooldir.Linux-6.12.63+deb13-amd64-x86_64/bin/nbmake-evbriscv64 \
  -C minix/servers/rs
obj.intrgcc/tooldir.Linux-6.12.63+deb13-amd64-x86_64/bin/nbmake-evbriscv64 \
  -C minix/servers/rs install
```

**Smoke commands / 冒烟命令**:
```bash
# diskless baseline smoke
timeout 120 ./minix/scripts/qemu-riscv64.sh -s \
  -k obj.intrgcc/minix/kernel/kernel \
  -B obj.intrgcc/destdir.evbriscv64 \
  > /tmp/qemu-smoke-incremental.log 2>&1 || true

# with-disk smoke
truncate -s 128M /tmp/minix-smoke-disk.img
timeout 140 ./minix/scripts/qemu-riscv64.sh -s \
  -k obj.intrgcc/minix/kernel/kernel \
  -B obj.intrgcc/destdir.evbriscv64 \
  -i /tmp/minix-smoke-disk.img \
  > /tmp/qemu-smoke-disk.log 2>&1 || true
```

**Observed result / 观察结果**:
- Incremental RS rebuild/install completed successfully.
- Diskless and with-disk smoke both reached shell path (`MINIX 4.0.0`, `/bin/sh`),
  and no kernel panic / `SIGSEGV` signature was observed.
- With-disk smoke shows:
  `virtio-blk-mmio: capacity: 262144 sectors` and `virtio-blk-mmio: initialized`,
  while the old warning pattern is absent:
  `virtio-blk-mmio: device not found`,
  `Request 0x700 to RS failed`,
  `WARNING: couldn't start virtio_blk_mmio`.
- First non-fatal error in both logs is still recoverable safecopy fallback noise
  (`kcall safecopy err`, `do_safecopy_*`), tracked as `issue.md` #17.

**Evidence / 证据**:
- `/tmp/qemu-smoke-incremental.log`
- `/tmp/qemu-smoke-disk.log`

### Entry 16 — neofetch Service Source Switch + Version Bump to 4.0.0 (2026-02-17) / neofetch 服务源切换 + 版本升级到 4.0.0
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Make `neofetch` service fields (`Services/CoreSvc/Missing`) useful by default,
  without relying on noisy default `ps` probing.
- Roll system/release version to `4.0.0` and keep runtime profile consistent.

**Code changes linked to this run / 本轮关联代码改动**:
1. `minix/drivers/storage/ramdisk/neofetch`
   - default probe mode switched from `off` to `auto`;
   - `auto` now prefers `/proc/service` for service summary;
   - `ps` path remains opt-in with `NEOFETCH_SERVICE_PROBE=ps`.
2. `minix/include/minix/config.h`
   - `OS_RELEASE` updated to `4.0.0`;
   - `OS_REV` updated to `400000000`.
3. `minimal_kernel/include/minix/config.h`
   - `OS_RELEASE` / `OS_REV` aligned to `4.0.0` / `400000000`.
4. `minix/releasetools/riscv64/release.conf`
   - `MINIX_VERSION` updated to `4.0.0-riscv64`.

**Build/install commands / 构建与安装命令**:
```bash
obj.intrgcc/tooldir.Linux-6.12.63+deb13-amd64-x86_64/bin/nbmake-evbriscv64 \
  -C minix/drivers/storage/ramdisk image

obj.intrgcc/tooldir.Linux-6.12.63+deb13-amd64-x86_64/bin/nbmake-evbriscv64 \
  -C minix/drivers/storage/memory all install
```

**Runtime probe command / 运行时探针命令**:
```bash
python3 minix/tests/riscv64/qemu_runtime_probe.py \
  --qemu-script minix/scripts/qemu-riscv64.sh \
  --kernel obj.intrgcc/minix/kernel/kernel \
  --destdir obj.intrgcc/destdir.evbriscv64 \
  --require-disk-node
```

**Observed result / 观察结果**:
- Ramdisk image and memory service rebuild/install completed successfully.
- Runtime probe passed all checks:
  `meminfo`, `ps_aux`, `srv_status`, `disk_node`.
- Service-summary data path in `neofetch` now defaults to procfs (`/proc/service`)
  instead of disabled-by-default mode, with explicit `ps` opt-in retained.
- System version macros and riscv64 release profile are now aligned to `4.0.0`.

**Evidence / 证据**:
- `qemu_runtime_probe.py` result: `PASS: qemu runtime probe`
- Updated source files:
  `minix/drivers/storage/ramdisk/neofetch`,
  `minix/include/minix/config.h`,
  `minimal_kernel/include/minix/config.h`,
  `minix/releasetools/riscv64/release.conf`

### Entry 17 — GCC ABI-Flag Baseline Alignment for riscv64 (#25) (2026-02-17) / riscv64 GCC ABI 参数基线收敛（#25）
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc` + raw `nbmake` verification

**Goal / 目标**:
- Remove default `-mabi=lp64d` dependency from riscv64 baseline flags to avoid
  GCC-only incremental rebuild incompatibility in environments that do not
  support that ABI option.
- Eliminate wrapper-only behavior drift by making the source-tree default align
  with the validated in-tree GCC path.

**Code change / 代码改动**:
1. `share/mk/bsd.own.mk`
   - riscv64 default `RISCV_ARCH_FLAGS` changed from
     `-march=rv64gc -mabi=lp64d` to
     `-march=RV64IMAFD -mcmodel=medany`.

**Verification commands / 验证命令**:
```bash
# Verify default from source-tree mk logic (non-wrapper lookup)
TOOLDIR="$PWD/obj.intrgcc/tooldir.Linux-6.12.63+deb13-amd64-x86_64"
"$TOOLDIR/bin/nbmake" -m "$PWD/share/mk" -C minix/drivers/storage/memory \
  MACHINE=evbriscv64 MACHINE_ARCH=riscv64 USETOOLS=yes \
  TOOLDIR="$TOOLDIR" DESTDIR="$PWD/obj.intrgcc/destdir.evbriscv64" \
  NETBSDSRCDIR="$PWD" ACTIVE_CC=gcc AVAILABLE_COMPILER=gcc \
  -V RISCV_ARCH_FLAGS

# Raw (non-wrapper) GCC incremental rebuild sanity
MAKEFLAGS='-de -m /home/donz/minix/share/mk  MKOBJDIRS=yes' \
"$TOOLDIR/bin/nbmake" -C minix/servers/mib \
  MACHINE=evbriscv64 MACHINE_ARCH=riscv64 USETOOLS=yes \
  TOOLDIR="$TOOLDIR" DESTDIR="$PWD/obj.intrgcc/destdir.evbriscv64" \
  NETBSDSRCDIR="$PWD" ACTIVE_CC=gcc AVAILABLE_COMPILER=gcc \
  clean dependall
```

**Observed result / 观察结果**:
- `RISCV_ARCH_FLAGS` now resolves to `-march=RV64IMAFD -mcmodel=medany`.
- Raw (non-wrapper) `ACTIVE_CC=gcc` rebuild of `minix/servers/mib` completed
  successfully with the aligned flags.
- No `-mabi=lp64d` option was emitted in the successful compile lines.

### Entry 18 — riscv64 mkdisk U-Boot Disk-Boot Image Rework (2026-02-17) / riscv64 mkdisk U-Boot 磁盘启动镜像重构
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Make `minix/releasetools/riscv64/mkdisk.sh` produce a meaningful disk image
  without requiring root loop-mount flow.
- Generate a U-Boot autodiscovery boot path (`boot.scr`) with preloaded MINIX
  module payloads.

**Code change / 代码改动**:
1. `minix/releasetools/riscv64/mkdisk.sh`
   - add `/usr/sbin:/sbin` PATH bootstrap;
   - add hard checks for required host tools (`parted|sfdisk`, `mke2fs`,
     `mkimage`, `python3`, `objcopy`);
   - generate MBR partition table and populate ext2 filesystems without root
     (via `mke2fs -d`);
   - build BSS-inclusive `/boot/kernel.bin` payload from kernel ELF via
     `objcopy --set-section-flags .unpaged_bss/.bss=alloc,load,contents`;
   - build `boot.scr.uimg` plus `/boot/kernel.bin`, `/boot/minix.modinfo`,
     `/boot/modules/*`;
   - switch handoff from `bootelf` to `go 0x80200000` for the generated
     raw payload;
   - keep output size summary based on real file bytes.

**Verification commands / 验证命令**:
```bash
# Rebuild image from obj.intrgcc artifacts
PATH=/usr/sbin:/sbin:$PATH \
  minix/releasetools/riscv64/mkdisk.sh \
  -d /home/donz/minix/obj.intrgcc \
  -o /home/donz/minix/obj.intrgcc/release/minix-evbriscv64-boot.img \
  -s 256

# Disk-only path with OpenSBI + U-Boot(smode) payload
timeout 50s qemu-system-riscv64 -machine virt -m 256M -nographic \
  -bios default \
  -kernel /usr/lib/u-boot/qemu-riscv64_smode/uboot.elf \
  -drive if=none,file=/home/donz/minix/obj.intrgcc/release/minix-evbriscv64-boot.img,format=raw,id=hd0 \
  -device virtio-blk-device,drive=hd0 \
  > /tmp/qemu-uboot-diskonly-new-smode.log 2>&1 || true

# Existing reference boot path regression
timeout 60s minix/scripts/qemu-riscv64.sh -s \
  -k /home/donz/minix/obj.intrgcc/minix/kernel/kernel \
  -B /home/donz/minix/obj.intrgcc/destdir.evbriscv64 \
  -i /home/donz/minix/obj.intrgcc/release/minix-evbriscv64-boot.img \
  > /tmp/qemu-with-kernel-after-mkdisk-rework.log 2>&1
```

**Observed result / 观察结果**:
- U-Boot now finds and executes the image-provided script automatically:
  `Found U-Boot script /boot.scr.uimg`, `## Executing script ...`.
- Script-driven disk payload boot now reaches MINIX userland:
  `rv64: kernel_main` -> `MINIX 4.0.0` -> `#` shell prompt.
- `virtio-blk-mmio` initialization appears in the same disk-only run:
  `virtio-blk-mmio: initialized`.
- Existing reference boot profile remains good.

**Evidence / 证据**:
- `/tmp/qemu-uboot-diskonly-new-smode.log`
- `/tmp/qemu-with-kernel-after-mkdisk-rework.log`

### Entry 19 — RV64 FDT Boot-Pointer Bridge + Full riscv64 Regression (2026-02-17) / RV64 FDT 启动指针桥接修复 + riscv64 全量回归
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Fix low-memory detection caused by FDT pointer namespace split
  (`__k_unpaged__boot_fdt` vs `_boot_fdt`) during RV64 early boot.
- Re-run full riscv64 regression after the fix and capture reproducible evidence.

**Code changes / 代码改动**:
1. `minix/kernel/arch/riscv64/kernel.c`
   - bridge boot FDT pointer in `kernel_main()`:
     `_boot_fdt = __k_unpaged__boot_fdt` when runtime symbol is zero.
2. `minix/kernel/arch/riscv64/bsp/virt/bsp_init.c`
   - keep BSP parser on runtime symbol (`_boot_fdt`) with explicit
     `(uintptr_t)` cast.

**Build/verification commands / 构建与验证命令**:
```bash
# Incremental kernel rebuild in obj.intrgcc profile
obj.intrgcc/tooldir.Linux-6.12.63+deb13-amd64-x86_64/bin/nbmake-evbriscv64 \
  -C minix/kernel dependall

# Runtime memory-path verification
timeout 120 ./minix/scripts/qemu-riscv64.sh \
  -k obj.intrgcc/minix/kernel/kernel \
  -B obj.intrgcc/destdir.evbriscv64 \
  > /tmp/qemu-memfix.log 2>&1

# Runtime neofetch/meminfo verification
(printf 'cat /proc/meminfo\nneofetch\n'; sleep 1) | \
  timeout 140 ./minix/scripts/qemu-riscv64.sh \
    -k obj.intrgcc/minix/kernel/kernel \
    -B obj.intrgcc/destdir.evbriscv64 \
    > /tmp/qemu-neofetch-memfix.log 2>&1

# Full riscv64 suite
TOOLDIR=/home/donz/minix/obj.intrgcc/tooldir.Linux-6.12.63+deb13-amd64-x86_64 \
DESTDIR=/home/donz/minix/obj.intrgcc/destdir.evbriscv64 \
KERNEL=/home/donz/minix/obj.intrgcc/minix/kernel/kernel \
NBMAKE=/home/donz/minix/obj.intrgcc/tooldir.Linux-6.12.63+deb13-amd64-x86_64/bin/nbmake-evbriscv64 \
READELF=/home/donz/minix/obj.intrgcc/tooldir.Linux-6.12.63+deb13-amd64-x86_64/bin/riscv64-elf32-minix-readelf \
TIMEOUT=90 \
timeout 1800 ./minix/tests/riscv64/run_tests.sh all \
  > /tmp/minix-full-riscv64-tests.log 2>&1
```

**Observed result / 观察结果**:
- FDT memory parsing restored full 256MB range:
  `Memory: 0x80000000 - 0x90000000`.
- `neofetch` memory raw line reflects the larger VM total after fix:
  `Mem(raw): 4096 61767 52676 48338 1185`
  (previously total page count was around `28999` in the failing path).
- Full riscv64 regression passed:
  `Passed: 21`, `Failed: 0`, `Skipped: 1` (SMP test marked not implemented).
- Multi-run smoke gate inside the same run passed:
  `Passed: 4`, `Failed: 0`, `Runtime passed: 4`, `Runtime failed: 0`.
- Host-side `minix/tests/run -T` still depends on in-guest MINIX runtime
  environment and is not treated as riscv64 target pass/fail evidence.

**Evidence / 证据**:
- `/tmp/qemu-memfix.log`
- `/tmp/qemu-neofetch-memfix.log`
- `/tmp/minix-full-riscv64-tests.log`
- `/tmp/minix-smoke-gate-20260217-165805/`

### Entry 20 — lwIP Raw-Socket Permission Fix Retest + New ping6 Scoped Crash Finding (2026-02-18) / lwIP raw socket 权限修复复测 + 新增 ping6 scoped 崩溃发现
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Revalidate networking after adding `pm` to `service lwip` IPC allow-list.
- Confirm the previous `ping/ping6` `Permission denied` signature is removed.
- Capture any remaining IPv6 runtime blockers.

**Code changes linked to this run / 本轮关联代码改动**:
1. `minix/releasetools/riscv64/system.conf`
   - `service lwip` IPC mask:
     `ipc SYSTEM ds vfs rs vm mib;` -> `ipc SYSTEM pm ds vfs rs vm mib;`
2. `minix/net/lwip/lwip.c`
   - Removed temporary `RAWDBG` tracing used for permission-path diagnosis.

**Build/image commands / 构建与镜像命令**:
```bash
TOOLDIR=$(echo /home/donz/minix/obj.intrgcc/tooldir.*)
NBMAKE="$TOOLDIR/bin/nbmake-evbriscv64"

"$NBMAKE" -C minix/net/lwip all install
"$NBMAKE" -C minix/drivers/storage/ramdisk RAMDISK_TESTS=1 image
"$NBMAKE" -C minix/drivers/storage/memory RAMDISK_TESTS=1 all install
```

**QEMU/runtime verification / QEMU 运行时验证**:
```bash
OBJDIR=/home/donz/minix/obj.intrgcc \
  /tmp/qemu-riscv64-nohostfwd.sh -n \
  -B /home/donz/minix/obj.intrgcc/destdir.evbriscv64 \
  -k /home/donz/minix/obj.intrgcc/minix/kernel/kernel
```

In-guest commands / 来宾内命令:
```sh
/sbin/ping -c 1 10.0.2.2
/sbin/ping6 -c 1 ::1
/sbin/ping6 -c 1 fe80::2%vio0
/sbin/route -n show
/sbin/ifconfig -a
```

**Observed result / 观察结果**:
- `ping/ping6` raw-socket creation no longer fails with `Permission denied`.
  Previous kernel denial signature (`ipc mask denied SENDREC ... to 0`) is not reproduced
  on raw-socket creation path in this run.
- `/sbin/ping6 -c 1 ::1` succeeds (`0% packet loss`), confirming IPv6 loopback ICMP path is alive.
- `/sbin/ping -c 1 10.0.2.2` enters normal send/wait path (this run timed out with packet loss, but no permission failure).
- New finding: `/sbin/ping6 -c 1 fe80::2%vio0` crashes in userspace with
  `VM: pagefault: SIGSEGV ... bad addr 0x0` and shell-side `Segmentation fault`.
  This is tracked as a new open issue (`issue.md` #35).

**Evidence / 证据**:
- Interactive QEMU PTY transcript captured in this session (2026-02-18, `obj.intrgcc` profile).

### Entry 21 — ping6 Soft-Timer Stabilization + Public Reachability Validation (slirp) (2026-02-18) / ping6 软定时稳定化 + 公网可达性验收（slirp）
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Close the remaining `ping6` userland crash path (`#35`) with no-count loopback
  and dual-VM link-local revalidation.
- Verify first-pass public reachability from MINIX guest.

**Code changes linked to this run / 本轮关联代码改动**:
1. `sbin/ping6/ping6.c`
   - On `__minix`, add `SO_RCVTIMEO` for bounded receive wait.
   - Keep non-Minix `SIGALRM`/`setitimer` pacing unchanged.
   - On Minix path, use monotonic soft-timer pacing in main loop
     (instead of timer-signal retransmit path), and preserve graceful
     `EAGAIN/EWOULDBLOCK` handling.
   - For Minix verbose extension-header options, keep warnings instead of hard
     exit when setsockopt is unsupported.

**Build/image commands / 构建与镜像命令**:
```bash
TOOLDIR=$(echo /home/donz/minix/obj.intrgcc/tooldir.*)
NBMAKE="$TOOLDIR/bin/nbmake-evbriscv64"

"$NBMAKE" -C sbin/ping6 all install
"$NBMAKE" -C minix/drivers/storage/ramdisk RAMDISK_TESTS=1 image
"$NBMAKE" -C minix/drivers/storage/memory RAMDISK_TESTS=1 all install
```

**QEMU/runtime verification / QEMU 运行时验证**:
```bash
OBJDIR=/home/donz/minix/obj.intrgcc \
  /tmp/qemu-riscv64-nohostfwd.sh -n \
  -B /home/donz/minix/obj.intrgcc/destdir.evbriscv64 \
  -k /home/donz/minix/obj.intrgcc/minix/kernel/kernel
```

In-guest commands / 来宾内命令:
```sh
/sbin/ping6 ::1
/sbin/ping6 -c 5 ::1
/sbin/ping -c 2 10.0.2.2
/sbin/ping -c 2 1.1.1.1
```

Dual-VM link-local check / 双 VM 链路本地复测:
```sh
/sbin/ping6 -q -c 1 fe80::5054:ff:fe12:3457%vio0
```

**Observed result / 观察结果**:
- `ping6 ::1` (no `-c`) no longer reproduces `SIGSEGV ... bad addr 0x0` in
  this runtime window.
- `ping6 -c 5 ::1` returns normal success statistics.
- Dual-VM link-local `ping6 -q -c 1 fe80::...%vio0` passes without process crash.
- Public reachability check passes in QEMU user-net (slirp):
  guest can ping both gateway (`10.0.2.2`) and public IP (`1.1.1.1`).
- Bridge-mode validation remains host-config dependent (missing bridge-helper
  prerequisites on this host), so slirp is used as the current acceptance mode.

**Evidence / 证据**:
- `/tmp/qemu-ping6-loopback-nocount-softtimer-20260218.log`
- `/tmp/qemu-ping6-dual-softtimer-20260218.log`
- `/tmp/qemu-minix-public-ping-slirp-root-20260218.log`

### Entry 22 — Add Dedicated VirtIO Driver Guide (Doc Update Only) (2026-02-18) / 新增 VirtIO 驱动专门文档（仅文档更新）
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Add one dedicated document for current VirtIO driver implementation and
  acceptance workflow, so future network/storage iterations have a stable
  technical reference.

**Documentation changes / 文档变更**:
1. Added `docs/RISCV64_VIRTIO_DRIVER_GUIDE.md`
   - Scope/stack map for `virtio_blk_mmio`, `virtio_net_mmio`, `libvirtio_mmio`.
   - MMIO/IRQ layout and service policy (`system.conf`, `lwip.conf`, ramdisk `rc`).
   - Build/refresh commands (obj.intrgcc baseline).
   - Runtime profiles, acceptance checklist, and common failure signatures.
2. Updated `README-RISCV64.md`
   - Added guide link in References section.
   - Bumped document version metadata (`1.12`).

**Build/test status / 构建测试状态**:
- No new code build or runtime test executed in this entry.
- 本条目仅文档更新，未新增构建与运行测试。

**Evidence / 证据**:
- `docs/RISCV64_VIRTIO_DRIVER_GUIDE.md`
- `README-RISCV64.md`

### Entry 23 — Add GitHub Actions Release Pipeline (Doc/CI Update) (2026-02-18) / 新增 GitHub Actions 自动发布流水线（文档/CI 更新）
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Add a repository-native pipeline that can build riscv64 artifacts and publish
  release assets directly to GitHub Release.

**CI changes / CI 变更**:
1. Added `/.github/workflows/release-riscv64.yml`
   - Trigger on tag push (`v*`) and manual dispatch.
   - Build flow: `tools -> distribution` on `obj.intrgcc`.
   - Package flow: run `minix/releasetools/riscv64/mkdisk.sh`.
   - Publish flow: upload `.img`, `.sha256`, and manifest to GitHub Release.
2. Updated `README-RISCV64.md`
   - Added a dedicated section documenting trigger method, outputs, and required
     workflow permissions.
   - Bumped document version metadata (`1.13`).

**Build/test status / 构建测试状态**:
- This entry introduces CI workflow and docs; no local full rebuild/retest was
  executed in this log entry.
- 本条目为 CI/文档更新，未在本地执行新的完整重建与运行测试。

**Evidence / 证据**:
- `.github/workflows/release-riscv64.yml`

### Entry 28 — Fix CI Missing `-lgcc/-lgcc_eh` During Static Links (2026-02-18) / 修复 CI 静态链接缺失 `-lgcc/-lgcc_eh`
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- Release workflow reached `distribution`, then failed in static links
  (`external/bsd/bind/bin/dig`) with:
  - `ld: cannot find -lgcc`
  - `ld: cannot find -lgcc_eh`

**Root cause / 根因**:
- On Minix build defaults, `MKGCC` is `no` unless explicitly enabled.
- CI `distribution` step previously did not force `MKGCC=yes`, so target-side
  GCC runtime libraries (`libgcc.a`, `libgcc_eh.a`) were not generated into
  `${DESTDIR}/usr/lib`.
- Cross gcc then failed to satisfy static link dependencies.

**Fix / 修复**:
1. Updated `/.github/workflows/release-riscv64.yml` (distribution step) to add:
   - `-V MKGCC=yes`
   - `-V MKGCCCMDS=no`
   - `-V MKLIBOBJC=no`
   - `-V MKLIBGOMP=no`
2. Kept existing `MKCXX=no` / `MKLIBSTDCXX=no` profile to avoid unrelated C++
   closure expansion in this release lane.

**Validation status / 验证状态**:
- Workflow updated and retrigger pending for run-time confirmation.
- Success criterion: `distribution` no longer fails at `cannot find -lgcc*`.

**Evidence / 证据**:
- `.github/workflows/release-riscv64.yml`
- `README-RISCV64.md`

### Entry 38 — Close RV64 Native Toolchain Panic Path and Enforce Blocking CI Gate (2026-02-20) / 修复 RV64 native toolchain panic 路径并切换为阻断式 CI 门禁
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- Guest native toolchain lane reproduced VM panic while running:
  - `printf '.text ...' | as -o /dev/null`
  - `printf ... | cc -pipe -x c - -c -o /dev/null`
- Panic signature:
  `rv64: VM pagefault ...` + `kernel panic: pagefault in VM`.

**Root cause / 根因**:
- In `minix/servers/vm/alloc.c`, `alloc_pages()` used page-index variables as
  `phys_bytes` (64-bit on RV64) while `NO_MEM` is a 32-bit click sentinel
  (`0xFFFFFFFE`).
- On RV64, failed `findbit()` results could be sign-extended and bypass
  `mem == NO_MEM` checks, then flow into bitmap access with invalid page index.

**Fix / 修复**:
1. `minix/servers/vm/alloc.c`
   - changed `alloc_pages` return type and page-index locals from
     `phys_bytes` to `phys_clicks`;
   - cast `findbit()` return values to `phys_clicks` before compare/use.
2. `minix/tests/riscv64/native_toolchain_gate.sh`
   - fixed shell exit-code handling so probe failures return nonzero reliably.
3. CI workflows
   - `.github/workflows/release-riscv64.yml`
   - `.github/workflows/nightly-riscv64.yml`
   changed native toolchain lane from non-blocking to blocking.

**Build / 构建命令**:
- `obj.intrgcc/tooldir.../bin/nbmake-evbriscv64 -C minix/servers/vm ACTIVE_CC=gcc ACTIVE_CPP=gcc AVAILABLE_COMPILER=gcc dependall`
- `obj.intrgcc/tooldir.../bin/nbmake-evbriscv64 -C minix/servers/vm ACTIVE_CC=gcc ACTIVE_CPP=gcc AVAILABLE_COMPILER=gcc DESTDIR=$PWD/obj.intrgcc/destdir.evbriscv64 install`
- `TMPDIR=$PWD/.ci-artifact-test/tmphost minix/releasetools/riscv64/mkdisk.sh -d obj.intrgcc -o $PWD/.ci-artifact-test/minix-native-gcc-test-fixed.img -s 1024 -u 768 -U`

**Validation / 验证**:
- `native_toolchain_gate.sh` on fresh native image:
  - passes `native_as_stdin` and `native_hello_build`;
  - final result: `[native-gate] PASS`, `rc=0`.
- Workflow-equivalent interactive smoke on same image:
  - shell prompt -> `neofetch` -> shutdown chain all pass.
- Negative-path check (dirty old image) now returns nonzero (`rc=2`), confirming
  gate failure is no longer misreported as success.

**Evidence / 证据**:
- `minix/servers/vm/alloc.c`
- `minix/tests/riscv64/native_toolchain_gate.sh`
- `.github/workflows/release-riscv64.yml`
- `.github/workflows/nightly-riscv64.yml`
- `.ci-artifact-test/native-toolchain-gate-fixed-image.log`
- `.ci-artifact-test/qemu-neofetch-shutdown-fixed.log`

### Entry 39 — Start Native Toolchain Stage with Automated Guest Gate (2026-02-19) / 启动 native 工具链阶段并接入来宾自动门禁
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Start native-toolchain bring-up with executable acceptance, not doc-only planning.
- 以可执行门禁方式启动 native toolchain 阶段，避免仅停留在文字方案。

**Code/Script changes / 代码与脚本改动**:
1. Extended runtime probe:
   - `minix/tests/riscv64/qemu_runtime_probe.py`
   - Added:
     - `--cmd NAME=COMMAND` (repeatable custom checks)
     - `--only-custom-cmds` (optional)
2. Added new native gate script:
   - `minix/tests/riscv64/native_toolchain_gate.sh`
   - Verifies in-guest:
     - tool commands: `as/ld/ar/ranlib`
     - native compiler detection: `cc/gcc/clang`
     - compile + run `hello.c` with output marker `NATIVE_TOOLCHAIN_OK`
   - Exit contract: `0=pass`, `1=fail`, `2=skip`.
3. Updated test runner entrypoint:
   - `minix/tests/riscv64/run_tests.sh`
   - Added top-level target `native`.
   - `all` now also executes native gate.
   - Default profile detection now prefers `obj.intrgcc` for kernel/tooldir/destdir,
     then falls back to legacy `obj`.
4. Added native build helper:
   - `minix/tests/riscv64/native_toolchain_build.sh`
   - Captures native-oriented build flags (`MKGCC=yes`, `MKGCCCMDS=yes`) with
     `obj.intrgcc` default profile and optional `--with-tools`.

**Documentation updates / 文档更新**:
1. Added dedicated guide:
   - `docs/RISCV64_NATIVE_TOOLCHAIN_GUIDE.md`
2. Updated:
   - `README-RISCV64.md` (native section + commands + references)
   - `RISC64-STATUS.md` (status and priorities include Stage N1/N2 native work)

**Validation commands run / 已执行验证命令**:
```bash
bash -n minix/tests/riscv64/native_toolchain_gate.sh
python3 -m py_compile minix/tests/riscv64/qemu_runtime_probe.py
bash -n minix/tests/riscv64/run_tests.sh
minix/tests/riscv64/native_toolchain_gate.sh --help
minix/tests/riscv64/native_toolchain_build.sh --help
python3 minix/tests/riscv64/qemu_runtime_probe.py --help
minix/tests/riscv64/run_tests.sh native
```

**Observed result / 观察结果**:
- All syntax/help checks pass.
- `run_tests.sh native` returns `SKIP` in current image because
  `obj.intrgcc/destdir.evbriscv64/usr/bin` does not yet contain
  `cc/gcc/clang`, which matches Stage N1/N2 expected pre-closure state.

**Evidence / 证据**:
- `minix/tests/riscv64/qemu_runtime_probe.py`
- `minix/tests/riscv64/native_toolchain_gate.sh`
- `minix/tests/riscv64/native_toolchain_build.sh`
- `minix/tests/riscv64/run_tests.sh`
- `docs/RISCV64_NATIVE_TOOLCHAIN_GUIDE.md`
- `README-RISCV64.md`
- `RISC64-STATUS.md`

### Entry 33 — Fix Missing `-lvirtio_mmio` in CI Distribution Link (2026-02-18) / 修复 CI distribution 链接缺失 `-lvirtio_mmio`
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- CI run (`22138682974`) failed in `Build distribution` while linking
  `minix/drivers/net/virtio_net_mmio`:
  - `ld: cannot find -lvirtio_mmio`

**Root cause / 根因**:
- `virtio_net_mmio` depends on `-lvirtio_mmio`, but `minix/lib/Makefile` did
  not include `libvirtio_mmio` in the `riscv64/riscv` `SUBDIR` list.
- As a result, the library was not guaranteed to be built/installed into
  `destdir/usr/lib` before the driver link step.

**Fix / 修复**:
1. Updated `minix/lib/Makefile`:
   - Added:
     - `.if (${MACHINE_ARCH} == "riscv64" || ${MACHINE_ARCH} == "riscv")`
     - `SUBDIR+= libvirtio_mmio`
     - `.endif`

**Validation / 验证**:
- Local targeted build confirms sequence and link now succeed:
  1. `minix/lib/libvirtio_mmio` installs
     `destdir.evbriscv64/usr/lib/libvirtio_mmio.a`
  2. `minix/drivers/net/virtio_net_mmio` static link succeeds with
     `-lvirtio_mmio`.

**Evidence / 证据**:
- `minix/lib/Makefile`
- `minix/lib/libvirtio_mmio/Makefile`
- `minix/drivers/net/virtio_net_mmio/Makefile`

### Entry 34 — Wire `libvirtio_mmio` Into Top-Level lib Build Chain (2026-02-18) / 将 `libvirtio_mmio` 接入顶层 lib 构建链
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- After Entry 33 changes, next CI run (`22139502194`) still failed at the same
  point:
  - `ld: cannot find -lvirtio_mmio` while linking `virtio_net_mmio`.

**Refined root cause / 细化根因**:
- `distribution` library phase is driven by top-level `lib/Makefile`.
- We had added `libvirtio_mmio` only in `minix/lib/Makefile`, but not in
  `lib/Makefile` MINIX subdir chain. Therefore CI still did not install
  `libvirtio_mmio` into `destdir/usr/lib` before driver link.

**Fix / 修复**:
1. Updated `lib/Makefile`:
   - Added RISC-V gated subdir:
     - `.if (${MACHINE_ARCH} == "riscv64" || ${MACHINE_ARCH} == "riscv")`
     - `SUBDIR+= ../minix/lib/libvirtio_mmio`
     - `.endif`
2. Kept Entry 33 change in `minix/lib/Makefile` for local MINIX-only build path
   consistency.

**Validation status / 验证状态**:
- New commit queued for next CI tag run; success criterion is clearing
  `virtio_net_mmio` link step without `cannot find -lvirtio_mmio`.

**Evidence / 证据**:
- `lib/Makefile`
- `minix/lib/Makefile`
- `README-RISCV64.md`

### Entry 32 — Fix RISC-V `ld.elf_so` Reloc Macro Build Break in CI (2026-02-18) / 修复 CI 中 RISC-V `ld.elf_so` 重定位宏编译失败
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- New CI run (`22138059197`) passed `Build tools` and failed in
  `Build distribution` at `libexec/ld.elf_so/arch/riscv/mdreloc.c`:
  - `warning: implicit declaration of function 'R_TYPESZ'`
  - `error: 'ADDR' undeclared`
  - `error: 'TLS_DTPMOD' undeclared`
  - `error: 'TLS_DTPREL' undeclared`
  - `error: 'TLS_DTV_OFFSET' undeclared`

**Root cause / 根因**:
- RISC-V path used `R_TYPESZ(ADDR/TLS_*)` style relocation cases, but CI build
  environment did not provide those macro mappings on this path, causing
  unresolved macro tokens in `mdreloc.c`.

**Fix / 修复**:
1. Updated `libexec/ld.elf_so/arch/riscv/mdreloc.c`:
   - Added `TLS_DTV_OFFSET` fallback:
     `#ifndef TLS_DTV_OFFSET #define TLS_DTV_OFFSET 0 #endif`
   - Replaced `R_TYPESZ(...)` cases with explicit `ELFSIZE`-based mappings:
     - `R_TYPE_ADDR` -> `R_TYPE(64/32)`
     - `R_TYPE_TLS_DTPMOD` -> `R_TYPE(TLS_DTPMOD64/32)`
     - `R_TYPE_TLS_DTPREL` -> `R_TYPE(TLS_DTPREL64/32)`
2. Added compatibility aliases in:
   - `sys/arch/riscv/include/elf_machdep.h`
   to keep `ADDR32/ADDR64` and `R_TYPESZ(name)` available for RISC-V code that
   still uses that naming model.

**Validation / 验证**:
- Local targeted compile of `mdreloc.c` with the same flags/profile succeeds:
  `mdreloc compile OK`.

**Evidence / 证据**:
- `libexec/ld.elf_so/arch/riscv/mdreloc.c`
- `sys/arch/riscv/include/elf_machdep.h`
- `README-RISCV64.md`

### Entry 30 — Fix `libgcc_s.so` Undefined `mprotect` in CI Distribution (2026-02-18) / 修复 CI distribution 中 `libgcc_s.so` 的 `mprotect` 未定义
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- New CI run (`v4.0.0-riscv64-ci-20260218185915`) progressed through `Build tools`,
  then failed in `Build distribution` when linking `external/mit/lua/usr.bin/lua`:
  - `.../usr/lib/libgcc_s.so: undefined reference to 'mprotect'`

**Root cause / 根因**:
- RISC-V `libgcc` arch defs selected
  `${GNUHOSTDIST}/libgcc/enable-execute-stack-mprotect.c` for
  `enable-execute-stack.c`.
- On MINIX target side in this lane, that pulls an unresolved `mprotect`
  reference into `libgcc_s.so`, which surfaces during dynamic link of `lua`.

**Fix / 修复**:
1. Updated:
   - `external/gpl3/gcc/lib/libgcc/arch/riscv64/defs.mk`
   - `external/gpl3/gcc/lib/libgcc/arch/riscv32/defs.mk`
2. Switched `G_CONFIGLINKS` mapping from:
   - `enable-execute-stack-mprotect.c`
   to:
   - `enable-execute-stack-empty.c`
3. Kept remaining `G_CONFIGLINKS` items intact to avoid unrelated libgcc ABI
   drift.

**Validation status / 验证状态**:
- Patch committed for next CI retrigger; success criterion is passing
  `Build distribution` without `libgcc_s.so: undefined reference to 'mprotect'`.

**Evidence / 证据**:
- `.github/workflows/release-riscv64.yml`
- `external/gpl3/gcc/lib/libgcc/arch/riscv64/defs.mk`
- `external/gpl3/gcc/lib/libgcc/arch/riscv32/defs.mk`

### Entry 31 — Add Runner Disk-Reclaim Step for GitHub Actions (2026-02-18) / 为 GitHub Actions 增加 runner 磁盘回收步骤
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Motivation / 动机**:
- The release workflow performs full `tools -> distribution`, and hosted runner
  disk pressure can become a blocker before build completion.
- 发布流水线执行完整 `tools -> distribution`，GitHub hosted runner 容量紧张时
  容易在中后期失败。

**Change / 改动**:
1. Updated `/.github/workflows/release-riscv64.yml`:
   - Added step `Reclaim runner disk space` right after `Checkout`.
2. Reclaim actions include:
   - print `df -h` before/after cleanup,
   - remove preinstalled heavy directories:
     `/usr/share/dotnet`, `/usr/local/lib/android`, `/opt/ghc`,
     `/opt/hostedtoolcache/CodeQL`,
   - disable/remove swap file (`/swapfile`),
   - prune docker leftovers (`docker system prune -af` when available),
   - clear apt cache and list files.

**Validation status / 验证状态**:
- Workflow updated; next tag-triggered run should confirm whether disk margin is
  sufficient through the full build path.

**Evidence / 证据**:
- `.github/workflows/release-riscv64.yml`
- `README-RISCV64.md`

### Entry 35 — Add Release QEMU Interactive Gate (neofetch + shutdown) (2026-02-19) / 发布流水线增加 QEMU 交互门禁（neofetch + 关机链）
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Require a real boot-and-interact check before publishing release assets.
- 在发布前强制执行“可启动 + 可交互 + 可关机”的最小可用验证。

**Change / 改动**:
1. Updated `/.github/workflows/release-riscv64.yml`:
   - Added `QEMU interactive smoke test (neofetch + shutdown chain)` step
     after artifact packaging and before release publish.
2. Smoke script behavior:
   - Boot image via `qemu-system-riscv64` + S-mode U-Boot chain.
   - Wait for `#` prompt.
   - Run `neofetch`, assert `Donz Fetch` and `OS: Minix Cat ...`.
   - Run shutdown fallback chain:
     `/sbin/shutdown -p now || /sbin/halt -p || /sbin/poweroff || /sbin/reboot -p || /sbin/reboot`.
3. Added `Upload QEMU smoke log` with `if: always()`:
   - log path: `/tmp/qemu-neofetch-smoke.log`
   - artifact name format:
     `riscv64-qemu-smoke-log-<tag>-<shortsha>`

**Validation / 验证**:
- Tag-triggered release flow proceeds only when the interactive gate passes.
- Smoke log artifact is kept for both pass/fail runs to support triage.

**Evidence / 证据**:
- `.github/workflows/release-riscv64.yml`
- `README-RISCV64.md`

### Entry 36 — Nightly Tag Format Finalization + Publish 5 Assets to Release (2026-02-19) / nightly tag 规则定稿 + 5 件产物发布到 Release
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Make nightly output deterministic and externally consumable from GitHub Release.
- 统一 nightly 命名、标签与资产分发路径，避免“只在 Actions artifact 可见”的歧义。

**Change / 改动**:
1. Added/updated nightly workflow:
   - `/.github/workflows/nightly-riscv64.yml`
2. Finalized nightly tag format:
   - `nightly-master-riscv64-YYYYMMDD-<shortsha>`
3. Finalized nightly artifact base naming:
   - `minix-cat-nightly-YYYYMMDD-<shortsha>-riscv64`
4. Nightly now publishes all five standard assets to two channels:
   - Actions artifact upload
   - GitHub Release (prerelease) via `softprops/action-gh-release@v2`
5. Kept QEMU interactive gate and smoke-log upload in nightly lane
   (same contract as release lane).

**Validation / 验证**:
- Successful nightly run `22165196780` uploaded 5 files (confirmed in step logs).
- Canceled run `22165112159` shows `0 artifact`; treated as non-reference run.

**Evidence / 证据**:
- `.github/workflows/nightly-riscv64.yml`
- `https://github.com/AvrovaDonz2026/minix/actions/runs/22165196780`
- `https://github.com/AvrovaDonz2026/minix/actions/runs/22165112159`

### Entry 24 — Enforce Commit-Hash Artifact Naming in Release Pipeline (2026-02-18) / 发布流水线产物命名强制包含提交 hash
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Enforce a stable artifact naming standard where every release asset embeds
  the built commit short hash.

**CI updates / CI 更新**:
1. Updated `/.github/workflows/release-riscv64.yml`
   - Added naming base:
     `minix-cat-<tag>-<shortsha>-riscv64`.
   - `shortsha` source:
     `git rev-parse --short=12 $GITHUB_SHA`.
   - Release assets now include:
     - `minix-cat-<tag>-<shortsha>-riscv64.img`
     - `minix-cat-<tag>-<shortsha>-riscv64.img.gz`
     - `minix-cat-<tag>-<shortsha>-riscv64.elf`
     - `minix-cat-<tag>-<shortsha>-riscv64-sysroot.tar.gz`
     - `SHA256SUMS.txt`
2. Updated `README-RISCV64.md`
   - Documented the naming convention and release asset list.
   - Bumped document version metadata (`1.14`).

**Build/test status / 构建测试状态**:
- This entry updates CI naming/packaging logic and docs only.
- 本条目仅更新 CI 命名/打包逻辑与文档，未新增本地完整构建回归。

**Evidence / 证据**:
- `.github/workflows/release-riscv64.yml`
- `README-RISCV64.md`

### Entry 25 — Fix CI `configure-gas` Failure on `riscv-ucb-minix` (2026-02-18) / 修复 CI 在 `riscv-ucb-minix` 上的 `configure-gas` 失败
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- GitHub Actions release workflow failed during `Build tools` at `tools/binutils`.
- Error:
  `configure: error: GAS does not know what format to use for target riscv-ucb-minix`.

**Root cause / 根因**:
- CI uses a fresh `external/gpl3/binutils/dist` prepared from
  `binutils-2.23.2.tar.bz2` plus `external/gpl3/binutils/patches/*`.
- Existing patch set had `riscv` entries for `linux/netbsd`, but no
  `riscv*-*-minix*` mapping in `gas/configure.tgt`.
- As a result, `fmt` remained unset for canonical target `riscv-ucb-minix`.

**Fix / 修复**:
1. Added patch:
   `external/gpl3/binutils/patches/0012-riscv-gas-minix-target-format.patch`
2. Patch content adds:
   - `riscv*eb-*-minix*) fmt=elf endian=big em=minix ;;`
   - `riscv*-*-minix*)   fmt=elf endian=little em=minix ;;`

**Validation / 验证**:
- Reproduced failure in a clean temp tree:
  unpack tarball -> apply patches -> run `gas/configure --target=riscv64-elf32-minix`.
- After adding patch `0012`, the same clean-tree configure run completes and
  creates `config.status` + `Makefile` without the format error.

**Evidence / 证据**:
- `external/gpl3/binutils/patches/0012-riscv-gas-minix-target-format.patch`

### Entry 26 — Fix CI `configure-gcc` Unsupported Target for `riscv-ucb-minix` (2026-02-18) / 修复 CI `configure-gcc` 对 `riscv-ucb-minix` 目标不支持
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- After fixing binutils/gas, release workflow moved forward and failed in
  `tools/gcc` (`configure-gcc`) with:
  `*** Configuration riscv-ucb-minix not supported`.

**Root cause / 根因**:
- CI builds from fresh `external/gpl3/gcc/dist` generated by
  `gcc-4.8.5.tar.bz2` + `external/gpl3/gcc/patches/*`.
- Existing patch set did not include `riscv*-*-minix*` case in
  `gcc/config.gcc` for this fresh-dist path.
- Local ignored `dist/` tree contained the case, but CI never consumes local
  ignored contents.

**Fix / 修复**:
1. Added patch:
   `external/gpl3/gcc/patches/0005-riscv-minix-config.patch`
2. Patch inserts `riscv*-*-minix*` target stanza in `gcc/config.gcc`:
   - `tm_file="... riscv/elf.h minix-spec.h minix.h"`
   - `tmake_file="${tmake_file} riscv/t-elf t-minix"`
   - `gnu_ld=yes`, `gas=yes`, `gcc_cv_initfini_array=yes`
   - `default_use_cxa_atexit=yes`

**Validation / 验证**:
- Reproduced in clean temp tree (tarball + old patches): direct
  `gcc/configure --target=riscv64-elf32-minix` emits
  `*** Configuration riscv-ucb-minix not supported`.
- Re-ran with new patch included: same configure path no longer emits unsupported
  target error.

**Evidence / 证据**:
- `external/gpl3/gcc/patches/0005-riscv-minix-config.patch`

### Entry 27 — Mitigate CI `as` Abort in `lib/csu` on Ubuntu 24 (2026-02-18) / 规避 Ubuntu 24 上 `lib/csu` 阶段 `as` 异常中止
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- Release workflow progressed into `distribution` and failed at `lib/csu`:
  - `*** buffer overflow detected ***: terminated`
  - `riscv64-elf32-minix-gcc: internal compiler error: Aborted (program as)`
- Failures were observed on `crtend.S`, `crtn.S`, `crt0.S` assembly paths.

**Root cause hypothesis / 根因判断**:
- Freshly built legacy toolchain binaries (`as` from old binutils branch) run on
  modern Ubuntu 24 host userspace and can trip fortify/stack-protector runtime
  checks, causing host-side abort before target object emission.

**Fix / 修复**:
1. Updated CI workflow:
   `/.github/workflows/release-riscv64.yml`
2. Added host hardening-off flags in both `Build tools` and
   `Build distribution` steps:
   - `-U_FORTIFY_SOURCE`
   - `-D_FORTIFY_SOURCE=0`
   - `-fno-stack-protector`
3. Applied via:
   - `HOST_CFLAGS="-O -fcommon ${HARDENING_OFF}"`
   - `HOST_CXXFLAGS="-O ${HARDENING_OFF}"`

**Validation status / 验证状态**:
- Workflow patch committed and retriggered by new CI tag run.
- Runtime confirmation depends on completion of the new GitHub Actions run.

**Evidence / 证据**:
- `.github/workflows/release-riscv64.yml`

### Entry 29 — Fix CI Missing `-lgcc_s` in Dynamic Link Stage (2026-02-18) / 修复 CI 动态链接阶段缺失 `-lgcc_s`
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- Release workflow moved past earlier toolchain gates, then failed in
  `distribution` when linking dynamic targets (for example `lua`) with:
  - `ld: cannot find -lgcc_s`

**Root cause / 根因**:
- Workflow previously forced PIC-related overrides in distribution step:
  - `-V MKPIC=no`
  - `-V MKPICLIB=no`
  - `-V MKPICINSTALL=no`
- Dynamic link products depend on shared GCC runtime (`libgcc_s`). Forcing the
  above flags prevents expected PIC/shared runtime path and can drop `libgcc_s`
  from target-side availability.

**Fix / 修复**:
1. Updated `/.github/workflows/release-riscv64.yml` (distribution step):
   - Removed:
     - `-V MKPIC=no`
     - `-V MKPICLIB=no`
     - `-V MKPICINSTALL=no`
2. Kept the already-added `MKGCC` runtime toggles:
   - `-V MKGCC=yes`
   - `-V MKGCCCMDS=no`
   to preserve `libgcc` runtime generation while allowing PIC defaults.

**Validation status / 验证状态**:
- Workflow patch committed for retrigger; confirmation depends on the next
  GitHub Actions run completing `distribution` without `-lgcc_s` failure.

**Evidence / 证据**:
- `.github/workflows/release-riscv64.yml`
- `README-RISCV64.md`

### Entry 40 — CI Native Payload Closure + Staged Full-Suite Blocking (2026-02-20) / CI native payload 闭环 + 分阶段全量阻断测试
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Ensure every release/nightly artifact contains a complete native toolchain
  payload (not only tool presence, but usable link/run chain).
- Upgrade CI test gate from smoke-only checks to staged blocking full-suite
  checks (`build -> user -> native -> kernel -> gate`).

**Change / 改动**:
1. Updated release/nightly workflows:
   - `/.github/workflows/release-riscv64.yml`
   - `/.github/workflows/nightly-riscv64.yml`
2. Added native payload precheck in both workflows (blocking):
   - binaries: `cc gcc c++ g++ cpp as ld ar ranlib nm objcopy objdump readelf strip`
   - libraries: `usr/lib/libgcc.a`, `usr/lib/libgcc_eh.a`, `usr/lib/libstdc++.a`
   - headers: `usr/include/stdio.h`, `usr/include/g++/bits/c++config.h`
3. Upgraded full-suite stage to explicit blocking sequence in CI:
   - `build -> user -> native -> kernel -> gate(timeout 900s)`
   - env: `SMOKE_DD_UNSAFE=1`, `SMOKE_ROUNDS=1`
4. Upgraded native runtime gate script:
   - `minix/tests/riscv64/native_toolchain_gate.sh`
   - added link/run-level checks in single boot:
     `native_ar_ranlib`, `native_hello_link_run`, `native_cxx_link_run`
     (alongside existing `native_as_stdin` / compile checks)
5. Updated manual documentation:
   - `README-RISCV64.md` version bump to `1.28`, with workflow behavior,
     artifact naming, and staged gate updates.

**Validation / 验证**:
- Local runtime gate logs show full native chain PASS:
  - `/tmp/native-gate-full-linkrun.log`
  - `/tmp/run-tests-native.log`
- Local staged full-suite path validated with:
  - `/tmp/riscv64-full-suite-local.log`
- GitHub Actions release run `22218664841` completed `success` with the
  updated blocking chain enabled.

**Evidence / 证据**:
- `.github/workflows/release-riscv64.yml`
- `.github/workflows/nightly-riscv64.yml`
- `minix/tests/riscv64/native_toolchain_gate.sh`
- `README-RISCV64.md`
- `https://github.com/AvrovaDonz2026/minix/actions/runs/22218664841`

### Entry 41 — Enforce Per-Command Native Toolchain Usability Gate (2026-02-21) / 强化 native 工具链逐命令可用性门禁
**Workspace / 工作区**: `/home/donz/minix`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Goal / 目标**:
- Tighten CI so native GCC toolchain is not only present, but functionally usable.
- 将 CI 从“命令存在/基础编译”升级为“逐命令可执行 + 真实产物验证 + 可运行产物验证”。

**Change / 改动**:
1. Upgraded `minix/tests/riscv64/native_toolchain_gate.sh` command matrix.
2. Added strict per-command runtime checks (single boot, blocking):
   - compiler/frontends: `cc/gcc/c++/g++/cpp(gcpp)`
   - binutils core: `as/ld/ar/ranlib/nm/objcopy/objdump/readelf/strip`
3. Added artifact-level checks around those commands:
   - compile C objects via `cc/gcc`
   - preprocess via `cpp/gcpp`
   - assemble/link-relocatable/archive (`as/ld/ar/ranlib`)
   - inspect/transform objects (`nm/objcopy/objdump/readelf/strip`)
   - static C/C++ link-and-run executables in guest
4. Hardened `/usr` preparation in native gate for CI variance:
   - if `/usr` already writable, keep it
   - else attempt common ext2 nodes before fallback mount path

**Validation / 验证**:
- Script syntax: `bash -n minix/tests/riscv64/native_toolchain_gate.sh` PASS.
- `--help` path sanity check PASS.
- Prior CI failure modes observed and addressed in sequence:
  - `22249826170`: payload precheck false-negative (`usr/bin/cpp`)
  - `22250528261`: native gate mount prep (`prepare_usr_mount` rc=1)

**Evidence / 证据**:
- `minix/tests/riscv64/native_toolchain_gate.sh`
- `README-RISCV64.md`
- `https://github.com/AvrovaDonz2026/minix/actions/runs/22249826170`
- `https://github.com/AvrovaDonz2026/minix/actions/runs/22250528261`

### Entry 35 — Fix virtio_net_mmio RS Policy Drift and Network Smoke (2026-08-21) / 修复 virtio_net_mmio 策略漂移并补网络冒烟
**Workspace / 工作区**: `/workspace`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- Disk/distribution profiles install `/etc/system.conf.d/virtio_net_mmio`
  from `virtio_net_mmio.conf`, which overrode RISC-V `system.conf` and
  omitted `PRIVCTL` plus the VirtIO IRQ/MMIO window.
- Without `SYS_PRIVCTL`, `virtio_mmio_allow_mem()` cannot add the MMIO
  range, `vm_map_phys` fails, and `vio0` never appears.
- QEMU `-n` always bound host port 2222, which breaks shared CI hosts.
- `run_tests.sh kernel` had no network datapath check.

**Fix / 修复**:
1. Expand `minix/drivers/net/virtio_net_mmio/virtio_net_mmio.conf` to the
   full RISC-V policy (`uid 0`, `PRIVCTL`, IRQs 1-8, IPC including `lwip`,
   MMIO `0x10001000:0x10008000`).
2. Widen the same MMIO window in `minix/releasetools/riscv64/system.conf`.
3. Program modern virtqueue DESC/AVAIL/USED from `vring_init` pointers;
   initialize `irq_hook` to `-1`; report link via `VIRTIO_NET_F_STATUS`;
   print `virtio-net-mmio: initialized`.
4. QEMU `-n` adds `ipv6=on` and MAC `52:54:00:12:34:56`, and honors
   `NET_HOSTFWD=none`.
5. Add `minix/tests/riscv64/qemu_net_smoke.py` and wire it into
   `run_tests.sh kernel`.

**Commands / 命令**:
```bash
NBMAKE=obj.intrgcc/tooldir.*/bin/nbmake-evbriscv64
"$NBMAKE" -C minix/lib/libvirtio_mmio all install
"$NBMAKE" -C minix/drivers/net/virtio_net_mmio all install
"$NBMAKE" -C minix/drivers/storage/ramdisk RAMDISK_TESTS=1 image
"$NBMAKE" -C minix/drivers/storage/memory RAMDISK_TESTS=1 all install
NET_HOSTFWD=none python3 minix/tests/riscv64/qemu_net_smoke.py \
  --qemu-script minix/scripts/qemu-riscv64.sh \
  --kernel obj.intrgcc/minix/kernel/kernel \
  --destdir obj.intrgcc/destdir.evbriscv64
```

**Evidence / 证据**:
- `issue.md` `#39`
- `minix/drivers/net/virtio_net_mmio/virtio_net_mmio.conf`
- `minix/lib/libvirtio_mmio/virtio_mmio.c`
- `minix/tests/riscv64/qemu_net_smoke.py`

### Entry 36 — Per-Commit Packaging CI Gates + Reproducibility Record (2026-08-21) / 每次提交打包 CI 门禁 + 可复现性记录
**Workspace / 工作区**: `/workspace`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Change / 变更**:
- `release-riscv64.yml` 与 `nightly-riscv64.yml` 同为 OS 打包 CI；二者现均在每次提交时
  运行（任意分支 `push` + `pull_request`），审查 OS 完整性与打包可复现性。
- Nightly 保留 UTC `20 18 * * *` cron 与 `workflow_dispatch`；`tags-ignore` 避免与
  release-on-tag 重复。
- Release 仍仅在 `v*` tag push 与 `workflow_dispatch` 时发布 GitHub Release。
- 发布门禁：
  - nightly tag / GitHub Release 发布：仅 `schedule`、`workflow_dispatch`、或 `master`
    `push`
  - release 发布：仅 `v*` tag 或 `workflow_dispatch`
  - feature 分支 / `pull_request` run 为审查 run：上传 workflow artifacts，不发布
    GitHub Release / nightly tag
- 两条流水线均从 git 提交时间戳固定 `SOURCE_DATE_EPOCH`，压缩使用 `gzip -n`，并生成
  `BUILDINFO.txt` 与 `SHA256SUMS` 作为可复现性记录。
- Payload 完整性预检新增 destdir 必含项：`virtio_net_mmio`、`lwip`、`ifconfig`、
  `ping`、`ping6`（与 native 工具链预检并存）。
- 两条流水线仍执行 `tools -> distribution`、`mkdisk`、QEMU `neofetch`/shutdown smoke，
  以及阻断式完整测试套件（`build -> user -> native -> kernel -> gate`）。

**Evidence / 证据**:
- `.github/workflows/release-riscv64.yml`
- `.github/workflows/nightly-riscv64.yml`
- `README-RISCV64.md`
- `README.md`
- `RISC64-STATUS.md`

### Entry 37 — Return Packaging CI to GitHub-Hosted Runners (2026-08-21) / 打包 CI 改回 GitHub-hosted runner
**Workspace / 工作区**: `/workspace`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Change / 变更**:
- Self-hosted runner 已下线。`nightly-riscv64.yml`、`release-riscv64.yml`、
  `gcc13-riscv64-spike.yml` 改回 `runs-on: ubuntu-24.04`。
- 恢复 hosted 路径：`Reclaim runner disk space` + `apt` 安装宿主依赖
  （打包 CI 含 `qemu-system-misc` / `u-boot-qemu` / `u-boot-tools`）。
- 每次提交仍跑 nightly + release 审查；GitHub Release / nightly tag 发布门禁不变。

**Evidence / 证据**:
- `.github/workflows/nightly-riscv64.yml`
- `.github/workflows/release-riscv64.yml`
- `.github/workflows/gcc13-riscv64-spike.yml`
- `README-RISCV64.md`

### Entry 38 — Align virtio-net MMIO with FreeBSD if_vtnet (2026-08-21) / 按 FreeBSD if_vtnet 对齐 virtio-net MMIO
**Workspace / 工作区**: `/workspace`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- QEMU virtio-mmio is VirtIO 1.0 (`VIRTIO_F_VERSION_1`). The on-wire
  `virtio_net_hdr` is 12 bytes (`num_buffers`). The driver posted a
  10-byte header descriptor, so RX ethernet frames were shifted by two
  bytes and `ping 10.0.2.2` showed TX with 0 RX.
- Feature bits for CSUM / GUEST_CSUM / CTRL_RX were ignored
  (`TODO: Features are pretty much ignored`).
- RX and TX shared one 64-packet pool, so TX could starve RX.

**Fix / 修复** (userspace, FreeBSD `if_vtnet` model; not a kernel stack port):
1. Select 12-byte modern header when MMIO version >= 2.
2. Dedicated RX/TX rings (32+32).
3. Negotiate `VIRTIO_NET_F_CSUM`, `GUEST_CSUM`, `CTRL_RX`; advertise
   `NDEV_CAP_CS_TCP/UDP_{TX,RX}`; TX installs pseudo-header + `NEEDS_CSUM`;
   RX completes `NEEDS_CSUM` so lwIP can verify.
4. CTRL_VQ RX filter (promisc / allmulti / MAC table).
5. Config ISR reports link via `netdriver_link()`.
6. `qemu_net_smoke.py` requires `virtio-net-mmio: hdr 12`.
7. Host compile test `test_virtio_net_hdr.c` locks 10/12-byte sizes.

**Commands / 命令**:
```bash
NBMAKE=obj.intrgcc/tooldir.*/bin/nbmake-evbriscv64
export MKPCI=no
export MAKEOBJDIR='${.CURDIR:C,^/workspace,/workspace/obj.intrgcc,:C,^/home/donz/minix,/workspace/obj.intrgcc,}'
"$NBMAKE" -C minix/lib/libvirtio_mmio all install
"$NBMAKE" -C minix/drivers/net/virtio_net_mmio all install
"$NBMAKE" -C minix/drivers/storage/ramdisk RAMDISK_TESTS=1 image
"$NBMAKE" -C minix/drivers/storage/memory RAMDISK_TESTS=1 all install
NET_HOSTFWD=none python3 minix/tests/riscv64/qemu_net_smoke.py \
  --qemu-script minix/scripts/qemu-riscv64.sh \
  --kernel obj.intrgcc/minix/kernel/kernel \
  --destdir obj.intrgcc/destdir.evbriscv64
```

**Evidence / 证据**:
- `issue.md` `#40`
- `minix/drivers/net/virtio_net_mmio/virtio_net_mmio.c`
- `minix/lib/libvirtio_mmio/virtio_mmio.c`
- `minix/tests/riscv64/qemu_net_smoke.py`
- `minix/tests/riscv64/test_virtio_net_hdr.c`

### Entry 39 — Unblock GitHub-hosted packaging CI (2026-08-21) / 修复 GitHub-hosted 打包 CI
**Workspace / 工作区**: `/workspace`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- Nightly/release on `ubuntu-24.04` failed in `Build tools`:
  `bfd.h: No such file or directory` while compiling `elfxx-riscv.c`.
  Tracked `obj.intrgcc/tools` stamps plus a `tooldir.Linux-6.12.63+deb13`
  wrapper that still points at `/home/donz/minix`.
- Full suite used `if: always()`, so kernel tests still ran after tools
  failed. `nbmake-evbriscv64` exec'd the missing Donz `nbmake`.
- `qemu_net_smoke.py` treated OpenSBI's `\ ` ASCII art as a `#/$` prompt
  and failed with `virtio-net-mmio: initialized not found` before boot.

**Fix / 修复**:
1. Wipe `${OBJDIR}/tooldir.*` and `${OBJDIR}/tools` before `build.sh tools`.
2. Export the runner-built `TOOLDIR` via `GITHUB_ENV`.
3. Run the full suite only after a successful tools/distribution/package
   path (`if: success()`). Log uploads stay `always()`.
4. `run_tests.sh` prefers a tooldir with a real `nbmake` binary, rewrites
   wrappers whose `NETBSDSRCDIR` is missing, and picks the newest tree.
5. Net smoke waits for `login:` or `(?:^|\\n)# `; both smoke scripts
   treat PTY `EIO` as QEMU exit.
6. After GNU binutils configure, generate `build/bfd/bfd.h` with host
   `make` before the parallel `all-binutils` so `elfxx-riscv.lo` cannot
   start without the header.
7. libstdc++ `includes` skips gcc13-only names (`compare`, `any`, ...)
   when `external/gpl3/gcc/dist` is the fetched gcc 4.8.5 snapshot.

**Evidence / 证据**:
- `issue.md` `#41`
- `.github/workflows/nightly-riscv64.yml`
- `.github/workflows/release-riscv64.yml`
- `minix/tests/riscv64/run_tests.sh`
- `minix/tests/riscv64/qemu_net_smoke.py`
- `minix/tests/riscv64/qemu_io_smoke.py`
- `tools/binutils/Makefile`
- `external/gpl3/gcc/lib/libstdc++-v3/include/Makefile`
- GitHub Actions runs `32476453612` / `32476453658` / `32478447982` / `32478447998`

### Entry 40 — Hosted distribution: params.opt and _copysignl (2026-08-21) / hosted distribution 缺 params.opt 与 _copysignl
**Workspace / 工作区**: `/workspace`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`  
**Commit / 提交**: `cb83b9402`

**Symptom / 现象**:
- Nightly `32479729555` tools succeeded (~4 min), then distribution failed
  with `don't know how to make .../gcc/dist/gcc/params.opt` while building
  `external/gpl3/gcc/usr.bin/backend`. riscv64 `defs.mk` is gcc 13.2.0
  mknative; packaging CI fetches gcc 4.8.5.
- Release `32479729556` tools succeeded (~6 min), then distribution failed
  linking `external/mit/lua/usr.bin/lua`:
  `libm.so: undefined reference to _copysignl`. RISC-V `s_copysign.S`
  replaces `s_copysign.c` (the alias) and `s_copysignl.c` stayed empty
  without `__HAVE_LONG_DOUBLE 128`.

**Fix / 修复**:
1. `Makefile.options` / libobjc: skip option files that do not exist in
   the fetched dist (`params.opt`).
2. `sys/arch/riscv/include/math.h`: `__HAVE_LONG_DOUBLE 128` so
   `s_copysignl.c` emits IEEE binary128 `_copysignl`.
3. `tools/binutils/Makefile`: configure and build with host GNU make so
   `stmp-bfd-h` is a real prerequisite of `elfxx-riscv.lo`; fail if
   `bfd.h` is still missing after generate.

**Evidence / 证据**:
- `issue.md` `#43` `#44`
- GitHub Actions runs `32479729555` (nightly) and `32479729556` (release)

### Entry 41 — Drop premature bfd.h check (2026-08-21) / 去掉过早的 bfd.h 检查
**Workspace / 工作区**: `/workspace`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`  
**Commit / 提交**: `417e7bd94` (failed)

**Symptom / 现象**:
- Nightly `32482801846` and release `32482801856` failed in `Build tools`
  right after top-level configure:
  `error: bfd Makefile missing after configure`.
- `.configure_done` only writes `build/Makefile`. The extra nbmake
  `bfd.h` prerequisite tested `build/bfd/Makefile` before GNU make
  `configure-bfd` ran.

**Fix / 修复**:
1. Remove the nbmake `build/bfd/bfd.h` prerequisite of `.build_done`.
2. `BUILD_COMMAND` is host GNU make `configure-bfd`, then GNU make
   `all-binutils all-gas all-ld` with a cleaned environment (`env -i`).

**Evidence / 证据**:
- `issue.md` `#45`
- `tools/binutils/Makefile`
- GitHub Actions runs `32482801846` (nightly) and `32482801856` (release)

### Entry 42 — Skip gcc13 gcov/common-target sources (2026-08-21) / 跳过 gcc13 的 gcov 与 common-target 源
**Workspace / 工作区**: `/workspace`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- After params.opt, native gcc `gcov` still lists `json.o` / `json.cc`
  (gcc 13) against the fetched gcc 4.8.5 dist. common-target lists
  `spellcheck.cc`, `selftest.cc`, `opt-suggestions.cc`.

**Fix / 修复**:
1. gcov: drop `json.o` when `json.cc` is missing; use `gcov.c` on 4.8.5.
2. common-target: keep a source only if the `.cc` or `.c` exists in dist.

**Evidence / 证据**:
- `issue.md` `#47`
- `external/gpl3/gcc/usr.bin/gcov/Makefile`
- `external/gpl3/gcc/usr.bin/common-target/Makefile`

### Entry 43 — FreeBSD-style mergeable RX and EVENT_IDX (2026-08-21) / 按 FreeBSD 做 mergeable RX 与 EVENT_IDX
**Workspace / 工作区**: `/workspace`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Change / 改动**:
1. Offer `VIRTIO_NET_F_MRG_RXBUF` and `VIRTIO_NET_F_GUEST_ANNOUNCE`.
2. Post one RX/TX buffer per slot with the virtio-net header at the
   start of the buffer; concatenate `num_buffers` used slots on RX.
3. Grow rings from 32+32 to 128+128.
4. Negotiate `VIRTIO_RING_F_EVENT_IDX` on virtio-mmio and suppress
   kicks with `vring_need_event`.
5. Net smoke requires `hdr 12`, `mrg on`, and `event_idx on`.

**Evidence / 证据**:
- `issue.md` `#46`
- `minix/drivers/net/virtio_net_mmio/virtio_net_mmio.c`
- `minix/lib/libvirtio_mmio/virtio_mmio.c`
- `minix/tests/riscv64/qemu_net_smoke.py`

### Entry 44 — 64-bit long double aliases and 256-slot if_vtnet (2026-08-21) / 64 位 long double alias 与 256 槽 if_vtnet
**Workspace / 工作区**: `/workspace`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- Nightly `32483868137` (`2f74ddcdd`) passed `Build tools` then failed
  `Build distribution` in `lib/libm`:
  `s_cbrtl.c:128: error: Unsupported long double format`.
- In-tree gcc 4.8.5: `__SIZEOF_LONG_DOUBLE__==8`, `__LDBL_MANT_DIG__==53`.
  `__HAVE_LONG_DOUBLE 128` compiled binary128 `s_cbrtl.c` against
  `float.h` that defaults `LDBL_MANT_DIG` to 53.

**Fix / 修复**:
1. Drop `__HAVE_LONG_DOUBLE 128`. Alias `copysignl` / `fabsl` / `fmal`
   from `arch/riscv` `.S` files that replace the C sources (`#48`).
2. virtio-net-mmio: 256-slot RX/TX rings, `VIRTIO_NET_F_CTRL_MAC` /
   `CTRL_RX_EXTRA`, `ndr_set_hwaddr` via `CTRL_MAC_ADDR_SET`,
   `CTRL_RX_NOBCAST` (`#49`). Net smoke requires `rx 256`.

**Evidence / 证据**:
- `issue.md` `#48` `#49`
- GitHub Actions run `32483868137`
- `sys/arch/riscv/include/math.h`
- `lib/libm/arch/riscv/s_copysign.S`
- `minix/drivers/net/virtio_net_mmio/virtio_net_mmio.c`

### Entry 45 — gcc 4.8.5 backend generator sources (2026-08-21) / 4.8.5 backend 生成器源
**Workspace / 工作区**: `/workspace`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- Nightly/release `32486378021` (`a4d3a69ff`) passed `Build tools` then
  failed `Build distribution` in `external/gpl3/gcc/usr.bin/backend`:
  `don't know how to make .../gcc/gengenrtl.cc`.
- gcc 4.8.5 ships `gengenrtl.c`. RISC-V `defs.mk` is gcc 13.2.0 mknative
  and the backend Makefile hardcoded `.cc` generator paths.

**Fix / 修复**:
1. Resolve each dist/gcc generator basename to `.cc` or `.c`.
2. Drop gcc13-only objects/generators (`gengtype-state`, `hash-table`,
   `sort`, `inchash`, `genenums`) when the dist lacks them.
3. On 4.8.5, run `./gengtype` without `-S/-w/-r` state files.

**Evidence / 证据**:
- `issue.md` `#50`
- GitHub Actions run `32486378021`
- `external/gpl3/gcc/usr.bin/backend/Makefile`

### Entry 46 — skip gcc13 common.md on 4.8.5 (2026-08-21) / 4.8.5 上跳过 gcc13 common.md
**Workspace / 工作区**: `/workspace`  
**Target / 目标**: `evbriscv64`  
**Profile / 轮廓**: `obj.intrgcc`

**Symptom / 现象**:
- Nightly `32488937725` (`5fe3792d1`) passed `Build tools` then failed
  `Build distribution` in `external/gpl3/gcc/usr.bin/backend`:
  `don't know how to make .../gcc/common.md`.
- `#50` unblocked `gengenrtl.c`. riscv64 `defs.mk` still lists gcc13
  `common.md`, which gcc 4.8.5 does not ship.

**Fix / 修复**:
- Keep only existing paths in `G_md_file` (typically `config/riscv/riscv.md`).

**Evidence / 证据**:
- `issue.md` `#52`
- GitHub Actions run `32488937725`
- `external/gpl3/gcc/usr.bin/backend/Makefile`

## Entry 47 — 2026-08-21 15:20 UTC

**Change / 变更**: Hosted CI tools gcc 4.8.5 does not emit `version.h` (version is `BASEVER` plus `version.c`). gcc 13 native `defs.mk` still copies that header into `external/gpl3/gcc/usr.bin/backend`. `Makefile.toolsgccfiles` synthesizes `version.h`, `bversion.h`, `plugin-version.h`, and later gcc13 generator fragments when the tools copy is missing.

**Issue ID**: `#53`

**Result / 结果**: Local Makefile review. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#53`
- GitHub Actions run `32491621998`
- `external/gpl3/gcc/usr.bin/Makefile.toolsgccfiles`

## Entry 48 — 2026-08-21 15:05 UTC

**Change / 变更**: gcc 4.8.5 `genmodes` only accepts `-h|-m`. gcc 13 native backend runs `./genmodes -i` for `insn-modes-inline.h`. Stub that header when `genmodes.cc` is absent. Map remaining frontend/cc1/gcc `.cc` SRCS to `.c` via `Makefile.cc2c`, and stub `specs.h` if tools gcc omits it.

**Issue ID**: `#54`

**Result / 结果**: Local Makefile review against gcc 4.8.5 `genmodes.c`. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#54`
- `external/gpl3/gcc/usr.bin/backend/Makefile`
- `external/gpl3/gcc/usr.bin/Makefile.cc2c`

## Entry 49 — 2026-08-21 15:25 UTC

**Change / 变更**: Hosted nightly `32495453269` created local `version.h` then failed on `tools/gcc/build/gcc/version.h`. `G_GCC_H` listed that tools path as a host-helper prerequisite. Use the local stub when the tools copy is missing.

**Issue ID**: `#55`

**Result / 结果**: Local Makefile review. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#55`
- GitHub Actions run `32495453269`
- `external/gpl3/gcc/usr.bin/backend/Makefile`

## Entry 50 — 2026-08-21 15:50 UTC

**Change / 变更**: Hosted nightly `32497228532` (`744e854c3`) passed tools then failed native backend looking for `genhooks.cc`. `#50` mapped other generators; `Makefile.hooks` still hardcoded the gcc13 name. gcc 4.8.5 ships `genhooks.c`. Resolve `.cc` or `.c` from dist. Leave the `"Target Hook"` argv as-is; 4.8.5 `genhooks` accepts it.

**Issue ID**: `#56`

**Result / 结果**: Local Makefile review against gcc 4.8.5 `genhooks.c`. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#56`
- GitHub Actions run `32497228532`
- `external/gpl3/gcc/Makefile.hooks`

## Entry 51 — 2026-08-21 16:15 UTC

**Change / 变更**: Hosted nightly `32499756350` (`e0766af8e`) compiled `genhooks.c` then failed linking `gengtype` with undefined `version_string`. gcc 4.8.5 still ships `version.c` and `gengtype-state.c`; gcc 13 dropped `version.o`. Link `version.lo` into `gengtype` with `VER_CPPFLAGS`. Treat `gtype-desc.c` as the 4.8.5 GTY output instead of gcc13 `gtype-desc.cc`.

**Issue ID**: `#57`

**Result / 结果**: Local Makefile review against gcc 4.8.5 `Makefile.in` (`build/gengtype` links `build/version.o`). CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#57`
- GitHub Actions run `32499756350`
- `external/gpl3/gcc/usr.bin/backend/Makefile`

## Entry 52 — 2026-08-21 16:50 UTC

**Change / 变更**: Hosted nightly `32502264930` (`b1686b5c3`) linked `gengtype` then aborted in `s-gtype` (`named_label_entry` used but not defined, then `abort in error_at_line`). riscv64 `gtyp-input.list` is gcc13 `.cc` names; the tmp filter only mapped `.c` to `.cc`, so missing `.cc` files were dropped. `defs.mk` `G_GTFILES` is the 4.8.5 GTFILES list. Emit that list as `gtyp-input.list.tmp` when `gengtype.cc` is absent, and map `.cc` to `.c` on the gcc13 path.

**Issue ID**: `#58`

**Result / 结果**: Local Makefile review against gcc 4.8.5 `gengtype.c` (`error_at_line` asserts `pos->file != NULL`) and `defs.mk` `G_GTFILES`. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#58`
- GitHub Actions run `32502264930`
- `external/gpl3/gcc/usr.bin/backend/Makefile`

## Entry 53 — 2026-08-21 17:20 UTC

**Change / 变更**: Hosted nightly `32505629389` (`d93d49dcb`) failed `gtyp-input.list.tmp` with `sh: .for: not found` (exit 127). `#58` put `.for` inside a `{ \' recipe continuation, so nbmake passed it to the shell. Emit one quoted `printf` per `G_GTFILES` word as its own recipe line.

**Issue ID**: `#59`

**Result / 结果**: Makefile recipe now expands `.for` at parse time. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#59`
- GitHub Actions run `32505629389`
- `external/gpl3/gcc/usr.bin/backend/Makefile`

## Entry 54 — 2026-08-21 18:00 UTC

**Change / 变更**: Hosted nightly `32508128890` (`f074b4a56`) expanded `.for`, then make split the standalone recipe `printf '%s\n'` so the format string became a real newline. `gtyp-input.list.tmp` was garbage; `gengtype -r` warned `structure 'answer' used but not defined` and aborted in `error_at_line`. Echo one `G_GTFILES` word per line so make never sees `\n`.

**Issue ID**: `#60`

**Result / 结果**: Makefile recipe uses `echo` instead of `printf '%s\n'`. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#60`
- GitHub Actions run `32508128890`
- `external/gpl3/gcc/usr.bin/backend/Makefile`

## Entry 55 — 2026-08-21 18:25 UTC

**Change / 变更**: Hosted nightly `32511340050` (`bfb31c72d`) echoed a well-formed `G_GTFILES` list, then `gengtype -r` still warned `structure 'answer' used but not defined` / `cpp_macro` and aborted in `error_at_line`. gcc 4.8.5 defines those GTY types in `libcpp/include/cpp-id-data.h`. The gcc13 path dropped that header unconditionally. Keep it when the file exists.

**Issue ID**: `#61`

**Result / 结果**: `cpp-id-data.h` stays on gcc 4.8.5. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#61`
- GitHub Actions run `32511340050`
- `external/gpl3/gcc/usr.bin/backend/Makefile`

## Entry 56 — 2026-08-21 18:55 UTC

**Change / 变更**: Hosted nightly `32513249750` (`a0707ca84`) finished `s-gtype`, then failed compiling `hash-table.lo`: `config.h:4:2: error: #error config.h is for the host, not build, machine`. gcc 4.8.5 `hash-table.c` includes `config.h` unconditionally while generator `.lo` objects compile with `-DGENERATOR_FILE`. Wrap `config.h` so that case includes arch `bconfig.h`.

**Issue ID**: `#62`

**Result / 结果**: Generator objects include `bconfig.h` via the `config.h` wrapper. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#62`
- GitHub Actions run `32513249750`
- `external/gpl3/gcc/usr.bin/backend/Makefile`

## Entry 57 — 2026-08-21 19:25 UTC

**Change / 变更**: Hosted nightly `32516002843` (`086dbe436`) compiled `hash-table.lo`, then failed native `external/gpl3/gcc/usr.bin/libcpp` with `don't know how to make charset.cc`. gcc 4.8.5 ships `libcpp/*.c`; riscv64 `defs.mk` `G_libcpp_a_OBJS` is gcc 13 mknative and the Makefile rewrites those objects to `.cc`. Map each name onto `libcpp/*.c` when the dist has no `.cc`.

**Issue ID**: `#63`

**Result / 结果**: Native libcpp SRCS resolve `.cc` or `.c` from dist. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#63`
- GitHub Actions run `32516002843`
- `external/gpl3/gcc/usr.bin/libcpp/Makefile`

## Entry 58 — 2026-08-21 19:55 UTC

**Change / 变更**: Hosted nightly `32519022725` (`445b0e907`) built `libcpp.a`, then failed native gcov/cc1 with `gcov-io.h:292:22: fatal error: gcov-iov.h: No such file or directory`. gcc 4.8.5 `gcov-io.h` includes that header; mknative ships it under `lib/libgcc/libgcov/arch`. Backend already passed `-I` there; add the same path in `usr.bin/Makefile.inc`.

**Issue ID**: `#64`

**Result / 结果**: Native gcov/cc1 search the libgcov arch dir for `gcov-iov.h`. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#64`
- GitHub Actions run `32519022725`
- `external/gpl3/gcc/usr.bin/Makefile.inc`

## Entry 59 — 2026-08-21 20:35 UTC

**Change / 变更**: Hosted nightly `32521377902` (`6358e38bb`) still failed native gcov/cc1 with `gcov-io.h:292:22: fatal error: gcov-iov.h: No such file or directory`. `#64` added `-I${.PARSEDIR}/../lib/libgcc/libgcov/arch/${GCC_MACHINE_ARCH}`; `.PARSEDIR` expanded empty, so the compile line was `-I/../lib/libgcc/libgcov/arch/riscv64`. Resolve the path from `NETBSDSRCDIR`.

**Issue ID**: `#65`

**Result / 结果**: Native gcov/cc1 `-I` for `gcov-iov.h` is an absolute src path. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#65`
- GitHub Actions run `32521377902`
- `external/gpl3/gcc/usr.bin/Makefile.inc`

## Entry 60 — 2026-08-21 21:10 UTC

**Change / 变更**: Hosted nightly `32524763481` (`7014a3bb6`) compiled native gcov.c, then linking gcov failed with undefined `fnotice`, `fancy_abort`, `diagnostic_initialize`, `version_string`, `pkgversion_string`, and `bug_report_url`. `usr.bin/common` listed gcc13 `.cc` names; `Makefile.cc2c` kept only `input.c`, so `libcommon.a` was archived from `input.o`. Map diagnostic/pretty-print/intl/input/version like common-target and restore `version.c`.

**Issue ID**: `#67`

**Result / 结果**: Native libcommon SRCS resolve the gcc 4.8.5 diagnostic objects including `version.c`. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#67`
- GitHub Actions run `32524763481`
- `external/gpl3/gcc/usr.bin/common/Makefile`

## Entry 61 — 2026-08-21 21:45 UTC

**Change / 变更**: Hosted nightly `32527820716` (`c952fa0c1`) compiled native gcov, then linking `usr.bin/cpp` `gcpp` failed with multiple `ggc_free` definitions and undefined `main`. The link line was `ggc-none.o ggc-none.o ggc-none.o`. `#54` `Makefile.cc2c` did `GCC_SRCS_MAPPED+= ${_gcc_cc2c}`; bmake delays that expansion, so `SRCS:=` repeated the last match (`ggc-none.c` for `cppspec.cc gcc.cc ggc-none.cc`). Add `${s}` / `${s:R}.c` directly, like common-target.

**Issue ID**: `#68`

**Result / 结果**: Native frontend/cc1/cpp/gcc SRCS keep one mapped basename per input. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#68`
- GitHub Actions run `32527820716`
- `external/gpl3/gcc/usr.bin/Makefile.cc2c`

## Entry 62 — 2026-08-21 22:20 UTC

**Change / 变更**: Hosted nightly `32530101083` (`92237adf3`) linked native `gcpp` as `cppspec.o gcc.o ggc-none.o` (`#68` held), then failed with undefined `global_init_params` / `compiler_params` from gcc 4.8.5 `params.c`, and `dgettext` / `bindtextdomain` from libcpp. gcc13 dropped `params.cc` from common-target; map it back onto `params.c`. Repeat `-lintl` after frontend archives so the static RISC-V link sees libintl after libcpp.a.

**Issue ID**: `#69`

**Result / 结果**: libcommon-target includes 4.8.5 `params.c`; frontend drivers relink `-lintl` after archives. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#69`
- GitHub Actions run `32530101083`
- `external/gpl3/gcc/usr.bin/common-target/Makefile`
- `external/gpl3/gcc/usr.bin/Makefile.frontend`

## Entry 63 — 2026-08-21 22:50 UTC

**Change / 变更**: Hosted nightly `32532469511` (`9cb398c22`) linked native `gcpp` with `-lintl` after `libdecnumber.a` (`#69` held), then died `nbmake: don't know how to make lto1.1` in `external/gpl3/gcc/usr.bin/lto1` after `.depend`. `#54` put `.include "../Makefile.cc2c"` at the top of `lto1` / `cc1` / `cc1obj` / `cc1plus`; that file includes `Makefile.inc` → `bsd.own.mk` before `NOMAN`. `bsd.own.mk` is include-guarded (`_BSD_OWN_MK_`); first parse sees `NOMAN` unset so `MKMAN` stays yes, and `Makefile.backend`'s later `NOMAN` cannot flip it. `bsd.prog.mk` then `_APPEND_MANS=yes` → `MAN+= ${PROG}.1`. gcc 4.8.5 does not ship `lto1.1` / `cc1.1` / `cc1obj.1` / `cc1plus.1`. Set `NOMAN=1` in those four program Makefiles before `Makefile.cc2c`, matching `lto-wrapper`.

**Issue ID**: `#70`

**Result / 结果**: Native `lto1` / `cc1` / `cc1obj` / `cc1plus` keep `MKMAN=no` because `NOMAN` is set before `bsd.own.mk`. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#70`
- GitHub Actions run `32532469511`
- `external/gpl3/gcc/usr.bin/lto1/Makefile`
- `external/gpl3/gcc/usr.bin/cc1/Makefile`
- `external/gpl3/gcc/usr.bin/cc1obj/Makefile`
- `external/gpl3/gcc/usr.bin/cc1plus/Makefile`

## Entry 64 — 2026-08-21 23:30 UTC

**Change / 变更**: Hosted nightly `32534503524` (`88ec45927`) linked native `lto1` (`#70` held), then failed with undefined `pointer_set_create`, `lto_symtab_prevailing_decl`, `dump_insn_slim`, `insn_data` / `gen_*` / `lookup_constraint`, GTY `gt_ggc_r_gt_dbxout_h`, and `madvise`. `libbackend.a` started at `ggc-page.o` with no `insn-*.o`. `#47` used `!empty(_b:Mininsn-*)`; that is `:M` + `ininsn-*`, so every generated `insn-*.o` was dropped (source lives in OBJDIR, not dist). gcc13 `G_OBJS` also omits 4.8.5 `pointer-set.o`, `lto-symtab.o`, `sched-vis.o` (`dump_insn_slim`), `dbxout.o` / `sdbout.o` / `tree-nomudflap.o`. Use `:Minsn-*` and add those objects when the dist source exists. Undef `HAVE_MADVISE` in native `config.h` so `ggc-page.c` does not call `madvise` (tools `config.h` is the Linux host).

**Issue ID**: `#71`

**Result / 结果**: Native libbackend keeps generated `insn-*.o` and 4.8.5-only objects gcc13 `G_OBJS` dropped. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#71`
- GitHub Actions run `32534503524`
- `external/gpl3/gcc/usr.bin/backend/Makefile`

## Entry 65 — 2026-08-21 23:59 UTC

**Change / 变更**: Hosted nightly `32537278919` (`6954a7e6c`) linked native `lto1` (`#71` held), then failed linking `cc1` with undefined `mudflap_init()` and `_cpp_preprocess_dir_only`. gcc13 `G_C_OBJS` dropped 4.8.5 `tree-mudflap.o` (still in i386 defs); `G_libcpp_a_OBJS` dropped `directives-only.o`. Restore those objects (and `cp/repo.o` for `cc1plus`) in `usr.bin/Makefile.inc` when the dist source exists.

**Issue ID**: `#72`

**Result / 结果**: Native `cc1` / `cc1plus` / libcpp keep gcc 4.8.5 frontend and directives-only objects gcc13 mknative dropped. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#72`
- GitHub Actions run `32537278919`
- `external/gpl3/gcc/usr.bin/Makefile.inc`
- `external/gpl3/gcc/usr.bin/libcpp/Makefile`

## Entry 66 — 2026-08-22 02:20 UTC

**Change / 变更**: Hosted nightly `32539264449` (`6a08be70f`) passed tools, distribution, native, virtio-blk, and virtio-net init (`hdr 12`, `mrg on`, `event_idx on`, `rx 256`, `ifconfig vio0`, `ping6 ::1`), then `/sbin/ping -c 2 10.0.2.2` reported `2 packets transmitted, 0 packets received`. `#46` EVENT_IDX in `virtio_mmio_to_queue` only writes `QUEUE_NOTIFY` when `vring_need_event(avail_event=0)` is true (the first buffer of a burst). A 256-slot RX refill therefore left QEMU looking at one buffer (IPv6 RA can consume it); TX `ping -c 2` has the same hole on the second packet. Add `virtio_mmio_kick()` and kick RX after refill, TX after send, and CTRL after `to_queue`. Keep EVENT_IDX negotiated. Do not change virtio-blk (one request at a time).

**Issue ID**: `#73`

**Result / 结果**: virtio-net RX refill and TX/CTRL posts notify QEMU of the current avail idx instead of only the first slot. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#73`
- GitHub Actions run `32539264449`
- `minix/include/minix/virtio_mmio.h`
- `minix/lib/libvirtio_mmio/virtio_mmio.c`
- `minix/drivers/net/virtio_net_mmio/virtio_net_mmio.c`

## Entry 67 — 2026-08-22 03:20 UTC

**Change / 变更**: Hosted nightly `32546187525` (`45418c7fb`) kept `#73` kicks (`event_idx on`, `rx 256`, `ifconfig vio0`, `ping6 ::1`) then failed `ping -c 2 10.0.2.2` with `2 packets transmitted, 0 packets received`. virtio-blk completes I/O by busy-waiting on `from_queue`; virtio-net only drained RX from the VRING IRQ. `from_queue` published `used_event = last_used` on every consume, so a missed first used-notify left QEMU's `signalled_used_valid` set and suppressed later interrupts. Drain the used ring after TX kick and on a 10 Hz tick, publish `used_event` with Linux `virtqueue_enable_cb` after the drain, `IRQ_REENABLE` the MMIO line, and read the MAC with byte accesses. Keep EVENT_IDX negotiated.

**Issue ID**: `#74`

**Result / 结果**: virtio-net RX no longer depends on the first EVENT_IDX used-notify. CI pending after this push.

**Evidence / 证据**:
- `issue.md` `#74`
- GitHub Actions run `32546187525`
- `minix/include/minix/virtio_mmio.h`
- `minix/lib/libvirtio_mmio/virtio_mmio.c`
- `minix/drivers/net/virtio_net_mmio/virtio_net_mmio.c`

## Entry 68 — 2026-08-22 04:00 UTC

**Change / 变更**: Hosted nightly still burns 30+ min rediscovering EVENT_IDX avail/used notify math after `#73`/`#74` driver fixes. Add host-executable `minix/tests/riscv64/test_virtio_event_idx.c` (`vring_need_event` cases for `#73`/`#74`); `run_tests.sh` `run_build_tests` compiles and runs it with the host compiler. `qemu-riscv64.sh` uses `QEMU=${QEMU:-qemu-system-riscv64}` and appends `filter-dump` after `-netdev` when `NET_PCAP` is set. `qemu_net_smoke.py` requires `virtio-net-mmio: mac 52:54:00:12:34:56`, dumps the pcap, logs ARP/echo counts, and hints TX vs RX when `ping_gw` fails.

**Issue ID**: `#75`

**Result / 结果**: local host EVENT_IDX test added (`run_tests.sh build` 9/0/0). Local QEMU 8.2.2 net smoke against rebuilt ramdisk passed init/MAC/mrg/event_idx/rx256/ifconfig/ping6; `ping -c 2 10.0.2.2` still 100% loss. Endian-fixed pcap: `arp_req=6 arp_rep=0 echo_req=0 echo_rep=0`. Gateway ping not claimed green.

**Evidence / 证据**:
- `issue.md` `#75`
- `minix/tests/riscv64/qemu_net_smoke.py`

## Entry 69 — 2026-08-22 04:30 UTC

**Change / 变更**: `#75` pcap showed well-formed guest ARP who-has `10.0.2.2` and no slirp reply. QEMU 8.2 `net/slirp.c` `net_init_slirp()` sets `ipv4=0` when `ipv6=on` is present without `ipv4=on`, so libslirp `in_enabled` is off and `arp_input` returns immediately. Pass `ipv4=on,ipv6=on` from `qemu-riscv64.sh`. Keep EVENT_IDX. `run_tests.sh build` greps the script so this cannot silently regress.

**Issue ID**: `#76`

**Result / 结果**: Local QEMU 8.2.2 net smoke `PASS: qemu net smoke`; `ping_gw` passed. pcap `arp_req=2 arp_rep=1 echo_req=2 echo_rep=2`. Hosted nightly not claimed green.

**Evidence / 证据**:
- `issue.md` `#76`
- `minix/scripts/qemu-riscv64.sh`
- `/tmp/qemu-net-smoke-ipv4.log`
- QEMU 8.2 `net/slirp.c` `net_init_slirp()`

