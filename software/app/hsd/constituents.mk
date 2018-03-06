libnames := hsd
libsrcs_hsd := $(filter-out hsd_init.cc hsd_pgp.cc hsd_sim.cc hsd_valid.cc, $(wildcard *.cc))
libincs_hsd := Module.hh TprCore.hh AxiVersion.hh RxDesc.hh

tgtnames := hsd_init
tgtsrcs_hsd_init := hsd_init.cc
tgtlibs_hsd_init := hsd
tgtslib_hsd_init := rt

tgtnames += hsd_test
tgtsrcs_hsd_test := hsd_test.cc Histogram.cc
tgtlibs_hsd_test := hsd
tgtslib_hsd_test := rt pthread

tgtnames += hsd_pgp
tgtsrcs_hsd_pgp := hsd_pgp.cc
tgtlibs_hsd_pgp := hsd
tgtslib_hsd_pgp := rt pthread

tgtnames += hsd_sim
tgtsrcs_hsd_sim := hsd_sim.cc
tgtslib_hsd_sim := rt pthread

tgtnames += hsd_valid
tgtsrcs_hsd_valid := hsd_valid.cc
tgtslib_hsd_valid := rt pthread
