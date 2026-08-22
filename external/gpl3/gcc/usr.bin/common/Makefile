#	$NetBSD: Makefile,v 1.3 2014/05/31 22:55:17 mrg Exp $

LIBISPRIVATE=	yes

# For ../Makefile.inc and bsd.own.mk
.include <bsd.init.mk>
.include "../Makefile.hostprobes"

LIB=		common

# gcc 4.8.5 libcommon is diagnostic.c pretty-print.c intl.c input.c
# version.c. gcc 13 lists .cc names and dropped version.c. Do not use
# Makefile.cc2c here: nightly 32524763481 archived libcommon.a from
# input.o only, then native gcov failed to link fnotice/fancy_abort/
# version_string. Map each basename the same way common-target does.
_COMMON_SRCS=	diagnostic.cc pretty-print.cc intl.cc input.cc version.cc
SRCS=
.for f in ${_COMMON_SRCS}
.if exists(${DIST}/gcc/${f})
SRCS+=		${f}
.elif exists(${DIST}/gcc/${f:S/.cc/.c/})
SRCS+=		${f:S/.cc/.c/}
.endif
.endfor
.if empty(SRCS)
SRCS=		${_COMMON_SRCS}
.endif

# XXX make sure this doesn't have more than it needs
CPPFLAGS+=	-I. -I${GCCARCH} -I${BACKENDOBJ} \
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

TOOLSGCCOBJ!=	cd ${NETBSDSRCDIR}/tools/gcc && ${PRINTOBJDIR}
TOOLSGCCBUILD=	${TOOLSGCCOBJ}/build/gcc

COPTS.diagnostic.cc=	-Wno-stack-protector
COPTS.intl.cc=		-Wno-stack-protector
COPTS.diagnostic.c+=	${COPTS.diagnostic.cc}
COPTS.intl.c+=		${COPTS.intl.cc}
CPPFLAGS.version.c+=	${VER_CPPFLAGS}
CPPFLAGS.version.cc+=	${VER_CPPFLAGS}

${SRCS}: ${GCCARCH}/defs.mk

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

.include "../Makefile.toolsgccfiles"

${SRCS:.cc=.d} ${SRCS:.cc=.o} ${SRCS:.c=.d} ${SRCS:.c=.o}: config.h auto-host.h
diagnostic.d diagnostic.o: version.h bversion.h
version.d version.o: version.h bversion.h

.include <bsd.lib.mk>

# Force using C++ for this
HOST_CC:=	${HOST_CXX}
CC:=		${CXX}
CFLAGS:=	${CXXFLAGS}

.PATH: ${DIST}/gcc
