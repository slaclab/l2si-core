libnames := hsd
libsrcs_hsd := $(filter-out hsd_init.cc, $(wildcard *.cc))
libincs_hsd := Module.hh TprCore.hh AxiVersion.hh

tgtnames := hsd_init
tgtsrcs_hsd_init := hsd_init.cc
tgtlibs_hsd_init := hsd
tgtslib_hsd_init := rt