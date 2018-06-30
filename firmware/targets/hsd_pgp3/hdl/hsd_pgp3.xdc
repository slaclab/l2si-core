set_property PACKAGE_PIN AT18 [get_ports timingModAbs]
set_property PACKAGE_PIN AT19 [get_ports timingRxLos]
set_property PACKAGE_PIN AT20 [get_ports timingTxDis]
set_property IOSTANDARD LVCMOS33 [get_ports timingModAbs]
set_property IOSTANDARD LVCMOS33 [get_ports timingRxLos]
set_property IOSTANDARD LVCMOS33 [get_ports timingTxDis]

#LCLSII (185.7 MHz)
create_clock -name timingRefClkP -period 5.38 [get_ports timingRefClkP]
#LCLS (238 MHz)
#create_clock -period 4.200 -name timingRefClkP [get_ports timingRefClkP]

set_clock_groups -asynchronous \
                 -group [get_clocks -include_generated_clocks pciRefClkP] \
                 -group [get_clocks -include_generated_clocks timingRefClkP] \
                 -group [get_clocks -include_generated_clocks adr_p]

create_generated_clock -name timingRecClk [get_pins {U_Core/U_TimingGth/GEN_EXTREF/TIMING_RECCLK_BUFG_GT/O}]
create_generated_clock -name timingFbClk [get_pins {U_Core/U_TimingGth/GEN_EXTREF/TIMING_TXCLK_BUFG_GT/O}]

set_clock_groups -asynchronous \
                 -group [get_clocks timingRecClk] \
                 -group [get_clocks timingFbClk]

set_false_path -from [get_ports pg_m2c[0]]
set_false_path -from [get_ports prsnt_m2c_l[0]]
