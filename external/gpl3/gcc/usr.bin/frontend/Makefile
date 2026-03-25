#	$NetBSD: Makefile,v 1.9 2015/01/07 02:05:41 christos Exp $

LIBISPRIVATE=	yes

# For ../Makefile.inc and bsd.own.mk
.include <bsd.init.mk>
.include "../Makefile.hostprobes"

LIB=		frontend

SRCS=		gcc.cc prefix.cc

HOSTPROG_CXX=	1

# XXX
.if ${GCC_MACHINE_ARCH} == "x86_64" || ${GCC_MACHINE_ARCH} == "i386"
	SRCS+=		driver-i386.cc
.PATH:		${DIST}/gcc/config/i386
.endif
.if ${GCC_MACHINE_ARCH} == "powerpc" || ${GCC_MACHINE_ARCH} == "powerpc64"
	SRCS+=		driver-rs6000.cc
.PATH:		${DIST}/gcc/config/rs6000
.endif

CPPFLAGS+=	-I${GCCARCH} -I${BACKENDOBJ} -I. \
		${G_ALL_CFLAGS:M-D*} ${G_INCLUDES:M-I*:N-I.*} \
		-DPREFIX=\"/usr\" \
		-DDEFAULT_TARGET_VERSION=\"${G_version}\" \
		-DDEFAULT_TARGET_MACHINE=\"${MACHINE_GNU_PLATFORM}\" \
		-DCONFIGURE_SPECS="\"\""
HOST_CPPFLAGS+=	-I${GCCARCH} ${G_ALL_CFLAGS:M-D*} ${G_INCLUDES:M-I*:N-I.*}

TOOLSGCCOBJ!=	cd ${NETBSDSRCDIR}/tools/gcc && ${PRINTOBJDIR}
TOOLSGCCBUILD=	${TOOLSGCCOBJ}/build/gcc

DPSRCS+=	config.h auto-host.h tm.h options.h version.h bversion.h configargs.h specs.h
.NOPATH:	config.h auto-host.h tm.h options.h version.h bversion.h configargs.h specs.h
CLEANFILES+=	config.h auto-host.h tm.h options.h version.h bversion.h configargs.h specs.h

FRONTEND_DRIVER_DEFINES= \
		-DDEFAULT_REAL_TARGET_MACHINE=\"${MACHINE_GNU_PLATFORM}\" \
		-DSTANDARD_LIBEXEC_PREFIX=\"/usr/libexec/\" \
		-DSTANDARD_BINDIR_PREFIX=\"/usr/bin\" \
		-DTOOLDIR_BASE_PREFIX=\"../\" \
		-DACCEL_DIR_SUFFIX=\"\" \
		-DENABLE_OFFLOADING=0 \
		-DOFFLOAD_TARGETS=\"\"

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

options.h: ${TOOLSGCCBUILD}/options.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

configargs.h: ${TOOLSGCCBUILD}/configargs.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

version.h: ${TOOLSGCCBUILD}/version.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

bversion.h: ${TOOLSGCCBUILD}/bversion.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

specs.h: ${TOOLSGCCBUILD}/specs.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

CPPFLAGS.gcc.cc+=	${FRONTEND_DRIVER_DEFINES} -DBASEVER=${BASEVERSTR}
CPPFLAGS.prefix.cc+=	-DBASEVER=${BASEVERSTR}

${SRCS:.cc=.d} ${SRCS:.cc=.o}: config.h auto-host.h tm.h options.h configargs.h
gcc.d gcc.o: specs.h ${GNUHOSTDIST}/gcc/BASE-VER
prefix.d prefix.o: ${GNUHOSTDIST}/gcc/BASE-VER

${SRCS}: ${GCCARCH}/defs.mk

MKPIC:=		no
MKPICLIB:=	no

# Force using C++ for this
HOST_CC:=	${HOST_CXX}
CC:=		${CXX}
CFLAGS:=	${CXXFLAGS}

CFLAGS+=	-Wno-stack-protector

# XXX print-objdir fix me
CPPFLAGS+=	-I../backend

.PATH: ${DIST}/gcc ${DIST}/gcc/common

.include <bsd.lib.mk>
