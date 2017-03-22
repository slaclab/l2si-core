arch_size = i386-linux x86_64-linux x86_64-rhel6 x86_64-rhel7
arch_opts = -opt -dbg -opt-dbg -dbg-opt

archs := $(foreach aopt,$(arch_opts),$(addsuffix $(aopt),$(arch_size)))

quiet := @

setup.mk:;
