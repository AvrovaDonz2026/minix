#	$NetBSD: Makefile,v 1.3 2014/05/31 22:55:17 mrg Exp $

LIBISPRIVATE=	yes

# For ../Makefile.inc and bsd.own.mk
.include <bsd.init.mk>
.include "../Makefile.hostprobes"

LIB=		common

SRCS=		diagnostic.cc pretty-print.cc intl.cc input.cc

# XXX make sure this doesn't have more than it needs
CPPFLAGS+=	-I${GCCARCH} -I${BACKENDOBJ} -I. \
		${G_ALL_CFLAGS:M-D*} ${G_INCLUDES:M-I*:N-I.*} \
		-DPREFIX=\"/usr\" \
		-DDEFAULT_TARGET_VERSION=\"${G_version}\" \
		-DDEFAULT_TARGET_MACHINE=\"${MACHINE_GNU_PLATFORM}\" \
		-DCONFIGURE_SPECS="\"\""

DPSRCS+=	config.h auto-host.h version.h bversion.h
.NOPATH:	config.h auto-host.h version.h bversion.h
CLEANFILES+=	config.h auto-host.h version.h bversion.h

MKPIC:=		no
MKPICLIB:=	no

HOSTPROG_CXX=	1

TOOLSGCCOBJ!=	cd ${TOP}/tools/gcc && ${PRINTOBJDIR}
TOOLSGCCBUILD=	${TOOLSGCCOBJ}/build/gcc

COPTS.diagnostic.cc=	-Wno-stack-protector
COPTS.intl.cc=		-Wno-stack-protector

${SRCS}: ${GCCARCH}/defs.mk

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
	} >> ${.TARGET}

version.h: ${TOOLSGCCBUILD}/version.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

bversion.h: ${TOOLSGCCBUILD}/bversion.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

${SRCS:.cc=.d} ${SRCS:.cc=.o}: config.h auto-host.h
diagnostic.d diagnostic.o: version.h bversion.h

.include <bsd.lib.mk>

# Force using C++ for this
HOST_CC:=	${HOST_CXX}
CC:=		${CXX}
CFLAGS:=	${CXXFLAGS}

.PATH: ${DIST}/gcc
