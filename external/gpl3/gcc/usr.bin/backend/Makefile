#	$NetBSD: Makefile,v 1.24 2015/02/01 17:47:00 chs Exp $

LIBISPRIVATE=	yes

LIB=		backend

G_OUT_FILE_SRC=	${G_out_file}
.if !exists(${G_out_file}) && exists(${G_out_file:S,.c,.cc,})
G_OUT_FILE_SRC:=	${G_out_file:S,.c,.cc,}
.endif

SRCS=		${G_OBJS} ${G_OUT_FILE_SRC:T}

BOTH_CPPFLAGS+=	-I. -I${GCCARCH} ${G_ALL_CFLAGS:M-D*} ${G_INCLUDES:M-I*:N-I.*}
CPPFLAGS+=	${BOTH_CPPFLAGS} -DTARGET_NAME=\"${MACHINE_GNU_PLATFORM}\"
HOST_CPPFLAGS+=	${BOTH_CPPFLAGS} -DGENERATOR_FILE
DPSRCS+=	insn-attr.h insn-codes.h insn-config.h insn-flags.h insn-modes.h
DPSRCS+=	insn-modes-inline.h tree-check.h auto-host.h pass-instances.def case-cfn-macros.h
DPSRCS+=	bversion.h plugin-version.h configargs.h multilib.h
CPPFLAGS+=	-I${DIST}/libgcc
CPPFLAGS+=	-I${.CURDIR}/../../lib/libgcc/libgcov/arch/${MACHINE_ARCH}

CPPFLAGS.cppdefault.c+=	-DPREFIX=\"/usr\" \
			-DNATIVE_SYSTEM_HEADER_DIR=\"${G_NATIVE_SYSTEM_HEADER_DIR}\"
CPPFLAGS.cppdefault.cc+=	${CPPFLAGS.cppdefault.c}
CPPFLAGS.lto-streamer-in.cc+=	-DTARGET_MACHINE=\"${MACHINE_GNU_PLATFORM}\"

HOSTPROG_CXX=	1

.include "../Makefile.inc"

G_OUT_FILE_SRC=	${G_out_file}
.if !exists(${G_out_file}) && exists(${G_out_file:S,.c,.cc,})
G_OUT_FILE_SRC:=	${G_out_file:S,.c,.cc,}
.endif

# Packaging CI fetches gcc 4.8.5 (gengenrtl.c). riscv64 defs.mk is gcc
# 13.2.0 mknative and lists .cc generators plus gcc13-only objects.
.for _n in gengenrtl gengtype gengtype-lex gengtype-parse gengtype-state \
	genmodes rtl print-rtl bitmap errors ggc-none hash-table sort inchash \
	gensupport read-rtl dummy-conditions vec read-md \
	genattr genattr-common genattrtab genautomata gencodes genconditions \
	genconfig genemit genextract genflags genopinit genoutput genpeep \
	genpreds genrecog genmddump genmddeps genconstants genenums \
	gencheck genchecksum genhooks version
.if exists(${DIST}/gcc/${_n}.cc)
GCC_DIST_SRC.${_n}=	${DIST}/gcc/${_n}.cc
.elif exists(${DIST}/gcc/${_n}.c)
GCC_DIST_SRC.${_n}=	${DIST}/gcc/${_n}.c
.endif
.endfor

# Keep generated insn-* / gtype-desc / options-save; drop objects whose
# .cc/.c is missing from this dist. insn-enums needs genenums (gcc 5+).
# :Minsn-* is :M + insn-*. :Mininsn-* matches ininsn-* and dropped
# every insn-*.o (nightly 32534503524 archived libbackend without them).
GCC_BACKEND_OBJS=
.for o in ${G_OBJS}
_b:=	${o:R}
.if ${_b} == "insn-enums" && !defined(GCC_DIST_SRC.genenums)
# gcc 4.8.5 has no genenums; drop insn-enums.o
.elif ${_b} == "gtype-desc" || ${_b} == "options-save" || !empty(_b:Minsn-*)
GCC_BACKEND_OBJS+=	${o}
.elif exists(${DIST}/gcc/${_b}.cc) || exists(${DIST}/gcc/${_b}.c) || \
      exists(${DIST}/gcc/config/${_b}.cc) || exists(${DIST}/gcc/config/${_b}.c) || \
      exists(${DIST}/gcc/common/${_b}.cc) || exists(${DIST}/gcc/common/${_b}.c) || \
      exists(${G_out_file:H}/${_b}.c) || exists(${G_out_file:H}/${_b}.cc) || \
      exists(${DIST}/libiberty/${_b}.c)
GCC_BACKEND_OBJS+=	${o}
.endif
.endfor
G_OBJS:=	${GCC_BACKEND_OBJS}

# gcc 13 mknative dropped 4.8.5-only backend objects. Add them when
# the dist still has the source (pointer-set, lto-symtab, sched-vis
# dump_insn_slim, dbxout/sdbout/tree-nomudflap GTY, older graphite).
.for _n in pointer-set lto-symtab sched-vis dbxout sdbout tree-nomudflap \
	bt-load loop-unswitch omega regmove tree-optimize \
	tree-ssa-copyrename graphite-blocking graphite-clast-to-gimple \
	graphite-interchange
.if empty(G_OBJS:M${_n}.o)
.if exists(${DIST}/gcc/${_n}.c) || exists(${DIST}/gcc/${_n}.cc)
G_OBJS+=	${_n}.o
.endif
.endif
.endfor

GCC_BACKEND_BUILD_RTL=
.for o in ${G_BUILD_RTL}
_b:=	${o:R}
.if !empty(_b:Mbuild-*) || ${_b} == "min-insn-modes"
GCC_BACKEND_BUILD_RTL+=	${o}
.elif exists(${DIST}/gcc/${_b}.cc) || exists(${DIST}/gcc/${_b}.c)
GCC_BACKEND_BUILD_RTL+=	${o}
.endif
.endfor
G_BUILD_RTL:=	${GCC_BACKEND_BUILD_RTL}

# gcc 13 mknative lists gcc/common.md. gcc 4.8.5 has only the CPU .md.
GCC_MD_FILE=
.for f in ${G_md_file}
.if exists(${f})
GCC_MD_FILE+=	${f}
.endif
.endfor
G_md_file:=	${GCC_MD_FILE}

