#=========================================================================================================#
#                                                                                                         #
#                rmem executable model                                                                    #
#                =====================                                                                    #
#                                                                                                         #
#  This file is:                                                                                          #
#                                                                                                         #
#  Copyright Peter Sewell, University of Cambridge                                            2011-2017   #
#  Copyright Shaked Flur, University of Cambridge                                             2015-2018   #
#  Copyright Jon French, University of Cambridge                                        2015, 2017-2018   #
#  Copyright Pankaj Pawan, IIT Kanpur and INRIA (when this work was done)                          2011   #
#  Copyright Christopher Pulte, University of Cambridge                                       2015-2018   #
#  Copyright Susmit Sarkar, University of St Andrews                               2011-2012, 2014-2015   #
#  Copyright Ohad Kammar, University of Cambridge (when this work was done)                   2013-2014   #
#  Copyright Kathy Gray, University of Cambridge (when this work was done)                   2015, 2017   #
#  Copyright Francesco Zappa Nardelli, INRIA, Paris, France                                        2011   #
#  Copyright Robert Norton-Wright, University of Cambridge                                    2016-2017   #
#  Copyright Luc Maranget, INRIA, Paris, France                                         2011-2012, 2015   #
#  Copyright Sela Mador-Haim, University of Pennsylvania (when this work was done)                 2012   #
#  Copyright Jean Pichon-Pharabod, University of Cambridge                                    2013-2014   #
#  Copyright Gabriel Kerneis, University of Cambridge (when this work was done)                    2014   #
#  Copyright Kayvan Memarian, University of Cambridge                                              2012   #
#                                                                                                         #
#  All rights reserved.                                                                                   #
#                                                                                                         #
#  It is part of the rmem tool, distributed under the 2-clause BSD licence in                             #
#  LICENCE.txt.                                                                                           #
#                                                                                                         #
#=========================================================================================================#

OPAM := $(shell which opam 2> /dev/null)
OCAMLBUILD := $(shell which ocamlbuild 2> /dev/null)
ifeq ($(OCAMLBUILD),)
  $(warning *** cannot find ocamlbuild, please install it or set OCAMLBUILD to point to it)
  OCAMLBUILD := echo "*** cannot find ocamlbuild" >&2 && false
endif



# _OCAMLFIND must match the one ocamlbuild will use, hence the 'override'
override _OCAMLFIND := $(shell $(OCAMLBUILD) -which ocamlfind 2> /dev/null)
# for ocamlc or ocamlopt use '$(_OCAMLFIND) ocamlc' or '$(_OCAMLFIND) ocamlopt'

default:
	$(MAKE) rmem
.PHONY: default
.DEFAULT_GOAL: default

## help: #############################################################

define HELP_MESSAGE
In addition to the dependencies described below, rmem requires OCaml\
4.02.3 or greater and ocamlbuild. The variable OCAMLBUILD can be used\
to set a specific ocamlbuild executable.

make             - same as 'make rmem'
make clean       - remove all the files that were generated by the build process

make rmem [UI={text|web|isabelle|headless}] [MODE={debug|opt|profile|byte}] [ISA=...]
  UI    text - (default) build the text interface; web - build the web interface;
        isabelle - build Isabelle theory files; headless - build the text interface
        without interactive mode (does not require lambda-term).
  MODE  compile to bytecode (debug - default), native (opt) or p.native (profile)
  ISA   comma separated list of ISA models to include ($(ALLISAS)).

make clean_ocaml - 'ocamlbuild -clean'

make clean_install_dir [INSTALLDIR=<path>]     - removes $(INSTALLDIR)
make install_web_interface [INSTALLDIR=<path>] - build the web-interface and install it in $(INSTALLDIR)
make serve [INSTALLDIR=<path>] [PORT=<port>]   - serve the web-interface in $(INSTALLDIR)

make isabelle [ISA=...] - generate theory files for Isabelle (in ./build_isabelle_concurrency_model/)

make sloc_concurrency_model - use sloccount on the .lem files that were used in the last build
endef

help:
	$(info $(HELP_MESSAGE))
	@:
.PHONY: help

## utils: ############################################################
FORCE:
.PHONY: FORCE

