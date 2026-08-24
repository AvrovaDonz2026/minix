# MINIX: CMake-based LLVM build (modern clang with RISC-V backend).
#
# Enabled when MKLLVM_CMAKE=yes.  Replaces the legacy autoconf/make LLVM 3.6
# host-tools path under tools/llvm for cross builds.

.include <bsd.init.mk>

.if !defined(LLVM_VERSION)
LLVM_VERSION=	18.1.8
.endif

LLVM_CMAKE_SCRIPT= ${NETBSDSRCDIR}/scripts/build-llvm-cmake.sh

realdepends realall: stamp-llvm-cmake

stamp-llvm-cmake: ${LLVM_CMAKE_SCRIPT}
	@test -n "${TOOLDIR}" || (echo "TOOLDIR not set" >&2; exit 1)
	@env TOOLDIR="${TOOLDIR}" LLVM_VERSION="${LLVM_VERSION}" \
	    LLVM_JOBS="${_TOOL_JOBS:U4}" \
	    /bin/bash ${LLVM_CMAKE_SCRIPT}
	@touch ${.TARGET}

CLEANFILES+=	stamp-llvm-cmake

.include <bsd.hostprog.mk>
