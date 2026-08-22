#	$NetBSD: Makefile,v 1.6 2014/06/01 19:51:02 mrg Exp $

.include <bsd.own.mk>
.include <bsd.init.mk>

.include "${.CURDIR}/../../arch/${GCC_MACHINE_ARCH}/defs.mk"

.cc: # disable .cc->NULL transform

INCS=
.for _f in ${G_tr1_headers}
.if exists(${DIST}/libstdc++-v3/include/${_f})
INCS+=		${_f}
.endif
.endfor
INCSDIR=	/usr/include/g++/tr1

.include "${.CURDIR}/../Makefile.includes"

# Get default targets including <bsd.inc.mk>.
.include <bsd.prog.mk>

.PATH: ${DIST}/libstdc++-v3/include
