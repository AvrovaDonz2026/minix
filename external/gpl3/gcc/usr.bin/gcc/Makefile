#	$NetBSD: Makefile,v 1.6 2015/04/17 12:41:46 martin Exp $

PROG=		gcc
SRCS=		gccspec.cc ${G_GCC_OBJS:.o=.cc}

CPPFLAGS+=	-I${BACKENDOBJ}
# GCC13's driver expects the same core driver defines that upstream threads
# through DRIVER_DEFINES in gcc/Makefile.in.
DRIVER_DEFINES= \
		-DSTANDARD_STARTFILE_PREFIX=\"/usr/lib/\" \
		-DSTANDARD_EXEC_PREFIX=\"/usr/libexec/\" \
		-DSTANDARD_LIBEXEC_PREFIX=\"/usr/libexec/\" \
		-DDEFAULT_TARGET_VERSION=\"${G_version}\" \
		-DDEFAULT_REAL_TARGET_MACHINE=\"${MACHINE_GNU_PLATFORM}\" \
		-DDEFAULT_TARGET_MACHINE=\"${MACHINE_GNU_PLATFORM}\" \
		-DSTANDARD_BINDIR_PREFIX=\"/usr/bin\" \
		-DTOOLDIR_BASE_PREFIX=\"../\" \
		-DACCEL_DIR_SUFFIX=\"\" \
		-DENABLE_OFFLOADING=0 \
		-DOFFLOAD_TARGETS=\"\" \
		-DCONFIGURE_SPECS="\"\"" \
		-DNATIVE_SYSTEM_HEADER_DIR=\"/usr/include\"
CPPFLAGS+=	${DRIVER_DEFINES}
CPPFLAGS.gcc.cc+=	-DBASEVER=${BASEVERSTR}

COPTS.builtins.c = -Wno-stack-protector

.if defined(__MINIX) && ${HAVE_LLVM:Uno} == "no"
LINKS+=		${BINDIR}/gcc ${BINDIR}/cc 
.endif # defined(__MINIX) && ${HAVE_LLVM:Uno} == "no"

MAN=		gcc.1
MLINKS=		gcc.1 cc.1 gcc.1 g++.1 gcc.1 c++.1

TEXINFO=	gcc.texi
INFOFLAGS=	-I${DIST}/gcc/doc -I${DIST}/gcc/doc/include

LDADD+=		-lintl
DPADD+=		${LIBINTL}

.include "../Makefile.frontend"

${SRCS}: ${GCCARCH}/defs.mk

.include <bsd.info.mk>

COPTS.gcc.cc=	-Wno-stack-protector
.if ${MACHINE_ARCH} == "vax"
COPTS.dse.c=	-O1
.endif

.PATH: ${DIST}/gcc ${DIST}/gcc/doc ${DIST}/gcc/c

gcc.info: gcc-vers.texi
