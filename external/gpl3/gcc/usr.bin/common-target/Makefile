#	$NetBSD: Makefile,v 1.4 2014/05/31 22:55:17 mrg Exp $

LIBISPRIVATE=	yes

# For ../Makefile.inc and bsd.own.mk
.include <bsd.init.mk>
.include "../Makefile.hostprobes"

LIB=		common-target

SRCS=		prefix.cc opts.cc opts-common.cc options.cc vec.cc \
		hooks.cc common-targhooks.cc hash-table.cc file-find.cc \
		spellcheck.cc selftest.cc opt-suggestions.cc \
		${G_common_out_file:T}

CPPFLAGS+=	-I${GCCARCH} -I${BACKENDOBJ} -I. \
		${G_ALL_CFLAGS:M-D*} ${G_INCLUDES:M-I*:N-I.*} \
		-DPREFIX=\"/usr\" \
		-DDEFAULT_TARGET_VERSION=\"${G_version}\" \
		-DDEFAULT_TARGET_MACHINE=\"${MACHINE_GNU_PLATFORM}\" \
		-DCONFIGURE_SPECS="\"\"" \
		-I${BACKENDOBJ}

TOOLSGCCOBJ!=	cd ${NETBSDSRCDIR}/tools/gcc && ${PRINTOBJDIR}
TOOLSGCCBUILD=	${TOOLSGCCOBJ}/build/gcc
GCC_BASEVER_FILE=	${NETBSDSRCDIR}/external/gpl3/gcc/dist/gcc/BASE-VER

DPSRCS+=	options.h config.h auto-host.h version.h bversion.h
DPSRCS+=	tm.h
.NOPATH:	config.h auto-host.h version.h bversion.h tm.h
CLEANFILES+=	config.h auto-host.h version.h bversion.h tm.h

COPTS.prefix.cc=	-Wno-stack-protector
COPTS.opts-common.cc=	-Wno-stack-protector
CPPFLAGS.prefix.cc+=	-DBASEVER=${BASEVERSTR}

GENPROG_ERROR_DEPENDS=errors.lo

.include "../Makefile.options"
.include "../../Makefile.hooks"

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
		for fn in ${GCC13_TARGET_DECL_FALLBACKS}; do \
			echo "#undef HAVE_$${fn}"; \
			echo "#define HAVE_DECL_$${fn} 0"; \
		done; \
	} >> ${.TARGET}

version.h: ${TOOLSGCCBUILD}/version.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

bversion.h: ${TOOLSGCCBUILD}/bversion.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

tm.h: ${TOOLSGCCBUILD}/tm.h
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

${G_common_out_file:T:R}.o:  common/common-target-hooks-def.h
prefix.d prefix.o: ${GCC_BASEVER_FILE}
opts.d opts.o: version.h bversion.h
${SRCS:.cc=.d} ${SRCS:.cc=.o} ${SRCS:.c=.d} ${SRCS:.c=.o}: config.h auto-host.h tm.h

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
