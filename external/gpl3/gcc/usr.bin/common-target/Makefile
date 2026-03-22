#	$NetBSD: Makefile,v 1.4 2014/05/31 22:55:17 mrg Exp $

LIBISPRIVATE=	yes

# For ../Makefile.inc and bsd.own.mk
.include <bsd.init.mk>

LIB=		common-target

SRCS=		prefix.cc params.c opts.cc opts-common.cc options.c vec.cc \
		hooks.cc common-targhooks.cc hash-table.cc file-find.cc \
		${G_common_out_file:T}

CPPFLAGS+=	-I${GCCARCH} -I${BACKENDOBJ} -I. \
		${G_ALL_CFLAGS:M-D*} ${G_INCLUDES:M-I*:N-I.*} \
		-DPREFIX=\"/usr\" \
		-DDEFAULT_TARGET_VERSION=\"${G_version}\" \
		-DDEFAULT_TARGET_MACHINE=\"${MACHINE_GNU_PLATFORM}\" \
		-DCONFIGURE_SPECS="\"\"" \
		-I${BACKENDOBJ}

COPTS.prefix.cc=	-Wno-stack-protector
COPTS.opts-common.cc=	-Wno-stack-protector
CPPFLAGS.prefix.cc+=	-DBASEVER=${BASEVERSTR}

GENPROG_ERROR_DEPENDS=errors.lo

.include "../Makefile.options"
.include "../../Makefile.hooks"

${SRCS}: ${GCCARCH}/defs.mk

${G_common_out_file:T:R}.o:  common/common-target-hooks-def.h
prefix.d prefix.o: ${GNUHOSTDIST}/gcc/BASE-VER

DPSRCS+=	options.h

HOST_CPPFLAGS+=	-I${BACKENDOBJ} -I${GCCARCH} -I. -I${DIST}/include -I${DIST}/gcc
HOST_CPPFLAGS+=	-DGENERATOR_FILE

MKPIC:=		no
MKPICLIB:=	no

HOSTPROG_CXX=	1

.include <bsd.lib.mk>

# Force using C++ for this
HOST_CC:=	${HOST_CXX}
CC:=		${CXX}
CFLAGS:=	${CXXFLAGS}

.PATH: ${DIST}/gcc ${DIST}/gcc/common
.PATH: ${G_common_out_file:H}
