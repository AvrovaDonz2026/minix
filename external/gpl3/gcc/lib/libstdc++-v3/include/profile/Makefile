#	$NetBSD: Makefile,v 1.2 2014/06/01 20:24:45 mrg Exp $

.include <bsd.init.mk>

.include "${.CURDIR}/../../arch/${GCC_MACHINE_ARCH}/defs.mk"

.cc: # disable .cc->NULL transform

DIST=		${GCCDIST}
GNUHOSTDIST=	${DIST}

INCS=
.for _f in ${G_profile_headers} ${G_profile_impl_headers}
.if exists(${DIST}/libstdc++-v3/include/profile/${_f}) || \
    exists(${DIST}/libstdc++-v3/include/${_f})
INCS+=		${_f}
.endif
.endfor
INCSDIR=	/usr/include/g++/profile

.include "${.CURDIR}/../Makefile.includes"

.PATH: ${DIST}/libstdc++-v3/include/profile

# Get default targets including <bsd.inc.mk>.
.include <bsd.prog.mk>
