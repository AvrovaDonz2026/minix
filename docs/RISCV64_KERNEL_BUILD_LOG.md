# RISC-V MINIX Kernel Build Log / RISC-V MINIX 内核构建日志

**Last updated / 最后更新**: 2026-01-07  
**Version / 版本**: 1.2  
**Purpose / 用途**: Append-only record of build commands and outcomes. / 记录构建命令与结果（追加式）。

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

### Entry 8 — Toolchain + Distribution + RISC-V Tests (2026-01-31) / 工具链 + 发行版 + RISC-V 测试
**Workspace / 工作区**: `/home/donz/minix`  
**Commands / 命令**:
```bash
# Tools (with ccache)
CCACHE_CONFIGPATH=/home/donz/minix/obj/ccache/ccache.conf \
CCACHE_BASEDIR=/home/donz/minix \
CCACHE_DIR=/home/donz/minix/obj/ccache/cache \
PATH="/usr/lib/ccache:$PATH" \
MKPCI=no HOST_CFLAGS="-O -fcommon" HAVE_GOLD=no HAVE_LLVM=no MKLLVM=no \
HOST_CC="cc -Wno-implicit-int -Wno-implicit-function-declaration" \
./build.sh -U -m evbriscv64 \
  -V AVAILABLE_COMPILER=gcc -V ACTIVE_CC=gcc -V ACTIVE_CPP=gcc -V ACTIVE_CXX=gcc -V ACTIVE_OBJC=gcc \
  tools

# Distribution (external toolchain)
CCACHE_CONFIGPATH=/home/donz/minix/obj/ccache/ccache.conf \
CCACHE_BASEDIR=/home/donz/minix \
CCACHE_DIR=/home/donz/minix/obj/ccache/cache \
PATH="/usr/lib/ccache:$PATH" \
EXTERNAL_TOOLCHAIN=/home/donz/minix/obj/exttoolchain \
HOST_CC="cc -Wno-implicit-int -Wno-implicit-function-declaration" \
MKPCI=no HOST_CFLAGS="-O -fcommon" HAVE_GOLD=no HAVE_LLVM=no MKLLVM=no \
CFLAGS="-fcommon" LDFLAGS='-Wl,--defsym,_gp=__global_pointer$$' \
./build.sh -U -u -j"$(nproc)" -m evbriscv64 \
  -V TOOLCHAIN_MISSING=yes \
  -V AVAILABLE_COMPILER=gcc -V ACTIVE_CC=gcc -V ACTIVE_CPP=gcc -V ACTIVE_CXX=gcc -V ACTIVE_OBJC=gcc \
  -V RISCV_ARCH_FLAGS='-march=rv64imafd -mcmodel=medany' \
  -V NOGCCERROR=yes \
  -V MKPIC=no -V MKPICLIB=no -V MKPICINSTALL=no \
  -V MKGCCCMDS=no -V MKLIBSTDCXX=no -V MKCXX=no -V MKLIBCXX=no -V MKATF=yes -V MKKYUA=yes \
  -V USE_PCI=no -V MKLIBOBJC=no -V MKLIBGOMP=no \
  -V CHECKFLIST_FLAGS='-m -e' \
  -V MKBINUTILS=no \
  distribution

# Tests
TOOLDIR=/home/donz/minix/obj/exttoolchain \
DESTDIR=/home/donz/minix/obj/destdir.evbriscv64 \
LOGDIR=/home/donz/minix/obj/test-logs \
RISCV_ARCH_FLAGS='-march=rv64imafd_zicsr_zifencei -mcmodel=medany' \
./minix/tests/riscv64/run_tests.sh all
```
**Results / 结果**:
- tools build: success (`/tmp/minix-tools.log`)
- distribution: success (`/tmp/minix-build.log`); `checkflist` relaxed with `-m -e` shows extra/missing files (non-fatal)
- tests: build/user tests pass; kernel boot + timer pass; SMP skipped; VirtIO block I/O smoke failed due to `minix-service` SIGSEGV during driver start (see `/tmp/minix-riscv64-tests.log`)

**Notes / 说明**:
- ccache config: `/home/donz/minix/obj/ccache/ccache.conf`
- virtio smoke failure: `/sbin/minix-service -c up /service/virtio_blk_mmio -dev /dev/c0d0` crashes (`pc=0x3bb38`, `sp=0xefbffff0`)

### Entry 9 — Boot Path Stabilization + QEMU Smoke (2026-02-16) / 启动路径稳定化 + QEMU 冒烟
**Workspace / 工作区**: `/home/donz/minix`  
**Commands / 命令**:
```bash
# Rebuild affected MINIX tree using in-tree toolchain
obj.intrgcc/tooldir/bin/nbmake-evbriscv64 -C minix MKPCI=yes MKCOVERAGE=no dependall

# Non-interactive boot check
timeout 120 ./minix/scripts/qemu-riscv64.sh \
  -k obj.intrgcc/minix/kernel/kernel \
  -B obj.intrgcc/destdir.evbriscv64 > /tmp/qemu-fix20.log 2>&1 || true

# Interactive smoke (manual)
./minix/scripts/qemu-riscv64.sh \
  -k obj.intrgcc/minix/kernel/kernel \
  -B obj.intrgcc/destdir.evbriscv64
# In guest shell:
echo SMOKE_OK
```
**Key code changes / 关键代码改动**:
- `minix/include/arch/riscv64/include/archconst.h`: set `USR_DATATOP/USR_STACKTOP` to `0x70000000UL` (keep ilp32 user pointers below sign-extension hazard zone).
- `minix/fs/pfs/pfs.c`, `minix/fs/mfs/main.c`: set `sef_cb_init_response_rs_asyn_once` for startup init response.
- `minix/servers/vfs/main.c`, `minix/servers/vfs/mount.c`, `minix/servers/vfs/dmap.c`: boot-time FS callback/service-endpoint handling hardening.

**Results / 结果**:
- No boot-time `VM: pagefault: SIGSEGV ... bad addr ...` observed in `/tmp/qemu-fix20.log`.
- Boot passed `VFS: init_root done`, `init: exec /bin/sh /etc/rc`, and reached shell path repeatedly.
- Interactive QEMU smoke succeeded: shell prompt available and `echo SMOKE_OK` returned `SMOKE_OK`.