# Reseed the search path after Makefile.inc so GCCARCH and G_out_file
# contribute their real directories before bsd.lib.mk consumes .depend.
.PATH: ${DIST}/gcc ${DIST}/libiberty ${GCCARCH} ${G_out_file:H} ${DIST}/include
.PATH: ${DIST}/gcc/config
.NOPATH: auto-host.h config.h version.h bversion.h plugin-version.h
.NOPATH: configargs.h multilib.h pass-instances.def case-cfn-macros.h cfn-operators.pd

.include <bsd.lib.mk>
.include "../Makefile.hostprobes"

# Force using C++ for this
ORIGHOST_CC:=	${HOST_CC}
HOST_CC:=	${HOST_CXX}
CC:=		${CXX}
CFLAGS:=	${CXXFLAGS}

# Check PREPROCESSOR_DEFINES for cppbuiltin.c and cppdefault.c
CPPFLAGS.cppbuiltin.c+=	-DBASEVER="\"${BASEVER}"\"
CPPFLAGS.cppbuiltin.cc+=	${CPPFLAGS.cppbuiltin.c}

#
# Independent generation programs.
#
CLEANFILES+=	gengenrtl genrtl.h \
		gengtype gtyp-gen.h \
		genflags genflags.h \
		gencheck tree-check.h \
		insn-preds.c genpreds tm-preds.h tm_p.h cs-tm_p.h \
		genmodes insn-modes.c insn-modes.h min-insn-modes.c \
		insn-modes-inline.h \
		pass-instances.def case-cfn-macros.h cfn-operators.pd \
		auto-host.h build-print-rtl.cc \
		build-rtl.cc build-errors.cc build-varray.c \
		build-bitmap.cc build-ggc-none.cc \
		gt-*.h *.o *.lo \
		version.h bversion.h plugin-version.h configargs.h multilib.h
CLEANFILES+=	config.h

# XXX
COPTS.varasm.c=			-Wno-error

# XXX Override the normal rule to use HOST_COMPILE.cc
.c.lo:
	${_MKTARGET_COMPILE}
	${HOST_COMPILE.cc} -o ${.TARGET}.o ${COPTS.${.IMPSRC:T}} ${CPUFLAGS.${.IMPSRC:T}} ${CPPFLAGS.${.IMPSRC:T}} ${.IMPSRC}
	mv ${.TARGET}.o ${.TARGET}

.cc.lo:
	${_MKTARGET_COMPILE}
	${HOST_COMPILE.cc} -o ${.TARGET}.o ${COPTS.${.IMPSRC:T}} ${CPUFLAGS.${.IMPSRC:T}} ${CPPFLAGS.${.IMPSRC:T}} ${.IMPSRC}
	mv ${.TARGET}.o ${.TARGET}

# Headers that host objects depend on (except gen*rtl*)
G_BUILD_XM_HEADERS=	${G_build_xm_include_list:S,ansidecl.h,${DIST}/include/ansidecl.h,}
HH_NORTL=		${G_tm_file_list} ${G_BUILD_XM_HEADERS}
HH=		${HH_NORTL} genrtl.h insn-modes.h insn-modes-inline.h

TOOLSGCCOBJ!=	cd ${NETBSDSRCDIR}/tools/gcc && ${PRINTOBJDIR}
TOOLSGCCBUILD=	${TOOLSGCCOBJ}/build/gcc
CPPFLAGS+=	-I${TOOLSGCCBUILD}

# GCC13 carries many backend helper prerequisites as bare basenames in the
# generated defs. Canonicalize the source-tree headers here so host helper
# rules do not depend on .PATH continuing to resolve each basename.
GCC13_BACKEND_G_GCC_H_DIST=	gcc.h diagnostic-core.h input.h diagnostic.def
GCC13_BACKEND_G_GCC_H_TOOLS=	version.h bversion.h
GCC13_BACKEND_G_GCC_H=
.for h in ${G_GCC_H}
.if !empty(GCC13_BACKEND_G_GCC_H_DIST:M${h})
GCC13_BACKEND_G_GCC_H:= ${GCC13_BACKEND_G_GCC_H} ${DIST}/gcc/${h}
.elif !empty(GCC13_BACKEND_G_GCC_H_TOOLS:M${h})
.if exists(${TOOLSGCCBUILD}/${h})
GCC13_BACKEND_G_GCC_H:= ${GCC13_BACKEND_G_GCC_H} ${TOOLSGCCBUILD}/${h}
.else
# gcc 4.8.5 tools gcc does not emit these; depend on the local stub.
GCC13_BACKEND_G_GCC_H:= ${GCC13_BACKEND_G_GCC_H} ${h}
.endif
.else
GCC13_BACKEND_G_GCC_H:= ${GCC13_BACKEND_G_GCC_H} ${h}
.endif
.endfor

GCC13_BACKEND_G_RTL_H_DIST=	coretypes.h rtl.h rtl.def machmode.h mode-classes.def
GCC13_BACKEND_G_RTL_H_DIST+=	reg-notes.def insn-notes.def input.h real.h
GCC13_BACKEND_G_RTL_H_DIST+=	statistics.h vec.h ggc.h fixed-value.h
GCC13_BACKEND_G_RTL_H_DIST+=	double-int.h alias.h flags.h flag-types.h
GCC13_BACKEND_G_RTL_H=
.for h in ${G_RTL_H}
.if !empty(GCC13_BACKEND_G_RTL_H_DIST:M${h})
GCC13_BACKEND_G_RTL_H:= ${GCC13_BACKEND_G_RTL_H} ${DIST}/gcc/${h}
.else
GCC13_BACKEND_G_RTL_H:= ${GCC13_BACKEND_G_RTL_H} ${h}
.endif
.endfor