# $(call equal,<x>,<y>) expands to 1 if the strings <x> and <y> are
# equivalent, otherwise it expands to the empty string. For example:
# $(if $(call equal,<x>,<y>),echo "equal",echo "not equal")
define _equal
  ifeq "$(1)" "$(2)"
    _equal_res := 1
  else
    _equal_res :=
  endif
endef
equal=$(eval $(call _equal,$(1),$(2)))$(_equal_res)
notequal=$(if $(call equal,$(1),$(2)),,1)

add_ocaml_exts = $(foreach s,.d.byte .byte .native .p.native,$(addsuffix $(s),$(1)))

comma=,
split_on_comma = $(subst $(comma), ,$(1))

# in the recipe of a rule $(call git_version,<the-git-dir>)
# will print OCaml code matching the signature Git from src_top/versions.ml
git_version =\
  { printf -- '(* auto generated by make *)\n\n' &&\
    printf -- '(* git -C $(1) describe --dirty --always --abbrev=0 *)\n' &&\
    printf -- 'let describe : string = {|%s|}\n\n' "$$(git -C $(1) describe --dirty --always --abbrev=0)" &&\
    printf -- '(* git -C $(1) log -1 --format=%%ci *)\n' &&\
    printf -- 'let last_changed : string = {|%s|}\n\n' "$$(git -C $(1) log -1 --format=%ci)" &&\
    printf -- '(* git -C $(1) status -suno *)\n' &&\
    printf -- 'let status : string = {|\n%s|}\n' "$$(git -C $(1) status -suno)";\
  }

######################################################################

MODE=$(if $(call equal,$(UI),web),opt,debug)
.PHONY: MODE
ifeq ($(MODE),debug)
  EXT = d.byte
  JSOCFLAGS=--pretty --no-inline --debug-info --source-map
else ifeq ($(MODE),byte)
  EXT = byte
else ifeq ($(MODE),opt)
  EXT = native
  JSOCFLAGS=--opt 3
else ifeq ($(MODE),profile)
  EXT = p.native
else
  $(error '$(MODE)' is not a valid MODE value, must be one of: opt, profile, debug, byte)
endif

UI=text
.PHONY: UI
ifeq ($(UI),isabelle)
  CONCSENTINEL = build_isabelle_concurrency_model/make_sentinel
else
  CONCSENTINEL = build_concurrency_model/make_sentinel
  ifeq ($(UI),web)
    ifeq ($(MODE),opt)
      EXT = byte
    else ifeq ($(MODE),profile)
      $(error 'profile' is not a valid MODE value when UI=web, must be one of: opt, debug, byte)
    endif
  else ifeq ($(UI),text)
  else ifeq ($(UI),headless)
  else
    $(error '$(UI)' is not a valid UI value, must be one of: text, web, headless, isabelle)
  endif
endif

# the following has an effect only if ISA is not provided on the CLI;
ifneq ($(wildcard $(CONCSENTINEL)),)
  ISA := $(shell cat $(CONCSENTINEL))
else
  ISA := PPCGEN,AArch64,RISCV,X86
endif
.PHONY: ISA

ISA_LIST := $(call split_on_comma,$(ISA))
# make sure the ISAs are valid options, and not empty
ALLISAS = PPCGEN AArch64 MIPS RISCV X86
$(if $(strip $(ISA_LIST)),,$(error ISA cannot be empty, try $(ALLISAS)))
$(foreach i,$(ISA_LIST),$(if $(filter $(i),$(ALLISAS)),,$(error $(i) is not a valid ISA, try $(ALLISAS))))

# if the Lem model was built with a different set of ISAs we force a rebuild
ifneq ($(wildcard $(CONCSENTINEL)),)
  # make_sentinel exists
  ifneq ($(ISA),$(shell cat $(CONCSENTINEL)))
    FORCECONCSENTINEL = FORCE
  endif
endif

show_sentinel_isa:
	@$(if $(wildcard build_concurrency_model/make_sentinel),\
	  printf -- 'OCaml: ISA=%s\n' "$$(cat build_concurrency_model/make_sentinel)",\
	  echo "OCaml: no sentinel")
	@$(if $(wildcard build_isabelle_concurrency_model/make_sentinel),\
	  printf -- 'Isabelle: ISA=%s\n' "$$(cat build_isabelle_concurrency_model/make_sentinel)",\
	  echo "Isabelle: no sentinel")
