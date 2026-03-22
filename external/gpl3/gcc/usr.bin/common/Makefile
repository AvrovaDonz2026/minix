#	$NetBSD: Makefile,v 1.3 2014/05/31 22:55:17 mrg Exp $

LIBISPRIVATE=	yes

# For ../Makefile.inc and bsd.own.mk
.include <bsd.init.mk>

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

COPTS.diagnostic.cc=	-Wno-stack-protector
COPTS.intl.cc=		-Wno-stack-protector

${SRCS}: ${GCCARCH}/defs.mk

config.h: ${BACKENDOBJ}/config.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

auto-host.h: ${BACKENDOBJ}/auto-host.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

version.h: ${BACKENDOBJ}/version.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

bversion.h: ${BACKENDOBJ}/bversion.h
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
