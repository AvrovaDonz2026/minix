#	$NetBSD: link.mk,v 1.5 2013/09/29 12:11:59 joerg Exp $

.include <bsd.own.mk>

.if defined(HOSTPROG)
LIB_BASE=	${NETBSDSRCDIR}/tools/llvm-lib
.else
LIB_BASE=	${LLVM_TOPLEVEL}/lib
.endif

.for l in ${MCLINKER_LIBS}
MCLINKER_OBJDIR.${l}!=	cd ${LIB_BASE}/libMCLinker${l} && ${PRINTOBJDIR}
LDADD+=	-L${MCLINKER_OBJDIR.${l}} -lMCLinker${l}
DPADD+=	${MCLINKER_OBJDIR.${l}}/libMCLinker${l}.a
.endfor

.for l in ${LLDB_LIBS}
LLDB_OBJDIR.${l}!=	cd ${LIB_BASE}/liblldb${l} && ${PRINTOBJDIR}
LDADD+=	-L${LLDB_OBJDIR.${l}} -llldb${l}
DPADD+=	${LLDB_OBJDIR.${l}}/liblldb${l}.a
.endfor

.for l in ${CLANG_LIBS}
CLANG_OBJDIR.${l}!=	cd ${LIB_BASE}/lib${l} && ${PRINTOBJDIR}
LDADD+=	-L${CLANG_OBJDIR.${l}} -l${l}
DPADD+=	${CLANG_OBJDIR.${l}}/lib${l}.a
.endfor

.for l in ${LLD_LIBS}
LLD_OBJDIR.${l}!=	cd ${LIB_BASE}/lib${l} && ${PRINTOBJDIR}
LDADD+=	-L${LLD_OBJDIR.${l}} -l${l}
DPADD+=	${LLD_OBJDIR.${l}}/lib${l}.a
.endfor

.for l in ${LLVM_LIBS}
LLVM_OBJDIR.${l}!=	cd ${LIB_BASE}/libLLVM${l} && ${PRINTOBJDIR}
LDADD+=	-L${LLVM_OBJDIR.${l}} -lLLVM${l}
DPADD+=	${LLVM_OBJDIR.${l}}/libLLVM${l}.a
.endfor

.if defined(HOSTPROG)
LDADD_NEED_DL=		cat ${LLVM_TOOLCONF_OBJDIR}/need-dl 2> /dev/null
LDADD_NEED_TERMINFO=	cat ${LLVM_TOOLCONF_OBJDIR}/need-terminfo 2> /dev/null
LDADD+=	${LDADD_NEED_DL:sh} ${LDADD_NEED_TERMINFO:sh}
.else
LDADD+=	-lterminfo
DPADD+=	${LIBTERMINFO}
.endif

.if defined(__MINIX) && defined(HOSTPROG) && ${HOST_OSTYPE:C/\-.*//} != "Minix"
LDADD+=	-lpthread
.else
.if defined(__MINIX) && !defined(HOSTPROG) && ${MKLIBCXX:Uno} == "no"
# riscv64 keeps MKLIBCXX=no; guest LLVM links against libstdc++.
# Pull libstdc++/libgcc into the main image (avoid libstdc++ COPY / dual
# empty_rep).  Keep libc and friends dynamic (PT_INTERP).  Do not use
# LDSTATIC.clang=-static (merges to -dynamic -static and bloats the link).
# Stop the g++ driver from appending -lstdc++ after our static link.
LDFLAGS+=	-nodefaultlibs
LDFLAGS+=	-static-libgcc
LDFLAGS+=	-Wl,-z,now
LDADD+=	-Wl,-Bstatic -lstdc++ -lgcc -Wl,-Bdynamic -lc -lm
.else
LDADD+= -lc++ -lmthread
.endif
.endif # defined(__MINIX)
