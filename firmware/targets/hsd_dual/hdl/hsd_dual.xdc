#LCLSII (185.7 MHz)
create_clock -name timingRefClkP -period 5.38 [get_ports timingRefClkP]
#LCLS (238 MHz)
#create_clock -period 4.200 -name timingRefClkP [get_ports timingRefClkP]

set_clock_groups -asynchronous \
                 -group [get_clocks -include_generated_clocks pciRefClkP] \
                 -group [get_clocks -include_generated_clocks timingRefClkP] \
                 -group [get_clocks -include_generated_clocks adr_p]
