# Package level makefile
# ----------------------
#Makefile:;

# Symbols
# -------
SHELL := /bin/bash
RM    := rm -f
MV    := mv -f
empty :=
space := $(empty) $(empty)

pkg_name := $(notdir $(shell pwd))

RELEASE_DIR := $(PWD)
build_dir := ${RELEASE_DIR}/build

# Defines which directories are being created by this makefile
incdir  := $(INSTALLDIR)/include/${pkg_name}
libdir  := $(build_dir)/lib
bindir  := $(build_dir)/bin
objdir  := $(build_dir)/obj/${pkg_name}

prod_dirs := $(strip $(INSTALLDIR)/lib $(INSTALLDIR)/bin $(incdir))

LIBEXTNS := so
DEFINES  := -fPIC -D_REENTRANT -D__pentium__ -Wall
CC  := gcc
CXX := g++
LD  := g++
LX  := g++

ifneq ($(findstring i386-linux,$(tgt_arch)),)
CXXFLAGS   := -m32
CPPFLAGS   := $(CFLAGS) -m32
USRLIBDIR  := /usr/lib
endif

ifneq ($(findstring x86_64-,$(tgt_arch)),)
CPPFLAGS   := $(CFLAGS)
USRLIBDIR  := /usr/lib64
endif

ifneq ($(findstring -dbg,$(tgt_arch)),)
CPPFLAGS   += -g
endif

ifneq ($(findstring -opt,$(tgt_arch)),)
CPPFLAGS   += -O4
endif

override CPPFLAGS += -I$(RELEASE_DIR)

# Procedures
# ----------

# Define some procedures and create (different!) rules for libraries
# and targets. Note that 'eval' needs gmake >= 3.80.
incfiles  :=
libraries :=
targets   :=
objects   := 
getobjects = $(strip \
	$(patsubst %.cc,$(1)/%.o,$(filter %.cc,$(2))) \
	$(patsubst %.cpp,$(1)/%.o,$(filter %.cpp,$(2))) \
	$(patsubst %.c,$(1)/%.o, $(filter %.c,$(2))) \
	$(patsubst %.s,$(1)/%.o, $(filter %.s,$(2))))
getlib = $(1)
getlinksdir  = $(addprefix -L, $(sort $(dir $(1))))
getlinklibs  = $(addprefix -l,$(foreach prjlib,$(1),$(call getlib,$(prjlib))))
getlinkslib  = $(addprefix -l,$(notdir $(1)))

getrpath = $$ORIGIN/../lib
getrpaths = $(subst $(space),:,$(strip $(call getrpath)))


define library_template
  library_$(1) := $$(libdir)/lib$(1).$(LIBEXTNS)
  libobjs_$(1) := $$(call getobjects,$$(objdir),$$(libsrcs_$(1)))
  libraries    += $$(library_$(1))
  incfiles     += $$(libincs_$(1))	
  objects      += $$(libobjs_$(1))
ifeq ($$(LIBEXTNS),so)
ifneq ($$(ifversn_$(1)),)
  ifversnflags_$(1) := -Wl,--version-script=$$(ifversn_$(1))
endif
endif
$$(library_$(1)): $$(libobjs_$(1))
endef

$(foreach lib,$(libnames),$(eval $(call library_template,$(lib))))

define target_template
  target_$(1)  := $$(bindir)/$(1)
  tgtobjs_$(1) := $$(call getobjects,$$(objdir),$$(tgtsrcs_$(1)))
  targets      += $$(target_$(1))
  objects      += $$(tgtobjs_$(1))
  linkdirs_$(1)  := -L$(libdir)
  linkdirs_$(1)  += $$(call getlinksdir,$$(tgtslib_$(1)))
ifneq ($$(tgtlibs_$(1)),)
  linklibs_$(1)  := $$(call getlinklibs,$$(tgtlibs_$(1)))
endif
ifneq ($$(tgtslib_$(1)),)
  linklibs_$(1)  += $$(call getlinkslib,$$(tgtslib_$(1)))
endif
ifeq ($$(LIBEXTNS),so)
  rpaths_$(1)    := -Wl,-rpath='$$(call getrpath)'
endif
linkflags_$(1) := $$(linkdirs_$(1)) $$(linklibs_$(1)) $$(rpaths_$(1))
$$(target_$(1)): $$(tgtobjs_$(1)) $$(libraries_$(1))
endef

$(foreach tgt,$(tgtnames),$(eval $(call target_template,$(tgt))))

temp_dirs := $(strip $(sort $(foreach o,$(objects),$(dir $(o)))) $(libdir) $(bindir))

# Rules
# -----
rules := all dir objs lib bin clean cleanall userall userclean install print

.PHONY: $(rules) $(libnames) $(tgtnames)

.SUFFIXES:  # Kills all implicit rules

all: $(temp_dirs) bin;

objs: $(objects);

lib: $(libraries);

bin: lib $(targets);

install: $(prod_dirs)
	cp ${incfiles} $(incdir)
	cp -rf ${libdir} $(INSTALLDIR)/.
	cp -rf ${bindir} $(INSTALLDIR)/.

print:
	@echo	"bindir    = $(bindir)"
	@echo	"libdir    = $(libdir)"
	@echo	"objdir    = $(objdir)"
	@echo	"prod_dirs = $(prod_dirs)"
	@echo	"temp_dirs = $(temp_dirs)"
	@echo   "targets   = $(targets)"
	@echo	"libraries = $(libraries)"
	@echo	"objects   = $(objects)"
	@echo	"CXXFLAGS  = $(CXXFLAGS)"
	@echo	"CPPFLAGS  = $(CPPFLAGS)"

clean: userclean
	$(quiet)$(RM) $(objects) $(libraries) $(targets)

cleanall: clean userclean

# Directory structure
$(prod_dirs) $(temp_dirs):
	mkdir -p $@


# Libraries
$(libdir)/lib%.$(LIBEXTNS):
	@echo "[LD] Build library $*"
	$(quiet)$(LD) $(CXXFLAGS) -shared $(ifversnflags_$*) $(linkflags_$*) $^ -o $@


# Executables
$(bindir)/%:
	@echo "[LT] Linking target $*"
	$(quiet)$(LX) $(DEFINES) $(tgtobjs_$*) $(linkflags_$*) $(CXXFLAGS) -o $@

# Objects for C++ assembly files
$(objdir)/%.o: %.cc
	@echo "[CX] Compiling $<"
	$(quiet)$(CXX) $(CPPFLAGS) $(DEFINES) $(CXXFLAGS) -c $< -o $@

$(objdir)/%.o: %.cpp
	@echo "[CX] Compiling $<"
	$(quiet)$(CXX) $(CPPFLAGS) $(DEFINES) $(CXXFLAGS) -c $< -o $@
