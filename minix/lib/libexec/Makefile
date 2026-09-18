# Makefile for libexec

LIB=	exec
INCS=	libexec.h
SRCS=	exec_elf.c exec_general.c

INCSDIR= /usr/include

.include <bsd.lib.mk>

# Prefer in-tree libexec.h over a stale ${DESTDIR}/usr/include copy.
CPPFLAGS:= -I${.CURDIR} ${CPPFLAGS}
