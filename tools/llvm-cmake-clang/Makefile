# MINIX: install CMake-built cross clang into TOOLDIR.

NOMAN=		# defined

.include <bsd.init.mk>

.if !defined(LLVM_VERSION)
LLVM_VERSION=	18.1.8
.endif

HOST_BINDIR=	${TOOLDIR}/bin
WRAPPER=	${HOST_BINDIR}/${MACHINE_GNU_PLATFORM}-clang

realdepends realall: stamp-llvm-cmake-clang

stamp-llvm-cmake-clang: .MAKE
	@test -x ${WRAPPER} || (echo "missing ${WRAPPER}" >&2; exit 1)
	@touch ${.TARGET}

CLEANFILES+=	stamp-llvm-cmake-clang

.include <bsd.hostprog.mk>

install.host: ${HOST_BINDIR}/${MACHINE_GNU_PLATFORM}-clang++
install.host: ${HOST_BINDIR}/${MACHINE_GNU_PLATFORM}-clang-cpp

${HOST_BINDIR}/${MACHINE_GNU_PLATFORM}-clang++ ${HOST_BINDIR}/${MACHINE_GNU_PLATFORM}-clang-cpp}: \
    stamp-llvm-cmake-clang
	${_MKTARGET_INSTALL}
	mkdir -p ${HOST_BINDIR}
	${HOST_INSTALL_SYMLINK} ${MACHINE_GNU_PLATFORM}-clang ${.TARGET}
