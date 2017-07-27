libnames := hsd
libsrcs_hsd := $(filter-out hsd_init.cc Histogram.cc, $(wildcard *.cc))
libincs_hsd := Module.hh TprCore.hh AxiVersion.hh RxDesc.hh

tgtnames := hsd_init
tgtsrcs_hsd_init := hsd_init.cc
tgtlibs_hsd_init := hsd
tgtslib_hsd_init := rt

tgtnames := hsd_test
tgtsrcs_hsd_test := hsd_test.cc Histogram.cc
tgtlibs_hsd_test := hsd
tgtslib_hsd_test := rt pthread
