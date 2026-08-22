#	$NetBSD: Makefile,v 1.5 2014/03/05 21:37:02 tron Exp $

.include <bsd.own.mk>
.include "../Makefile.hostprobes"
.include "../Makefile.inc"

PROG=           gcov

# Packaging CI fetches gcc 4.8.5 (gcov.c, no json.cc). riscv64 defs.mk
# is gcc 13.2.0 mknative and lists json.o. Skip sources the dist lacks.
.if !exists(${DIST}/gcc/json.cc)
G_GCOV_OBJS:=	${G_GCOV_OBJS:Njson.o}
.endif
SRCS=		${G_GCOV_OBJS:.o=.cc}
.if exists(${DIST}/gcc/gcov.c) && !exists(${DIST}/gcc/gcov.cc)
SRCS:=		${SRCS:S/.cc/.c/g}
.endif

CPPFLAGS+=	-I. -I${GCCARCH} -I${BACKENDOBJ} ${G_ALL_CFLAGS:M-D*} ${G_INCLUDES:M-I*:N-I.*}

BINDIR=		/usr/bin

MAN=		gcov.1

HOSTPROG_CXX=	1

TOOLSGCCOBJ!=	cd ${NETBSDSRCDIR}/tools/gcc && ${PRINTOBJDIR}
TOOLSGCCBUILD=	${TOOLSGCCOBJ}/build/gcc

DPSRCS+=	options.h config.h auto-host.h tm.h version.h bversion.h
.NOPATH:	options.h config.h auto-host.h tm.h version.h bversion.h
CLEANFILES+=	options.h config.h auto-host.h tm.h version.h bversion.h

config.h: gcc13-config-force ${TOOLSGCCBUILD}/config.h ${.PARSEDIR}/../Makefile.hostprobes
	rm -f ${.TARGET}
	cp ${TOOLSGCCBUILD}/config.h ${.TARGET}
	{ \
		echo '#ifndef CHECKING_P'; \
		echo '#define CHECKING_P 0'; \
		echo '#endif'; \
		echo '#ifndef ENABLE_OFFLOADING'; \
		echo '#define ENABLE_OFFLOADING 0'; \
		echo '#endif'; \
		echo '#ifndef HAVE_AS_LEB128'; \
		echo '#define HAVE_AS_LEB128 0'; \
		echo '#endif'; \
	} >> ${.TARGET}

auto-host.h: gcc13-auto-host-force ${TOOLSGCCBUILD}/auto-host.h ${.PARSEDIR}/../Makefile.hostprobes
	rm -f ${.TARGET}
	cp ${TOOLSGCCBUILD}/auto-host.h ${.TARGET}
	{ \
		for fn in ${GCC13_TARGET_STDIO_UNLOCKED_MISSING}; do \
			echo "#undef HAVE_$${fn}_UNLOCKED"; \
			echo "#undef HAVE_DECL_$${fn}_UNLOCKED"; \
		done; \
		for fn in ${GCC13_TARGET_MALLOC_INFO_MISSING}; do \
			echo "#undef HAVE_$${fn}"; \
			echo "#undef HAVE_DECL_$${fn}"; \
		done; \
		for fn in ${GCC13_TARGET_DECL_FALLBACKS}; do \
			echo "#undef HAVE_$${fn}"; \
			echo "#define HAVE_DECL_$${fn} 0"; \
		done; \
	} >> ${.TARGET}

tm.h: ${TOOLSGCCBUILD}/tm.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

options.h: ${TOOLSGCCBUILD}/options.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

.include "../Makefile.toolsgccfiles"

${SRCS:.cc=.d} ${SRCS:.cc=.o} ${SRCS:.c=.d} ${SRCS:.c=.o}: options.h config.h auto-host.h tm.h version.h bversion.h
.if exists(${DIST}/gcc/gcov.cc)
gcov.d gcov.o: gcov.cc
.elif exists(${DIST}/gcc/gcov.c)
gcov.d gcov.o: gcov.c
.endif
.if exists(${DIST}/gcc/json.cc)
json.d json.o: json.cc
.endif

# Force using C++ for this
HOST_CC:=	${HOST_CXX}
CC:=		${CXX}
CFLAGS:=	${CXXFLAGS} -Wno-stack-protector

.include "../Makefile.common"
.include "../Makefile.libcpp"
.include "../Makefile.backtrace"
.include "../Makefile.libiberty"
.include "../Makefile.libdecnumber"

LDADD+=		-lintl
DPADD+=		${LIBINTL}

.PATH: ${DIST}/gcc

.include <bsd.prog.mk>
