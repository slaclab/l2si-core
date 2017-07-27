include setup.mk

# List of packages (low level first)
#packages := hsd dti
packages := hsd

SHELL := /bin/bash

packages.% := $(addsuffix .%,$(packages))

.PHONY: print $(packages.%) $(archs) special gen clean install

print:
	@echo "CURDIR = $(CURDIR)"
	@echo "packages = $(packages)"
	@echo "packages.d = $(packages.d)"
	@echo "packages.a = $(packages.a)"
	@echo "CPPFLAGS = $(CPPFLAGS)"
	@echo "CXXFLAGS = $(CXXFLAGS)"

define package_template
$(1).%:
	@echo "[PK] Target <$$*> package <$(1)>"
	$(quiet)$(MAKE) -C $(1) $$*
endef

$(foreach pkg,$(packages),$(eval $(call package_template,$(pkg))))

define arch_template
packages_$(1) := $$(foreach pkg,$$(packages),$$(pkg).$(1))
$(1): $$(packages_$(1));
endef

$(foreach arc,$(archs) install clean,$(eval $(call arch_template,$(arc))))

Makefile:;