.PHONY: show_sentinel_isa

## the main executable: ##############################################

OCAMLBUILD_FLAGS += -use-ocamlfind
OCAMLBUILD_FLAGS += -plugin-tag "package(str)"
OCAMLBUILD_FLAGS += -I src_top/$(UI)
# if flambda is supported, perform more optimisation than usual
ifeq ($(MODE),opt)
  ifeq ($(shell $(_OCAMLFIND) ocamlopt -config | grep -q '^flambda:[[:space:]]*true' && echo true),true)
    OCAMLBUILD_FLAGS += -tag 'optimize(3)'
  endif
endif
# this is needed when building on bim and bom:
ifeq ($(shell $(_OCAMLFIND) ocamlopt -flarge-toc > /dev/null 2>&1 && echo true),true)
  OCAMLBUILD_FLAGS += -ocamlopt 'ocamlopt -flarge-toc'
endif

rmem: $(UI)
.PHONY: rmem

ppcmem:
	$(error did you mean rmem? see 'make help')
.PHONY: ppcmem

text:     override UI = text
headless: override UI = headless
text headless:
	$(MAKE) UI=$(UI) get_all_deps
	$(MAKE) UI=$(UI) main
	ln -f -s main.$(EXT) rmem
	@echo "*** DONE: $@ UI=$(UI) MODE=$(MODE) ISA=$(ISA)"
.PHONY: text headless
CLEANFILES += rmem

web: override UI=web
web:
	$(MAKE) UI=$(UI) get_all_deps
	$(MAKE) UI=$(UI) webppc
	$(MAKE) UI=$(UI) system.js
	@echo "*** DONE: web UI=$(UI) MODE=$(MODE) ISA=$(ISA)"
.PHONY: web

isabelle: override UI=isabelle
isabelle:
	$(MAKE) UI=$(UI) get_all_deps
	$(MAKE) UI=$(UI) build_isabelle_concurrency_model/make_sentinel
.PHONY: isabelle

.PHONY: get_all_deps

HIGHLIGHT := $(if $(MAKE_TERMOUT),| scripts/highlight.sh -s)
main webppc: src_top/share_dir.ml version.ml build_concurrency_model/make_sentinel
	rm -f $@.$(EXT)
	ulimit -s 33000; $(OCAMLBUILD) $(OCAMLBUILD_FLAGS) src_top/$@.$(EXT) $(HIGHLIGHT)
#	when piping through the highlight script we lose the exit status
#	of ocamlbuild; check for the target existence instead:
	@[ -f $@.$(EXT) ]
.PHONY: main webppc
CLEANFILES += $(call add_ocaml_exts,main)
CLEANFILES += $(call add_ocaml_exts,webppc)

clean_ocaml:
	$(OCAMLBUILD) -clean
.PHONY: clean_ocaml

version.ml: FORCE
	{ $(call git_version,./) &&\
	  printf -- '\n' &&\
	  printf -- 'let ocaml : string = {|%s|}\n\n' "$$($(_OCAMLFIND) ocamlc -vnum)" &&\
	  printf -- 'let lem : string = {|%s|}\n\n' "$$($(LEM) -v)" &&\
	  printf -- 'let sail_legacy : string = {|%s|}\n\n' "$$(sail-legacy -v)" &&\
	  printf -- 'let sail : string = {|%s|}\n\n' "$$(sail -v)" &&\
	  printf -- 'let libraries : (string * string) list = [\n' &&\
	  $(_OCAMLFIND) query -format '  ({|%p|}, {|%v|});' $(PKGS) &&\
	  printf -- ']\n';\
	} > $@
CLEANFILES += version.ml


# the prerequisite webppc.$(EXT) does not trigger a rebuild of webppc,
# that has to be done manually before updating system.js
system.js: webppc.$(EXT)
	rm -f system.map
	js_of_ocaml $(JSOCFLAGS) +nat.js src_web_interface/web_assets/BigInteger.js src_web_interface/web_assets/zarith.js $< -o $@
CLEANFILES += system.js system.map

clean: clean_ocaml
	rm -f $(CLEANFILES)
	rm -rf $(CLEANDIRS)
.PHONY: clean





