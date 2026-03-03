#	$NetBSD: Makefile,v 1.2 2014/06/01 20:24:45 mrg Exp $

.include <bsd.init.mk>

.include "${.CURDIR}/../../arch/${GCC_MACHINE_ARCH}/defs.mk"

.cc: # disable .cc->NULL transform

DIST=		${GCCDIST}
GNUHOSTDIST=	${DIST}

INCS=
.for _f in ${G_pb_headers1} ${G_pb_headers2} ${G_pb_headers3} ${G_pb_headers4} \
    ${G_pb_headers5} ${G_pb_headers6} ${G_pb_headers7}
.if exists(${DIST}/libstdc++-v3/include/${_f})
INCS+=		${_f}
.endif
.endfor
INCSDIR=	/usr/include/g++

.PATH:	${DIST}/libstdc++-v3/include

# Get default targets including <bsd.inc.mk>.
.include <bsd.prog.mk>
