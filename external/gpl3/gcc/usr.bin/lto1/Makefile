#	$NetBSD: Makefile,v 1.2 2015/01/14 20:26:41 tron Exp $

PROG=		lto1
SRCS=		lto-partition.cc lto-object.cc lto.cc lto-lang.cc attribs.cc main.cc
.include "../Makefile.cc2c"

CPPFLAGS+=	-DPREFIX=\"/usr\"

COPTS.lto.cc+=		-Wno-stack-protector
COPTS.lto-lang.cc+=	-Wno-stack-protector
COPTS.lto.c+=		${COPTS.lto.cc}
COPTS.lto-lang.c+=	${COPTS.lto-lang.cc}

.include "../Makefile.backend"
.include "../Makefile.backtrace"
.include "../Makefile.common"
.include "../Makefile.common-target"
.include "../Makefile.libcpp"
.include "../Makefile.libdecnumber"
.include "../Makefile.libiberty"

LDADD+= ${LIBIBERTYOBJ}/libiberty.a
DPADD+= ${LIBIBERTYOBJ}/libiberty.a
LDADD+=	${LIBIBERTY} ${LIBMPC} ${LIBMPFR} ${LIBGMP} -lintl -lz -lm
DPADD+=	${LIBIBERTY} ${LIBMPC} ${LIBMPFR} ${LIBGMP} ${LIBINTL} ${LIBZ} ${LIBM}

.PATH: ${DIST}/gcc/lto  ${DIST}/gcc # ${DIST}/gcc/c ${DIST}/gcc/c-family ${DIST}/gcc/config
.PATH: ${G_out_file:H}