## install for opam ##################################################

INSTALL_DIR ?= .
SHARE_DIR ?= share

src_top/share_dir.ml:
	echo "let share_dir = \"$(SHARE_DIR)\"" > src_top/share_dir.ml
CLEANFILES += src_top/share_dir.ml

install: 
	mkdir -p $(INSTALL_DIR)/bin
	mkdir -p $(SHARE_DIR)
	cp rmem $(INSTALL_DIR)/bin


## install the web-interface #########################################

INSTALLDIR = ~/public_html/rmem

# install tests (defines install_<isa>_tests and litmus_library.json)
include web_interface_tests.mk

$(INSTALLDIR):
	mkdir -p $@

# because all the prerequisites are after the | the recipe will execute
# only if the target does not already exist (i.e. if you manually installed
# .htaccess it will not be overwritten)
$(INSTALLDIR)/.htaccess: | $(INSTALLDIR)
	cp src_web_interface/example.htaccess $@

console_help_printer:
	rm -f console_help_printer.native
	$(OCAMLBUILD) $(OCAMLBUILD_FLAGS) src_top/console_help_printer.native
.PHONY: console_help_printer
CLEANFILES += console_help_printer.native

$(INSTALLDIR)/help.html: src_web_interface/help.md console_help_printer.native | $(INSTALLDIR)
	{ echo '<!-- WARNING: AUTOGENERATED FILE; DO NOT EDIT (edit $< instead) -->';\
	  gpp -U "" "" "(" "," ")" "(" ")" "#" "" -M "#" "\n" " " " " "\n" "(" ")" $(if $(or $(call equal,$(origin ANON),undefined),$(call notequal,$(ANON),false)),$(if $(ANON),-D ANON,)) $< | pandoc -f markdown -t html -s --toc --css rmem.css;\
	  echo "<pre><code>";\
	  ./console_help_printer.native;\
	  echo "</code></pre>";\
	} > $@

