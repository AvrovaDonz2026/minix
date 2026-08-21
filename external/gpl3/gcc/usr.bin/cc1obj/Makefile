#	$NetBSD: Makefile,v 1.8 2014/05/31 22:55:17 mrg Exp $

# Set NOMAN before Makefile.cc2c pulls bsd.own.mk. See lto1/Makefile.
NOMAN=		# defined

MYOBJS=		${G_OBJC_OBJS} ${G_C_AND_OBJC_OBJS} 
PROG=		cc1obj
SRCS=		${MYOBJS:S,objc/,,:S,c-family/,,:S,c/,,:Nlibcpp.a:.o=.cc} main.cc ${PROG}-checksum.c
.include "../Makefile.cc2c"

CPPFLAGS+=	-I${DIST}/gcc/objc
CPPFLAGS.prefix.cc+=	-DPREFIX=\"/usr\"

.include "../Makefile.backend"
.include "../Makefile.backtrace"
.include "../Makefile.common"
.include "../Makefile.common-target"
.include "../Makefile.libcpp"
.include "../Makefile.libdecnumber"
.include "../Makefile.libiberty"

CHECKSUM_OBJS=	${BACKENDOBJ}/libbackend.a \
		main.o \
		${LIBBACKTRACEOBJ}/libbacktrace.a \
		${COMMONOBJ}/libcommon.a \
		${COMMONTARGETOBJ}/libcommon-target.a \
		${LIBCPPOBJ}/libcpp.a \
		${LIBDECNUMBEROBJ}/libdecnumber.a \
		${LIBIBERTYOBJ}/libiberty.a \
		${MYOBJS:S,objc/,,:S,c-family/,,:S,c/,,} \
		checksum-options

.include "../Makefile.checksum"

# XXX check this out
# LDFLAGS+=	-rdynamic

# VER_CPPFLAGS from Makefile.inc
CPPFLAGS.c-cppbuiltin.cc=	${VER_CPPFLAGS}
CPPFLAGS.c-cppbuiltin.c+=	${CPPFLAGS.c-cppbuiltin.cc}
c-cppbuiltin.cc: ${GCCARCH}/defs.mk
c-cppbuiltin.c: ${GCCARCH}/defs.mk
c-cppbuiltin.d c-cppbuiltin.o: ${BACKENDOBJ}/tm_p.h ${BACKENDOBJ}/configargs.h \
	${BACKENDOBJ}/gt-c-family-c-cppbuiltin.h
.if exists(${DIST}/gcc/config/default-c.cc)
default-c.o: ${DIST}/gcc/config/default-c.cc
.elif exists(${DIST}/gcc/config/default-c.c)
default-c.o: ${DIST}/gcc/config/default-c.c
.endif

COPTS.c-ada-spec.cc+=			-Wno-stack-protector
COPTS.c-aux-info.cc+=			-Wno-stack-protector
COPTS.c-common.cc+=			-Wno-stack-protector
COPTS.c-cppbuiltin.cc+=			-Wno-stack-protector
COPTS.c-format.cc+=			-Wno-stack-protector
COPTS.c-lex.cc+=				-Wno-stack-protector
COPTS.c-ppoutput.cc+=			-Wno-stack-protector
COPTS.c-pragma.cc+=			-Wno-stack-protector
COPTS.c-typeck.cc+=			-Wno-stack-protector
COPTS.objc-act.cc+=			-Wno-stack-protector
COPTS.objc-gnu-runtime-abi-01.cc+=	-Wno-stack-protector
COPTS.objc-next-runtime-abi-01.cc+=	-Wno-stack-protector
.for f in c-ada-spec c-aux-info c-common c-cppbuiltin c-format c-lex \
	c-ppoutput c-pragma c-typeck objc-act objc-gnu-runtime-abi-01 \
	objc-next-runtime-abi-01
COPTS.${f}.c+=				${COPTS.${f}.cc}
.endfor

.if defined(__MINIX)
LDADD+=	${LIBMPC} ${LIBMPFR} ${LIBGMP} -lintl -lz -lm
DPADD+=	${LIBMPC} ${LIBMPFR} ${LIBGMP} ${LIBINTL} ${LIBZ} ${LIBM}
.else
LDADD+=	${LIBMPC} ${LIBMPFR} ${LIBGMP} -lintl -lz -lm
DPADD+=	${LIBMPC} ${LIBMPFR} ${LIBGMP} ${LIBINTL} ${LIBZ} ${LIBM}
.endif # defined(__MINIX)

.PATH: ${DIST}/gcc/objc ${DIST}/gcc/c ${DIST}/gcc/c-family
.PATH: ${DIST}/gcc ${DIST}/gcc/config
.PATH: ${G_out_file:H}