GCC13_BACKEND_G_RTL_BASE_H_DIST=	coretypes.h rtl.h rtl.def machmode.h
GCC13_BACKEND_G_RTL_BASE_H_DIST+=	mode-classes.def reg-notes.def insn-notes.def
GCC13_BACKEND_G_RTL_BASE_H_DIST+=	input.h real.h statistics.h vec.h ggc.h
GCC13_BACKEND_G_RTL_BASE_H_DIST+=	fixed-value.h double-int.h alias.h
GCC13_BACKEND_G_RTL_BASE_H=
.for h in ${G_RTL_BASE_H}
.if !empty(GCC13_BACKEND_G_RTL_BASE_H_DIST:M${h})
GCC13_BACKEND_G_RTL_BASE_H:= ${GCC13_BACKEND_G_RTL_BASE_H} ${DIST}/gcc/${h}
.else
GCC13_BACKEND_G_RTL_BASE_H:= ${GCC13_BACKEND_G_RTL_BASE_H} ${h}
.endif
.endfor

GCC13_BACKEND_G_TREE_H_DIST=	coretypes.h tree.h tree.def machmode.h mode-classes.def
GCC13_BACKEND_G_TREE_H_DIST+=	builtins.def sync-builtins.def omp-builtins.def
GCC13_BACKEND_G_TREE_H_DIST+=	gtm-builtins.def sanitizer.def input.h
GCC13_BACKEND_G_TREE_H_DIST+=	c-family/c-common.def
GCC13_BACKEND_G_TREE_H_DIST+=	statistics.h vec.h ggc.h treestruct.def
GCC13_BACKEND_G_TREE_H_DIST+=	double-int.h alias.h flags.h flag-types.h
GCC13_BACKEND_G_TREE_H_DIST+=	real.h fixed-value.h
GCC13_BACKEND_G_TREE_H_ARCH=	all-tree.def
GCC13_BACKEND_G_TREE_H=
.for h in ${G_TREE_H}
.if !empty(GCC13_BACKEND_G_TREE_H_DIST:M${h})
GCC13_BACKEND_G_TREE_H:= ${GCC13_BACKEND_G_TREE_H} ${DIST}/gcc/${h}
.elif !empty(GCC13_BACKEND_G_TREE_H_ARCH:M${h})
GCC13_BACKEND_G_TREE_H:= ${GCC13_BACKEND_G_TREE_H} ${GCCARCH}/${h}
.else
GCC13_BACKEND_G_TREE_H:= ${GCC13_BACKEND_G_TREE_H} ${h}
.endif
.endfor

GCC13_BACKEND_G_GTM_H_ARCH=	tm.h
GCC13_BACKEND_G_GTM_H=
.for h in ${G_GTM_H}
.if !empty(GCC13_BACKEND_G_GTM_H_ARCH:M${h})
GCC13_BACKEND_G_GTM_H:= ${GCC13_BACKEND_G_GTM_H} ${GCCARCH}/${h}
.else
GCC13_BACKEND_G_GTM_H:= ${GCC13_BACKEND_G_GTM_H} ${h}
.endif
.endfor

GCC13_BACKEND_G_BASIC_BLOCK_H_DIST=	basic-block.h predict.h predict.def
GCC13_BACKEND_G_BASIC_BLOCK_H_DIST+=	vec.h statistics.h ggc.h function.h
GCC13_BACKEND_G_BASIC_BLOCK_H_DIST+=	hard-reg-set.h cfghooks.h machmode.h
GCC13_BACKEND_G_BASIC_BLOCK_H_DIST+=	input.h mode-classes.def cfg-flags.def
GCC13_BACKEND_G_BASIC_BLOCK_H_DIST+=	flag-types.h
GCC13_BACKEND_G_BASIC_BLOCK_H_ARCH=	tm.h
GCC13_BACKEND_G_BASIC_BLOCK_H=
.for h in ${G_BASIC_BLOCK_H}
.if !empty(GCC13_BACKEND_G_BASIC_BLOCK_H_DIST:M${h})
GCC13_BACKEND_G_BASIC_BLOCK_H:= ${GCC13_BACKEND_G_BASIC_BLOCK_H} ${DIST}/gcc/${h}
.elif !empty(GCC13_BACKEND_G_BASIC_BLOCK_H_ARCH:M${h})
GCC13_BACKEND_G_BASIC_BLOCK_H:= ${GCC13_BACKEND_G_BASIC_BLOCK_H} ${GCCARCH}/${h}
.else
GCC13_BACKEND_G_BASIC_BLOCK_H:= ${GCC13_BACKEND_G_BASIC_BLOCK_H} ${h}
.endif
.endfor

GCC13_BACKEND_REGS_H_DIST=	regs.h machmode.h mode-classes.def hard-reg-set.h
GCC13_BACKEND_REGS_H=
.for h in ${REGS_H:U}
.if !empty(GCC13_BACKEND_REGS_H_DIST:M${h})
GCC13_BACKEND_REGS_H:= ${GCC13_BACKEND_REGS_H} ${DIST}/gcc/${h}
.else
GCC13_BACKEND_REGS_H:= ${GCC13_BACKEND_REGS_H} ${h}
.endif
.endfor

