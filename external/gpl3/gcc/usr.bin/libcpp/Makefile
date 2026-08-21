#	$NetBSD: Makefile,v 1.7 2014/03/05 21:37:02 tron Exp $

LIBISPRIVATE=	yes

# For ../Makefile.inc and bsd.own.mk
.include <bsd.init.mk>

LIB=		cpp

# Hosted packaging fetches gcc 4.8.5. Native SRCS still use gcc 13 .cc
# names from G_libcpp_a_OBJS. Map onto libcpp/*.c when the dist has no .cc.
_LIBCPP_SRCS=
.for f in ${G_libcpp_a_OBJS:.o=.cc}
.if exists(${DIST}/libcpp/${f})
_LIBCPP_SRCS+=	${f}
.elif exists(${DIST}/libcpp/${f:S/.cc/.c/})
_LIBCPP_SRCS+=	${f:S/.cc/.c/}
.endif
.endfor
.if empty(_LIBCPP_SRCS)
SRCS=		${G_libcpp_a_OBJS:.o=.cc}
.else
SRCS=		${_LIBCPP_SRCS}
.endif

CPPFLAGS+=	-I${.CURDIR} -I${.CURDIR}/arch/${GCC_MACHINE_ARCH} \
		-I${GCCARCH} -I${BACKENDOBJ} -I. \
		${G_INCLUDES:M-I*:N-I.*} \
		-DPREFIX=\"/usr\"

HOSTPROG_CXX=	1

.include <bsd.lib.mk>

COPTS+=	-Wno-stack-protector

# Force using C++ for this
HOST_CC:=	${HOST_CXX}
CC:=		${CXX}
CFLAGS:=	${CXXFLAGS}

${OBJS}: ${G_LIBCPP_DEPS}

.PATH: ${DIST}/libcpp
# ${DIST}/gcc

localedir.h:
	echo '#define LOCALEDIR "/usr/share/locale"' > ${.TARGET}
CLEANFILES+= localedir.h

init.d init.o: localedir.h