install_web_interface: web $(INSTALLDIR)
# TODO:	rm -rf $(INSTALLDIR)/*
	cp -r src_web_interface/* $(INSTALLDIR)/
	cp system.js $(INSTALLDIR)
	[ ! -e system.map ] || cp system.map $(INSTALLDIR)
	$(MAKE) console_help_printer
	$(MAKE) $(INSTALLDIR)/help.html
	$(MAKE) $(INSTALLDIR)/.htaccess
	$(MAKE) $(foreach isa,$(ISA_LIST),install_$(isa)_tests)
	$(MAKE) $(INSTALLDIR)/litmus_library.json
.PHONY: install_web_interface

clean_install_dir:
	rm -rf $(INSTALLDIR)
.PHONY: clean_install_dir

serve: PYTHON := $(or $(shell which python3 2> /dev/null),$(shell which python2 2> /dev/null))
serve: PORT=8000
serve:
	@xdg-open "http://127.0.0.1:$(PORT)/index.html" || echo '*** open "http://127.0.0.1:$(PORT)/index.html" in your web-browser'
	$(if $(PYTHON),\
	  cd $(INSTALLDIR) && $(PYTHON) $(realpath scripts/serve.py) $(PORT),\
	  $(error Could not find either python3 or python2 to run simple web server.))
.PHONY: serve



ifeq ($(UI),text)
  OCAMLBUILD_FLAGS += -tag-line '"src_top/main.$(EXT)" : package(lambda-term)'
else ifeq ($(UI),headless)
else ifeq ($(UI),web)
endif


# temporarily
saildir ?= src_sail_legacy
ifeq ($(saildir),)
  saildir = $(error cannot find (the share directory of) the opam package sail-legacy)
endif

sail2dir ?= $(shell opam var sail:share)
ifeq ($(sail2dir),)
  sail2dir = $(error cannot find (the share directory of) the opam package sail)
endif

riscvdir ?= $(shell opam var sail-riscv:share)
ifeq ($(riscvdir),)
  riscvdir = $(error cannot find (the share directory of) the opam package sail-riscv)
endif

lemdir ?= $(shell opam var lem:share)
ifeq ($(lemdir),)
  lemdir = $(error cannot find (the share directory of) the opam package lem)
endif

linksemdir ?= $(shell opam var linksem:share)
ifeq ($(linksemdir),)
  linksemdir = $(error cannot find (the share directory of) the opam package linksem)
endif



## ISA model stubs ###################################################

get_all_deps: isa_model_stubs
isa_model_stubs:
ifeq ($(filter PPCGEN,$(ISA_LIST)),)
  RMEMSTUBS += src_top/PPCGenTransSail.ml
endif
ifeq ($(filter AArch64,$(ISA_LIST)),)
  RMEMSTUBS += src_top/AArch64HGenTransSail.ml
endif
RMEMSTUBS += src_top/AArch64GenTransSail.ml
ifeq ($(filter MIPS,$(ISA_LIST)),)
  RMEMSTUBS += src_top/MIPSHGenTransSail.ml
endif
ifeq ($(filter RISCV,$(ISA_LIST)),)
  RMEMSTUBS += src_top/RISCVHGenTransSail.ml
endif
ifeq ($(filter X86,$(ISA_LIST)),)
  RMEMSTUBS += src_top/X86HGenTransSail.ml
endif
.PHONY: isa_model_stubs

######################################################################

pp2ml:
	rm -f pp2ml.native
	$(OCAMLBUILD) -no-plugin -use-ocamlfind src_top/herd_based/pp2ml.native
.PHONY: pp2ml
get_all_deps: pp2ml
CLEANFILES += $(call add_ocaml_exts,pp2ml)

litmus2xml: get_all_deps
	rm -f litmus2xml.native
	$(OCAMLBUILD) $(OCAMLBUILD_FLAGS) src_top/litmus2xml.native $(HIGHLIGHT)
	@[ -f litmus2xml.native ]
.PHONY: litmus2xml
CLEANFILES += $(call add_ocaml_exts,litmus2xml)

######################################################################

LEM=lem

LEMFLAGS += -only_changed_output
LEMFLAGS += -wl_unused_vars ign
LEMFLAGS += -wl_pat_comp ign
LEMFLAGS += -wl_pat_exh ign
# LEMFLAGS += -wl_pat_fail ign
LEMFLAGS += -wl_comp_message ign
LEMFLAGS += -wl_rename ign

ifeq ($(filter PPCGEN,$(ISA_LIST)),)
  POWER_FILES += src_concurrency_model/isa_stubs/power/power_embed_types.lem
  POWER_FILES += src_concurrency_model/isa_stubs/power/power_embed.lem
  POWER_FILES += src_concurrency_model/isa_stubs/power/powerIsa.lem
else
  POWER_FILES += $(saildir)/arch/power/power_extras_embed.lem
  POWER_FILES += $(saildir)/arch/power/power_embed_types.lem
  POWER_FILES += $(saildir)/arch/power/power_embed.lem
  POWER_FILES += src_concurrency_model/powerIsa.lem
endif

ifeq ($(filter AArch64,$(ISA_LIST)),)
  AARCH64_FILES += src_concurrency_model/isa_stubs/aarch64/armV8_embed_types.lem
  AARCH64_FILES += src_concurrency_model/isa_stubs/aarch64/armV8_embed.lem
  AARCH64_FILES += src_concurrency_model/isa_stubs/aarch64/aarch64Isa.lem
else
  AARCH64_FILES += $(saildir)/arch/arm/armV8_extras_embed.lem
  AARCH64_FILES += $(saildir)/arch/arm/armV8_embed_types.lem
  AARCH64_FILES += $(saildir)/arch/arm/armV8_embed.lem
  AARCH64_FILES += src_concurrency_model/aarch64Isa.lem
endif

ifeq ($(filter MIPS,$(ISA_LIST)),)
  MIPS_FILES += src_concurrency_model/isa_stubs/mips/mips_embed_types.lem
  MIPS_FILES += src_concurrency_model/isa_stubs/mips/mips_embed.lem
  MIPS_FILES += src_concurrency_model/isa_stubs/mips/mipsIsa.lem
else
  MIPS_FILES += $(saildir)/arch/mips/mips_extras_embed.lem
  MIPS_FILES += $(saildir)/arch/mips/mips_embed_types.lem
  MIPS_FILES += $(saildir)/arch/mips/mips_embed.lem
  MIPS_FILES += src_concurrency_model/mipsIsa.lem
endif

ifeq ($(filter RISCV,$(ISA_LIST)),)
  RISCV_FILES += src_concurrency_model/isa_stubs/riscv/riscv_types.lem
  RISCV_FILES += src_concurrency_model/isa_stubs/riscv/riscv.lem
  RISCV_FILES += src_concurrency_model/isa_stubs/riscv/riscvIsa.lem
else
  RISCV_FILES += $(riscvdir)/handwritten_support/0.11/riscv_extras.lem
  RISCV_FILES += $(riscvdir)/handwritten_support/0.11/riscv_extras_fdext.lem
  RISCV_FILES += $(riscvdir)/handwritten_support/0.11/mem_metadata.lem
  RISCV_FILES += $(riscvdir)/generated_definitions/for-rmem/riscv_types.lem
  RISCV_FILES += $(riscvdir)/generated_definitions/for-rmem/riscv.lem
  # FIXME: using '-wl_pat_red ign' is very bad but because riscv.lem is
  # generated by shallow embedding there is not much we can do
  LEMFLAGS += -wl_pat_red ign
  RISCV_FILES += src_concurrency_model/riscvIsa.lem
endif

ifeq ($(filter X86,$(ISA_LIST)),)
  X86_FILES += src_concurrency_model/isa_stubs/x86/x86_embed_types.lem
  X86_FILES += src_concurrency_model/isa_stubs/x86/x86_embed.lem
  X86_FILES += src_concurrency_model/isa_stubs/x86/x86Isa.lem
else
  X86_FILES += $(saildir)/arch/x86/x86_extras_embed.lem
  X86_FILES += $(saildir)/arch/x86/x86_embed_types.lem
  X86_FILES += $(saildir)/arch/x86/x86_embed.lem
  X86_FILES += src_concurrency_model/x86Isa.lem
endif

MACHINEFILES=\
  $(saildir)/src/lem_interp/sail_impl_base.lem\
  $(saildir)/src/gen_lib/sail_values.lem\
  $(saildir)/src/gen_lib/prompt.lem\
  $(sail2dir)/src/gen_lib/sail2_instr_kinds.lem\
  $(sail2dir)/src/gen_lib/sail2_values.lem\
  $(sail2dir)/src/gen_lib/sail2_operators.lem\
  $(sail2dir)/src/gen_lib/sail2_operators_mwords.lem\
  $(sail2dir)/src/gen_lib/sail2_prompt_monad.lem\
  $(sail2dir)/src/gen_lib/sail2_prompt.lem\
  $(sail2dir)/src/gen_lib/sail2_string.lem\
  src_concurrency_model/utils.lem\
  src_concurrency_model/freshIds.lem\
  src_concurrency_model/instructionSemantics.lem\
  src_concurrency_model/exceptionTypes.lem\
  src_concurrency_model/events.lem\
  src_concurrency_model/fragments.lem\
  src_concurrency_model/elfProgMemory.lem\
  src_concurrency_model/isa.lem\
  src_concurrency_model/regUtils.lem\
  src_concurrency_model/uiTypes.lem\
  src_concurrency_model/params.lem\
  src_concurrency_model/dwarfTypes.lem\
  src_concurrency_model/instructionKindPredicates.lem\
  src_concurrency_model/candidateExecution.lem\
  src_concurrency_model/machineDefTypes.lem\
  src_concurrency_model/machineDefUI.lem\
  src_concurrency_model/machineDefPLDI11StorageSubsystem.lem\
  src_concurrency_model/machineDefFlowingStorageSubsystem.lem\
  src_concurrency_model/machineDefFlatStorageSubsystem.lem\
  src_concurrency_model/machineDefPOPStorageSubsystem.lem\
  src_concurrency_model/machineDefTSOStorageSubsystem.lem\
  src_concurrency_model/machineDefThreadSubsystemUtils.lem\
  src_concurrency_model/machineDefThreadSubsystem.lem\
  src_concurrency_model/machineDefSystem.lem\
  src_concurrency_model/machineDefTransitionUtils.lem\
  src_concurrency_model/promisingViews.lem\
  src_concurrency_model/promisingTransitions.lem\
  src_concurrency_model/promisingThread.lem\
  src_concurrency_model/promisingStorageTSS.lem\
  src_concurrency_model/promisingStorage.lem\
  src_concurrency_model/promising.lem\
  src_concurrency_model/promisingDwarf.lem\
  src_concurrency_model/promisingUI.lem

SAIL1_LEM_INPUT_FILES=\
  -i $(saildir)/src/gen_lib/sail_values.lem\
  -i $(saildir)/src/gen_lib/prompt.lem\
  -i $(saildir)/src/lem_interp/sail_impl_base.lem\
  -i src_concurrency_model/isa.lem

SAIL2_LEM_INPUT_FILES=\
  $(SAIL1_LEM_INPUT_FILES)\
  -i $(sail2dir)/src/gen_lib/sail2_instr_kinds.lem\
  -i $(sail2dir)/src/gen_lib/sail2_values.lem\
  -i $(sail2dir)/src/gen_lib/sail2_operators.lem\
  -i $(sail2dir)/src/gen_lib/sail2_operators_mwords.lem\
  -i $(sail2dir)/src/gen_lib/sail2_prompt_monad.lem\
  -i $(sail2dir)/src/gen_lib/sail2_prompt.lem\
  -i $(sail2dir)/src/gen_lib/sail2_string.lem


build_concurrency_model/make_sentinel: $(FORCECONCSENTINEL) $(MACHINEFILES)
	rm -rf $(dir $@)
	mkdir -p $(dir $@)
	$(LEM) $(LEMFLAGS) -outdir $(dir $@) -ocaml $(MACHINEFILES)
	$(LEM) $(LEMFLAGS) $(SAIL2_LEM_INPUT_FILES) -outdir $(dir $@) -ocaml $(RISCV_FILES) src_concurrency_model/sail_1_2_convert.lem
	$(LEM) $(LEMFLAGS) $(SAIL1_LEM_INPUT_FILES) -outdir $(dir $@) -ocaml $(POWER_FILES)
	$(LEM) $(LEMFLAGS) $(SAIL1_LEM_INPUT_FILES) -outdir $(dir $@) -ocaml $(AARCH64_FILES)
	$(LEM) $(LEMFLAGS) $(SAIL1_LEM_INPUT_FILES) -outdir $(dir $@) -ocaml $(MIPS_FILES)
	$(LEM) $(LEMFLAGS) $(SAIL1_LEM_INPUT_FILES) -outdir $(dir $@) -ocaml $(X86_FILES)
	echo '$(ISA)' > $@
CLEANDIRS += build_concurrency_model

######################################################################

build_isabelle_concurrency_model/make_sentinel: $(FORCECONCSENTINEL) $(MACHINEFILES)
	rm -rf $(dir $@)
	mkdir -p $(dir $@)
	$(LEM) $(LEMFLAGS) -outdir $(dir $@) -isa $(MACHINEFILES-ISABELLE)
	echo '$(ISA)' > $@
# 	echo 'session MODEL = "LEM" + theories MachineDefTSOStorageSubsystem MachineDefSystem' > generated_isabelle/ROOT
CLEANDIRS += build_isabelle_concurrency_model

######################################################################

headers_src_concurrency_model:
	@$(foreach FILE, $(shell find src_concurrency_model/ -type f), \
		echo "Processing $(FILE)"; scripts/headache-svn-log.ml $(FILE); \
	)

headers_src_top:
	@$(foreach FILE, $(shell find src_top/ -type f -not -path "src_top/herd_based/*"), \
		echo "Processing $(FILE)"; scripts/headache-svn-log.ml $(FILE); \
	)


headers_src_marshal_defs:
	@$(foreach FILE, $(shell find src_marshal_defs/ -type f), \
		echo "Processing $(FILE)"; scripts/headache-svn-log.ml $(FILE); \
	)

headers_src_web_interface:
	@$(foreach FILE, src_web_interface/index.html \
	     $(shell find src_web_interface/web_assets -maxdepth 1 -type f  \
             -not -path "src_web_interface/web_assets/lib/*" -and \
             -name "*.js" -or -name "*.css" -or -name "*.html"), \
		echo "Processing $(FILE)"; scripts/headache-svn-log.ml $(FILE); \
	)

headers_makefiles:
	@$(foreach FILE, Makefile myocamlbuild.ml web_interface_tests.mk, \
		echo "Processing $(FILE)"; scripts/headache-svn-log.ml $(FILE); \
	)

# headers_scripts:
# 	@$(foreach FILE, $(shell find scripts), \
# 		echo "Processing $(FILE)"; scripts/headache-svn-log.ml $(FILE); \
# 	)

headers: \
headers_src_concurrency_model \
headers_src_top \
headers_src_marshal_defs \
headers_src_web_interface \
headers_makefiles
#headers_scripts \

.PHONY: \
headers_src_concurrency_model \
headers_src_top \
headers_src_marshal_defs \
headers_src_web_interface \
headers_makefiles
# headers_scripts \


######################################################################

sloc_concurrency_model: TEMPDIR=temp_sloc_concurrency_model
sloc_concurrency_model:
	$(if $(wildcard $(CONCSENTINEL)),,$(error "do 'make rmem' first"))
	@rm -rf $(TEMPDIR)
	@mkdir -p $(TEMPDIR)
	@cp $(MACHINEFILES) $(TEMPDIR)
	@for f in $(TEMPDIR)/*.lem; do mv "$$f" "$${f%.lem}.ml"; done
	@sloccount --details $(TEMPDIR) | grep -F '.ml'
	@sloccount $(TEMPDIR) | grep -F 'ml:'
	@echo "*"
	@echo "* NOTE: the .ml files above are actually .lem files that were renamed to fool sloccount"
	@echo "*"
	@rm -rf $(TEMPDIR)
.PHONY: sloc_concurrency_model

sloc_isa_models: ISAs := $(foreach d,$(wildcard build_isa_models/*),$(if $(wildcard $(d)/*.sail),$(notdir $(d))))
sloc_isa_models:
	@$(if $(ISAs),\
	  $(MAKE) --no-print-directory $(addprefix sloc_isa_model_,$(ISAs)),\
	  $(error do 'make rmem' first))
.PHONY: sloc_isa_models

sloc_isa_model_%: TEMPDIR=temp_sloc_isa_model
sloc_isa_model_%: FORCE
	$(if $(wildcard build_isa_models/$*/*.sail),,$(error "do 'make rmem' first"))
	@echo
	@echo '**** ISA model $*: ****'
	@rm -rf $(TEMPDIR)
	@mkdir -p $(TEMPDIR)
	@cp build_isa_models/$*/*.sail $(TEMPDIR)
	@for f in $(TEMPDIR)/*.sail; do mv "$$f" "$${f%.sail}.ml"; done
	@sloccount --details $(TEMPDIR) | grep ml
	@sloccount $(TEMPDIR) | grep -F 'ml:'
	@echo "*"
	@echo "* NOTE: the .ml files above are actually .sail files that were renamed to fool sloccount"
	@echo "*"
	@rm -rf $(TEMPDIR)

######################################################################

jenkins-sanity: sanity.xml
.PHONY: jenkins-sanity

sanity.xml: REGRESSIONDIR = $(REMSDIR)/litmus-tests-regression-machinery
sanity.xml: FORCE
	$(MAKE) -s -C $(REGRESSIONDIR) suite-sanity RMEMDIR=$(CURDIR) ISADRIVERS="shallow" TARGETS=clean-model
	$(MAKE) -s -C $(REGRESSIONDIR) suite-sanity RMEMDIR=$(CURDIR) ISADRIVERS="shallow"
	$(MAKE) -s -C $(REGRESSIONDIR) suite-sanity RMEMDIR=$(CURDIR) ISADRIVERS="shallow" TARGETS=report-junit-testcase > '$@.tmp'
	{ printf '<testsuites>\n' &&\
	  printf '  <testsuite name="sanity" tests="%d" failures="%d" timestamp="%s">\n' "$$(grep -c -F '<testcase name=' '$@.tmp')" "$$(grep -c -F '<error message="fail">' '$@.tmp')" "$$(date)" &&\
	  sed 's/^/    /' '$@.tmp' &&\
	  printf '  </testsuite>\n' &&\
	  printf '</testsuites>\n';\
	} > '$@'
	rm -rf '$@.tmp'

######################################################################

# When %.ml does not exist, myocamlbuild.ml will choose %.ml.notstub or
# %.ml.stub based on the presence of %.ml in $RMEMSTUBS
export RMEMSTUBS
