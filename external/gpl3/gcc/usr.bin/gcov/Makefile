#	$NetBSD: Makefile,v 1.5 2014/03/05 21:37:02 tron Exp $

.include <bsd.own.mk>
.include "../Makefile.hostprobes"

PROG=           gcov
SRCS=		${G_GCOV_OBJS:.o=.cc}

CPPFLAGS+=	-I${GCCARCH} -I${BACKENDOBJ} ${G_ALL_CFLAGS:M-D*} ${G_INCLUDES:M-I*:N-I.*}

BINDIR=		/usr/bin

MAN=		gcov.1

HOSTPROG_CXX=	1

TOOLSGCCOBJ!=	cd ${TOP}/tools/gcc && ${PRINTOBJDIR}
TOOLSGCCBUILD=	${TOOLSGCCOBJ}/build/gcc

DPSRCS+=	config.h auto-host.h tm.h version.h bversion.h
.NOPATH:	config.h auto-host.h tm.h version.h bversion.h
CLEANFILES+=	config.h auto-host.h tm.h version.h bversion.h

config.h: ${TOOLSGCCBUILD}/config.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

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

version.h: ${TOOLSGCCBUILD}/version.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

bversion.h: ${TOOLSGCCBUILD}/bversion.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

${SRCS:.cc=.d} ${SRCS:.cc=.o}: config.h auto-host.h tm.h version.h bversion.h

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