GCC13_BACKEND_G_GTFILES=
.for f in ${G_GTFILES}
.if !empty(f:M*.c) && !exists(${f}) && exists(${f:S,.c,.cc,})
GCC13_BACKEND_G_GTFILES:= ${GCC13_BACKEND_G_GTFILES} ${f:S,.c,.cc,}
.elif !empty(f:M*.cc) && !exists(${f}) && exists(${f:S,.cc,.c,})
GCC13_BACKEND_G_GTFILES:= ${GCC13_BACKEND_G_GTFILES} ${f:S,.cc,.c,}
.elif ${f} == ${DIST}/gcc/lto-symtab.c && exists(${DIST}/gcc/lto/lto-symtab.cc)
GCC13_BACKEND_G_GTFILES:= ${GCC13_BACKEND_G_GTFILES} ${DIST}/gcc/lto/lto-symtab.cc
.elif ${f} == ${DIST}/gcc/lto/lto-symtab.cc && exists(${DIST}/gcc/lto-symtab.c)
GCC13_BACKEND_G_GTFILES:= ${GCC13_BACKEND_G_GTFILES} ${DIST}/gcc/lto-symtab.c
.elif !empty(f:M${DIST}/*) && !exists(${f})
.else
GCC13_BACKEND_G_GTFILES:= ${GCC13_BACKEND_G_GTFILES} ${f}
.endif
.endfor
GCC13_BACKEND_G_GTFILES:=	${GCC13_BACKEND_G_GTFILES:S,${DIST}/gcc/../libcpp/include,${DIST}/libcpp/include,g}
GCC13_BACKEND_G_GTFILES:=	${GCC13_BACKEND_G_GTFILES:S,${DIST}/gcc/../include,${DIST}/include,g}
GCC13_BACKEND_G_GTFILES:=	${GCC13_BACKEND_G_GTFILES:S,${G_GT_OUT_FILE},${G_OUT_FILE_SRC},g}
# gcc13 moved GTY struct answer / cpp_macro into cpplib.h and dropped
# cpp-id-data.h. gcc 4.8.5 still defines those types in cpp-id-data.h;
# dropping it makes gengtype -r abort in error_at_line.
.if !exists(${DIST}/libcpp/include/cpp-id-data.h)
GCC13_BACKEND_G_GTFILES:=	${GCC13_BACKEND_G_GTFILES:N${DIST}/libcpp/include/cpp-id-data.h}
.endif
G_GTFILES:=	${GCC13_BACKEND_G_GTFILES}

#
# Generate the various header files we need.
#
# tools gcc config.h errors if GENERATOR_FILE is set (host vs build).
# gcc 4.8.5 hash-table.c includes config.h unconditionally, so generator
# .lo objects abort. Redirect that case to arch bconfig.h (auto-build.h).
config.h: gcc13-config-force ${TOOLSGCCBUILD}/config.h ${.PARSEDIR}/../Makefile.hostprobes
	${_MKTARGET_CREATE}
	rm -f ${.TARGET}
	{ \
		echo '#ifdef GENERATOR_FILE'; \
		echo '#include "bconfig.h"'; \
		echo '#else'; \
		cat ${TOOLSGCCBUILD}/config.h; \
		echo '#ifndef CHECKING_P'; \
		echo '#define CHECKING_P 0'; \
		echo '#endif'; \
		echo '#ifndef ENABLE_OFFLOADING'; \
		echo '#define ENABLE_OFFLOADING 0'; \
		echo '#endif'; \
		echo '#ifndef HAVE_AS_LEB128'; \
		echo '#define HAVE_AS_LEB128 0'; \
		echo '#endif'; \
		echo '#undef HAVE_ZSTD_H'; \
		echo '#endif'; \
	} > ${.TARGET}
.if defined(__MINIX)
# tools gcc config.h is the Linux host (HAVE_MADVISE 1). Native
# ggc-page.c would then call madvise, which MINIX libc lacks
# (nightly 32534503524).
	echo '#undef HAVE_MADVISE' >> ${.TARGET}
.endif

auto-host.h: gcc13-auto-host-force ${TOOLSGCCBUILD}/auto-host.h ${.PARSEDIR}/../Makefile.hostprobes
	${_MKTARGET_CREATE}
	rm -f ${.TARGET}
	cp ${TOOLSGCCBUILD}/auto-host.h ${.TARGET}
	{ \
		for fn in ${GCC13_TARGET_STDIO_UNLOCKED_MISSING}; do \
			echo "#undef HAVE_$${fn}_UNLOCKED"; \
			echo "#undef HAVE_DECL_$${fn}_UNLOCKED"; \
		done; \
		for fn in ${GCC13_TARGET_MALLOC_INFO_MISSING}; do \
			echo "#undef HAVE_$${fn}"; \
			echo "#undef HAVE_DECL_$${fn}"; \
		done; \
		for fn in ${GCC13_TARGET_DECL_FALLBACKS}; do \
			echo "#undef HAVE_$${fn}"; \
			echo "#define HAVE_DECL_$${fn} 0"; \
		done; \
	} >> ${.TARGET}

genrtl.h: gengenrtl
	${_MKTARGET_CREATE}
	./gengenrtl >${.TARGET}
.if defined(GCC_DIST_SRC.gengenrtl)
gengenrtl.lo: ${HH_NORTL} ${GCC_DIST_SRC.gengenrtl}
.endif
gengenrtl: gengenrtl.lo build-errors.lo
	${_MKTARGET_LINK}
	${HOST_LINK.cc} -o ${.TARGET} ${.ALLSRC} ${NBCOMPATLIB} ${HOSTLIBIBERTY}

insn-preds.c: genpreds ${G_md_file}
	${_MKTARGET_CREATE}
	./genpreds ${G_md_file} >${.TARGET}
tm-preds.h: genpreds ${G_md_file}
	${_MKTARGET_CREATE}
	./genpreds -h ${G_md_file} >${.TARGET}
tm-constrs.h: genpreds ${G_md_file}
	${_MKTARGET_CREATE}
	./genpreds -c ${G_md_file} >${.TARGET}

# be nice to generate this entirely; but difficult.
#
# riscv64 gtyp-input.list is gcc13 (.cc names). defs.mk G_GTFILES is the
# 4.8.5 GTFILES list (gimple.c, tree-flow.h, tree-mudflap.c, ...).
# Feeding the .cc list to 4.8.5 gengtype drops every missing .cc, then
# gengtype -r aborts in error_at_line on GTY types whose defining .c
# was never parsed.
.if exists(${DIST}/gcc/gengtype.cc)
gtyp-input.list.tmp: ${GCCARCH}/gtyp-input.list
	{ \
		while IFS= read -r f; do \
			f=$$(printf '%s\n' "$$f" | ${TOOL_SED} \
			    -e 's#SRCDIR#${DIST}#' \
			    -e 's#${G_GT_OUT_FILE}#${G_OUT_FILE_SRC}#' \
			    -e 's#${DIST}/gcc/\\.\\./libcpp/include#${DIST}/libcpp/include#g' \
			    -e 's#${DIST}/gcc/\\.\\./include#${DIST}/include#g' \
			    -e 's#${G_out_file}#${G_OUT_FILE_SRC}#'); \
			case "$$f" in \
			*cpp-id-data.h) continue ;; \
			${DIST}/gcc/lto-symtab.c) if [ -e "${DIST}/gcc/lto/lto-symtab.cc" ]; then f="${DIST}/gcc/lto/lto-symtab.cc"; fi ;; \
			${DIST}/gcc/lto/lto-symtab.cc) if [ ! -e "$$f" ] && [ -e "${DIST}/gcc/lto-symtab.c" ]; then f="${DIST}/gcc/lto-symtab.c"; fi ;; \
			*.cc) if [ ! -e "$$f" ] && [ -e "$${f%.cc}.c" ]; then f="$${f%.cc}.c"; fi ;; \
			*.c) if [ ! -e "$$f" ] && [ -e "$${f%.c}.cc" ]; then f="$${f%.c}.cc"; fi ;; \
			esac; \
			case "$$f" in \
			${DIST}/*) [ -e "$$f" ] || continue ;; \
			esac; \
			printf '%s\n' "$$f"; \
		done < ${.ALLSRC}; \
	} > ${.TARGET}
.else
# .for inside a `{ \' recipe continuation is passed to the shell
# (`sh: .for: not found`). A recipe `printf '%s\n'` is also split by
# make (`\n` becomes a real newline). Echo one G_GTFILES word per line.
gtyp-input.list.tmp: Makefile ${GCCARCH}/defs.mk
	${_MKTARGET_CREATE}
	rm -f ${.TARGET}
.for f in ${G_GTFILES}
	echo '${f}' >> ${.TARGET}
.endfor
.endif
CLEANFILES+=	gtyp-input.list.tmp

.if exists(${DIST}/gcc/gengtype.cc)
GCC13_GTYPE_OUTPUTS= \
		gtype-ada.h gtype-c.h gtype-cp.h gtype-d.h \
		gtype-desc.cc gtype-desc.h gtype-fortran.h gtype-go.h \
		gtype-jit.h gtype-lto.h gtype-m2.h gtype-objc.h \
		gtype-objcp.h gtype-rust.h gtype.state
.else
# gcc 4.8.5 gengtype writes gtype-desc.c and gt-*.h.
GCC13_GTYPE_OUTPUTS= \
		gtype-desc.c gtype-desc.h
.endif
CLEANFILES+=	${GCC13_GTYPE_OUTPUTS} s-gtype
CLEANFILES+=	tm-constrs.h

# GCC13 generates the entire GTY output set from a shared gengtype stamp.
# Modeling only gtype-desc.h leaves the rest of the outputs invisible to make
# and lets parallel object builds race ahead of file generation.
${GCC13_GTYPE_OUTPUTS}: s-gtype ; @true
.if defined(GCC_DIST_SRC.gengtype-state)
s-gtype: gengtype gtyp-input.list.tmp auto-host.h insn-constants.h
	${_MKTARGET_CREATE}
	if [ -f ${.CURDIR}/../gcc/arch/${GCC_MACHINE_ARCH}/sysroot-suffix.h ]; then \
	  rm -f sysroot-suffix.h; \
	  ln -s ${.CURDIR}/../gcc/arch/${GCC_MACHINE_ARCH}/sysroot-suffix.h ; \
	fi
	rm -f tmp-gtype.state
	./gengtype -S ${DIST}/gcc -I gtyp-input.list.tmp -w tmp-gtype.state
	mv -f tmp-gtype.state gtype.state
	./gengtype -r gtype.state
	touch ${.TARGET}
.else
s-gtype: gengtype gtyp-gen.h gtyp-input.list.tmp auto-host.h
	${_MKTARGET_CREATE}
	./gengtype
	touch ${.TARGET}
.endif

# GCC 13 replaced version.o with a generated version.h. gcc 4.8.5
# gengtype still links version.o (version_string, pkgversion_string,
# bug_report_url). 4.8.5 also has gengtype-state.c and uses -S/-I/-w.
.if defined(GCC_DIST_SRC.version)
GENGTYPE_VERSION_LO=	version.lo
version.lo: ${GCC_DIST_SRC.version}
CPPFLAGS.version.c+=	${VER_CPPFLAGS}
CPPFLAGS.version.cc+=	${VER_CPPFLAGS}
.else
GENGTYPE_VERSION_LO=
.endif
.if defined(GCC_DIST_SRC.gengtype)
gengtype.lo: ${HH} gtyp-gen.h config.h options.h version.h ${GCC_DIST_SRC.gengtype}
.endif
.if defined(GCC_DIST_SRC.gengtype-lex)
gengtype-lex.lo: ${HH} gtyp-gen.h config.h options.h version.h ${GCC_DIST_SRC.gengtype-lex}
.endif
.if defined(GCC_DIST_SRC.gengtype-parse)
gengtype-parse.lo: ${HH} gtyp-gen.h config.h options.h version.h ${GCC_DIST_SRC.gengtype-parse}
.endif
.if defined(GCC_DIST_SRC.gengtype-state)
gengtype-state.lo: ${HH} gtyp-gen.h config.h options.h version.h ${GCC_DIST_SRC.gengtype-state}
gengtype: gengtype.lo gengtype-lex.lo gengtype-parse.lo gengtype-state.lo build-errors.lo ${GENGTYPE_VERSION_LO}
	${_MKTARGET_LINK}
	${HOST_LINK.cc} -o ${.TARGET} ${.ALLSRC} ${NBCOMPATLIB} ${HOSTLIBIBERTY}
.else
gengtype: gengtype.lo gengtype-lex.lo gengtype-parse.lo build-errors.lo ${GENGTYPE_VERSION_LO}
	${_MKTARGET_LINK}
	${HOST_LINK.cc} -o ${.TARGET} ${.ALLSRC} ${NBCOMPATLIB} ${HOSTLIBIBERTY}
.endif

gtyp-gen.h: Makefile gtyp-input.list.tmp
	${_MKTARGET_CREATE}
	(\
	unset empty							; \
	echo "static const char *srcdir = \"$(G_GTFILES_SRCDIR)\";"	; \
	echo "static const char *lang_files[] = {"			; \
	awk '/^\[/ { lang = substr($$0, 2, length($$0) - 2); next } lang != "" { printf "\"%s\",\\n", $$0 }' gtyp-input.list.tmp ; \
	echo "NULL };"							; \
	echo "static const char *langs_for_lang_files[] = {"		; \
	awk '/^\[/ { lang = substr($$0, 2, length($$0) - 2); next } lang != "" { printf "\"%s\",\\n", lang }' gtyp-input.list.tmp ; \
	echo "NULL };"							; \
	echo "static const char *all_files[] = {"			; \
	awk '!/^\[/ { printf "\"%s\",\\n", $$0 }' gtyp-input.list.tmp ; \
	echo " NULL };"							; \
	echo "static const char *lang_dir_names[] = {"			; \
	awk '/^\[/ { lang = substr($$0, 2, length($$0) - 2); if (!seen[lang]++) printf "\"%s\",\\n", lang }' gtyp-input.list.tmp ; \
	echo "NULL };"							; \
	) >${.TARGET}

.include "../Makefile.toolsgccfiles"

configargs.h: ${TOOLSGCCBUILD}/configargs.h
	${_MKTARGET_CREATE}
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

multilib.h: ${TOOLSGCCBUILD}/multilib.h
	${_MKTARGET_CREATE}
	rm -f ${.TARGET}
	cp ${.ALLSRC} ${.TARGET}

insn-modes.c: genmodes
	${_MKTARGET_CREATE}
	./genmodes >${.TARGET}
insn-modes.h: genmodes
	${_MKTARGET_CREATE}
	./genmodes -h >${.TARGET}
# gcc 13 genmodes -i writes insn-modes-inline.h. gcc 4.8.5 only
# accepts -h|-m, and machmode.h does not include that header.
.if exists(${DIST}/gcc/genmodes.cc)
insn-modes-inline.h: genmodes
	${_MKTARGET_CREATE}
	./genmodes -i >${.TARGET}
.else
insn-modes-inline.h:
	${_MKTARGET_CREATE}
	rm -f ${.TARGET}
	{ \
		echo '#ifndef GCC_INSN_MODES_INLINE_H'; \
		echo '#define GCC_INSN_MODES_INLINE_H'; \
		echo '#endif'; \
	} > ${.TARGET}
.endif
min-insn-modes.c: genmodes
	${_MKTARGET_CREATE}
	./genmodes -m >${.TARGET}
.if defined(GCC_DIST_SRC.genmodes)
genmodes.lo: ${HH_NORTL} ${GCC_DIST_SRC.genmodes}
.endif
genmodes: genmodes.lo build-errors.lo
	${_MKTARGET_LINK}
	${HOST_LINK.cc} -o ${.TARGET} ${.ALLSRC} ${NBCOMPATLIB} ${HOSTLIBIBERTY}

tm_p.h: Makefile tm-preds.h
	${_MKTARGET_CREATE}
	TARGET_CPU_DEFAULT="" \
	HEADERS="$(G_tm_p_include_list)" DEFINES="" \
	${HOST_SH} ${GNUHOSTDIST}/gcc/mkconfig.sh ${.TARGET}

${G_OBJS} ${G_OBJS:.o=.d}:	tm_p.h		# XXX crude

.include "../Makefile.options"

# Yuck, we have to run configure to generate this one...
# We use ORIGHOST_CC here because GCC's ./configure expects (and
# depends upon) it.
CLEANFILES+=	auto-build.h
HOST_CFLAGS+= -I${.OBJDIR}
auto-build.h: gmp.h Makefile
	${_MKTARGET_CREATE}
	rm -rf .ab && \
	mkdir .ab && \
	(cd .ab && \
		AWK=${TOOL_AWK:Q} \
		CC=${ORIGHOST_CC:Q} CFLAGS=${HOST_CFLAGS:Q} \
		MAKE="${MAKE:Q} -m ${NETBSDSRCDIR}/share/mk" \
		CONFIG_SHELL=${HOST_SH:Q} \
		gcc_cv_ld=${LD} \
		gcc_cv_as=${AS} \
		${HOST_SH} ${GNUHOSTDIST}/gcc/configure \
			--enable-lto \
			--build=`${HOST_SH} ${GNUHOSTDIST}/config.guess` \
			--host=`${HOST_SH} ${GNUHOSTDIST}/config.guess` \
			--target=${MACHINE_GNU_PLATFORM} && \
			mv auto-host.h ../auto-build.h) && \
		rm -rf .ab
.if defined(__MINIX)
	${TOOL_SED} \
		-e 's/^#define HAVE_MADVISE 1$$/#define HAVE_MADVISE 0/' \
		-e 's/^#define HAVE_DECL_BASENAME 0$$/#define HAVE_DECL_BASENAME 1/' \
		-e 's/^#define HAVE_DECL_SBRK 0$$/#define HAVE_DECL_SBRK 1/' \
		-e 's/^#define HAVE_DECL_STRSIGNAL 0$$/#define HAVE_DECL_STRSIGNAL 1/' \
		-e 's/^#define rlim_t long$$/\/\* #undef rlim_t \*\//' \
		-e 's/^#define HAVE_DECL_STRSTR 0$$/#define HAVE_DECL_STRSTR 1/' \
		auto-build.h > auto-build.h.tmp
	mv auto-build.h.tmp auto-build.h
.endif

#
# These are copies of files we build for the build host that are used
# by the genfoo programs.
#

.if defined(GCC_DIST_SRC.rtl)
build-rtl.cc: ${GCC_DIST_SRC.rtl} \
  ${GCC13_BACKEND_G_RTL_H} ${DIST}/gcc/real.h ${GCC13_BACKEND_G_GCC_H} ${DIST}/gcc/errors.h gtype-desc.h
	${_MKTARGET_CREATE}
	rm -f build-rtl.cc
	${TOOL_SED} -e 's/<config[.]h/hconfig.h/' \
		${GCC_DIST_SRC.rtl} >${.TARGET}
build-rtl.lo: ${HH} build-rtl.cc
.endif

.if defined(GCC_DIST_SRC.print-rtl)
build-print-rtl.cc: ${GCC_DIST_SRC.print-rtl} \
  ${GCC13_BACKEND_G_RTL_BASE_H} ${GCC13_BACKEND_G_GTM_H} ${DIST}/gcc/hard-reg-set.h
	${_MKTARGET_CREATE}
	rm -f build-print-rtl.cc
	${TOOL_SED} -e 's/<config[.]h/hconfig.h/' \
		${GCC_DIST_SRC.print-rtl} >${.TARGET}
build-print-rtl.lo: ${HH} build-print-rtl.cc
build/print-rtl.o: ${GCC_DIST_SRC.print-rtl} $(BCONFIG_H) $(SYSTEM_H) ${DIST}/gcc/coretypes.h     \
  ${GCC13_BACKEND_G_GTM_H} ${GCC13_BACKEND_G_RTL_BASE_H}
.endif


.if defined(GCC_DIST_SRC.bitmap)
build-bitmap.cc: ${GCC_DIST_SRC.bitmap} \
  ${GCC13_BACKEND_G_RTL_H} ${DIST}/gcc/flags.h ${GCC13_BACKEND_G_BASIC_BLOCK_H} ${GCC13_BACKEND_REGS_H} ${GCC13_BACKEND_G_GCC_H} gtype-desc.h
	${_MKTARGET_CREATE}
	rm -f build-bitmap.cc
	${TOOL_SED} -e 's/<config[.]h/hconfig.h/' \
		${GCC_DIST_SRC.bitmap} >${.TARGET}
build-bitmap.lo: ${HH} build-bitmap.cc
.endif

.if defined(GCC_DIST_SRC.errors)
build-errors.cc: ${GCC_DIST_SRC.errors} ${DIST}/gcc/errors.h
	${_MKTARGET_CREATE}
	rm -f build-errors.cc
	cat ${GCC_DIST_SRC.errors} >${.TARGET}
build-errors.lo: ${HH_NORTL} build-errors.cc
.endif

build-varray.c: ${DIST}/gcc/varray.c \
  ${GCC13_BACKEND_G_RTL_H} ${GCC13_BACKEND_G_GCC_H} ${GCC13_BACKEND_G_TREE_H} ${DIST}/gcc/bitmap.h ${DIST}/gcc/errors.h
	${_MKTARGET_CREATE}
	rm -f build-varray.c
	${TOOL_SED} -e 's/<config[.]h/hconfig.h/' \
		${GNUHOSTDIST}/gcc/varray.c >${.TARGET}
build-varray.lo: ${HH} gtype-desc.h build-varray.c

.if defined(GCC_DIST_SRC.ggc-none)
build-ggc-none.cc: ${GCC_DIST_SRC.ggc-none} \
  ${GCC13_BACKEND_G_GCC_H} gtype-desc.h
	${_MKTARGET_CREATE}
	rm -f build-ggc-none.cc
	${TOOL_SED} -e 's/<config[.]h/hconfig.h/' \
		${GCC_DIST_SRC.ggc-none} >${.TARGET}
build-ggc-none.lo: ${HH} build-ggc-none.cc
.endif

.if defined(GCC_DIST_SRC.hash-table)
hash-table.lo: ${HH} ${GCC_DIST_SRC.hash-table} gtype-desc.h
.endif
.if defined(GCC_DIST_SRC.sort)
sort.lo: ${HH_NORTL} ${GCC_DIST_SRC.sort}
.endif
.if defined(GCC_DIST_SRC.inchash)
inchash.lo: ${HH} ${GCC_DIST_SRC.inchash}
.endif

#
# The normal insn-foo generators
#
.for f in gensupport read-rtl dummy-conditions
.if defined(GCC_DIST_SRC.${f})
${f}.lo: ${HH} ${GCC_DIST_SRC.${f}} gtype-desc.h
.endif
.endfor

#
# There are 5 main classes of generator programs.  Ones
# that are self contained, ones that use error reporting
# mechanisms, ones that use the MD reader, and ones that
# use the RTL reader.
#
GENPROG_ERROR_DEPENDS=	${G_BUILD_ERRORS:.o=.lo}
GENPROG_READER_DEPENDS=	${G_BUILD_MD:.o=.lo} ${GENPROG_ERROR_DEPENDS}
GENPROG_RTL_DEPENDS=	${G_BUILD_RTL:.o=.lo} ${GENPROG_READER_DEPENDS} ${GENPROG_ERROR_DEPENDS}

#
# First we generate the rules for the generators.
#
.for f in attr attr-common attrtab automata codes conditions config emit \
	  extract flags opinit output peep preds recog mddump
.if defined(GCC_DIST_SRC.gen${f})
gen${f}.lo: ${HH} ${GCC_DIST_SRC.gen${f}} gtype-desc.h
gen${f}: gen${f}.lo ${GENPROG_RTL_DEPENDS} 
	${_MKTARGET_LINK}
	${HOST_LINK.cc} -o ${.TARGET} ${.ALLSRC} ${NBCOMPATLIB} ${HOSTLIBIBERTY} ${LDFLAGS.${.TARGET}}
CLEANFILES+=	gen${f} gen${f}.lo
.endif
.endfor

.for f in mddeps constants enums
.if defined(GCC_DIST_SRC.gen${f})
gen${f}.lo: ${HH} ${GCC_DIST_SRC.gen${f}}
gen${f}: gen${f}.lo ${GENPROG_READER_DEPENDS} 
	${_MKTARGET_LINK}
	${HOST_LINK.cc} -o ${.TARGET} ${.ALLSRC} ${NBCOMPATLIB} ${HOSTLIBIBERTY} ${LDFLAGS.${.TARGET}}
CLEANFILES+=	gen${f} gen${f}.lo
.endif
.endfor

.for f in check checksum
.if defined(GCC_DIST_SRC.gen${f})
gen${f}.lo: ${HH} ${GCC_DIST_SRC.gen${f}} gtype-desc.h
gen${f}: gen${f}.lo
	${_MKTARGET_LINK}
	${HOST_LINK.cc} -o ${.TARGET} ${.ALLSRC} ${NBCOMPATLIB} ${HOSTLIBIBERTY} ${LDFLAGS.${.TARGET}}
CLEANFILES+=	gen${f} gen${f}.lo
.endif
.endfor

.include "../../Makefile.hooks"

#
# Second we generate the rules for the generated files.  There
# are 3 main classes:  RTL based or not, plus special cases.
#
# The special cases are:  gencheck, genattrtab, genopinit,
# gencondmd
#

# RTL based files
.for f in attr.h attr-common.h codes.h config.h flags.h \
	  automata.c emit.c extract.c output.c peep.c recog.c
.if defined(GCC_DIST_SRC.gen${f:R})
insn-${f}: gen${f:R} ${G_md_file} insn-conditions.md
	${_MKTARGET_CREATE}
	./gen${f:R} ${G_md_file} insn-conditions.md >${.TARGET}
CLEANFILES+=	insn-${f}
.endif
.endfor

# normal files
.for f in constants.h enums.c
.if defined(GCC_DIST_SRC.gen${f:R})
insn-${f}: gen${f:R} ${G_md_file}
	${_MKTARGET_CREATE}
	./gen${f:R} ${G_md_file} >${.TARGET}
CLEANFILES+=	insn-${f}
.endif
.endfor

# genconditions outputs gencondmd.cc
gencondmd.cc: genconditions ${G_md_file}
	${_MKTARGET_CREATE}
	./genconditions ${G_md_file} >${.TARGET}
CLEANFILES+=	gencondmd.cc

gencondmd.lo: ${HH} gencondmd.cc tm_p.h tm-constrs.h insn-constants.h
gencondmd: gencondmd.lo build-errors.lo
	${_MKTARGET_LINK}
	${HOST_LINK.cc} -o ${.TARGET} ${.ALLSRC} ${NBCOMPATLIB} ${HOSTLIBIBERTY} ${LDFLAGS.${.TARGET}}
CLEANFILES+=	gencondmd gencondmd.lo

# gencheck outputs tree-check.h
tree-check.h: gencheck
	${_MKTARGET_CREATE}
	./gencheck >${.TARGET}
CLEANFILES+=	tree-check.h

# Some generators output is not the normal name.
BUILDSYMLINKS+= insn-check.h tree-check.h

# genattrtab has three output files
# XXX fix me
insn-attrtab.c insn-dfatab.c insn-latencytab.c: genattrtab ${G_md_file} insn-conditions.md 
	${_MKTARGET_CREATE}
	./genattrtab ${G_md_file} insn-conditions.md -Ainsn-attrtab.c -Dinsn-dfatab.c -Linsn-latencytab.c
CLEANFILES+=	insn-attrtab.c insn-dfatab.c insn-latencytab.c

# genopinit has two output files
insn-opinit.c insn-opinit.h: genopinit ${G_md_file} insn-conditions.md
	${_MKTARGET_CREATE}
	./genopinit ${G_md_file} insn-conditions.md -hinsn-opinit.h -cinsn-opinit.c
CLEANFILES+=	insn-opinit.h insn-opinit.c

LDFLAGS.genautomata+=	-lm

# gencondmd outputs a special .md file
insn-conditions.md: gencondmd
	./gencondmd >${.TARGET}
CLEANFILES+=	insn-conditions.md 


#
# Required hard-coded dependancies.
#
genextract.lo: insn-config.h
read-rtl.lo gencodes.lo genattrtab.lo genautomata.lo: insn-constants.h
genattr-common.lo gensupport.lo genconditions.lo: insn-constants.h
genattr.lo genflags.lo genemit.lo genconfig.lo gencheck.lo: insn-constants.h
genopinit.lo genrecog.lo genpreds.lo genoutput.lo genpeep.lo: insn-constants.h
build-ggc-none.lo: gtype-desc.h
ggc-none.o: gtype-desc.h

insn-attrtab.o: insn-config.h
insn-extract.o: insn-config.h
toplev.d toplev.o: options.h
coverage.d: gcov-io.h
gcov-io.h: version.h
alias.d alias.o: insn-constants.h tm_p.h
cgraph.d cgraphunit.d cgraphunit.o: gcov-io.h
vec.lo: gtype-desc.h
gtype-desc.d gtype-desc.o: s-gtype insn-constants.h
insn-emit.d insn-emit.o: tm-constrs.h
.if defined(GCC_DIST_SRC.genattr-common)
insn-attr.h: insn-attr-common.h
.endif
asan.d asan.o: insn-opinit.h
data-streamer.d data-streamer-out.d coverage.d gcov-dump.d gcov-io.d gcov-iov.d gcov.d libgcov.d lto-cgraph.d mcf.d modulo-sched.d profile.d value-prof.d: gcov-io.h
data-streamer.o data-streamer-out.o coverage.o gcov-dump.o gcov-io.o gcov-iov.o gcov.o libgcov.o lto-cgraph.o mcf.o modulo-sched.o profile.o value-prof.o: gcov-io.h
gcov-io.h: version.h
df-scan.d df-scan.o: target-hooks-def.h
read-md.d read-md.o read-md.lo: auto-build.h insn-modes.h insn-modes-inline.h

# XXX make all hooks generated for now.
final.o: target-hooks-def.h c-family/c-target-hooks-def.h common/common-target-hooks-def.h

.if ${GCC_MACHINE_ARCH} == "alpha"
alpha.d alpha.o: tm-constrs.h tm_p.h insn-opinit.h target-hooks-def.h
.endif

.if ${MACHINE_CPU} == "arm"
arm.d arm.o: insn-constants.h tm_p.h insn-opinit.h target-hooks-def.h
.endif

.if ${GCC_MACHINE_ARCH} == "i386" || ${GCC_MACHINE_ARCH} == "x86_64"
i386.d i386.o: tm-constrs.h
.endif

.if ${GCC_MACHINE_ARCH} == "vax"
CPPFLAGS+=-I${.CURDIR}/../../lib/libgcc/libgcov/arch/${GCC_MACHINE_ARCH}
COPTS.expmed.c=-O0
COPTS.recog.c=-O0
.endif

CFLAGS+=	-Wno-stack-protector

.if ${GCC_MACHINE_ARCH} == "m68000" || ${GCC_MACHINE_ARCH} == "m68k" || \
	${GCC_MACHINE_ARCH} == "coldfire"
COPTS.tree-loop-distribution.c=	-O2
.endif

COPTS.tree.c=	${${ACTIVE_CC} == "clang" :? -O0 :}

.PATH: ${DIST}/gcc ${DIST}/libiberty ${GCCARCH} ${G_out_file:H} ${DIST}/include
.PATH: ${DIST}/gcc/config
