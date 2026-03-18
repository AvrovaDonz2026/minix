HOSTPROGNAME=	${_TOOL_PREFIX}mkfs.mfs
HOST_SRCDIR=	minix/usr.sbin/mkfs.mfs/v3

CPPFLAGS.mkfs.c+=	-U__minix -U__minix__ -U__riscv64 -U__riscv64__

.include "${.CURDIR}/../Makefile.host"
