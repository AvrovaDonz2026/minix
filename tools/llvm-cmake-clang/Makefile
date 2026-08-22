# MINIX: install CMake-built cross clang into TOOLDIR.

NOMAN=		# defined

HOSTPROGNAME=	${MACHINE_GNU_PLATFORM}-clang
HOSTPROG_CXX=	${MACHINE_GNU_PLATFORM}-clang

.include <bsd.init.mk>

.if !defined(LLVM_VERSION)
LLVM_VERSION=	18.1.8
.endif

LLVM_BINDIR=	${TOOLDIR}/bin
WRAPPER=	${LLVM_BINDIR}/${MACHINE_GNU_PLATFORM}-clang

realdepends realall: stamp-llvm-cmake-clang

stamp-llvm-cmake-clang: .MAKE
	@test -x ${WRAPPER} || (echo "missing ${WRAPPER}" >&2; exit 1)
	@touch ${.TARGET}

CLEANFILES+=	stamp-llvm-cmake-clang

.include <bsd.hostprog.mk>

install.host: ${HOST_BINDIR}/${MACHINE_GNU_PLATFORM}-clang++
install.host: ${HOST_BINDIR}/${MACHINE_GNU_PLATFORM}-clang-cpp

${HOST_BINDIR}/${MACHINE_GNU_PLATFORM}-clang++ ${HOST_BINDIR}/${MACHINE_GNU_PLATFORM}-clang-cpp}: \
    ${HOST_BINDIR}/${MACHINE_GNU_PLATFORM}-clang
	${_MKTARGET_INSTALL}
	mkdir -p ${HOST_BINDIR}
	${HOST_INSTALL_SYMLINK} ${HOSTPROGNAME} ${.TARGET}
