#	$NetBSD: Makefile,v 1.9 2014/06/01 19:51:01 mrg Exp $

SUBDIR=		backward ext bits debug decimal parallel pb profile
SUBDIR+=	tr1 tr2

.include <bsd.init.mk>
.include <bsd.own.mk>

.include "${.CURDIR}/../arch/${GCC_MACHINE_ARCH}/defs.mk"

.cc: # disable .cc->NULL transform

DIST=		${GCCDIST}
GNUHOSTDIST=	${DIST}

# libsupc++. Packaging CI fetches gcc 4.8.5; gcc13-only names such as
# compare must not be required when the dist snapshot does not ship them.
_LIBSUPCXX_INCS=	exception new typeinfo cxxabi.h initializer_list compare
INCS=
.for f in ${_LIBSUPCXX_INCS}
.if exists(${DIST}/libstdc++-v3/libsupc++/${f})
INCS+=		${f}
.endif
.endfor

# others
INCS+=		cerrno
.for f in ${G_std_headers} ${G_c_base_headers} ${G_c_compatibility_headers_extra}
.if exists(${DIST}/libstdc++-v3/include/std/${f}) || \
    exists(${DIST}/libstdc++-v3/include/c_global/${f}) || \
    exists(${DIST}/libstdc++-v3/include/c_compatibility/${f}) || \
    exists(${DIST}/libstdc++-v3/${f})
INCS+=		${f}
.endif
.endfor
INCSDIR=	/usr/include/g++

.include "${.CURDIR}/Makefile.includes"

.PATH: ${DIST}/libstdc++-v3
.PATH: ${DIST}/libstdc++-v3/libsupc++
#.PATH: ${DIST}/libstdc++-v3/include/c_compatibility
.PATH: ${DIST}/libstdc++-v3/include/c_global
.PATH: ${DIST}/libstdc++-v3/include/std

# Get default targets including <bsd.inc.mk>.
.include <bsd.prog.mk>
.include <bsd.subdir.mk>
