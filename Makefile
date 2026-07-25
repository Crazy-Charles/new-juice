ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PROJECT := $(ROOT)/new-juice.gprj
BUILD_TCL := $(ROOT)/scripts/build.tcl
PNR_BITSTREAM := $(ROOT)/impl/pnr/new-juice.fs
OUTPUT := $(ROOT)/impl/prn/new-juice.fs

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
GOWIN_IDE ?= /Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE
GOWIN_ENV := \
	QT_QPA_PLATFORM_PLUGIN_PATH="$(GOWIN_IDE)/plugins/qt/platforms" \
	DYLD_LIBRARY_PATH="$(GOWIN_IDE)/lib" \
	DYLD_FRAMEWORK_PATH="$(GOWIN_IDE)/lib"
else
GOWIN_IDE ?= /opt/Gowin/IDE
GOWIN_ENV :=
endif

GW_SH ?= $(GOWIN_IDE)/bin/gw_sh

PROJECT_INPUTS := $(PROJECT) $(shell find $(ROOT)/src $(ROOT)/roms -type f)

.DEFAULT_GOAL := all

.PHONY: all build rebuild check-tools

all: build

build: $(OUTPUT)

rebuild: check-tools
	$(call run-gowin)

check-tools:
	@if [ ! -x "$(GW_SH)" ]; then \
		echo "Gowin command-line tool not found: $(GW_SH)"; \
		echo "Set GOWIN_IDE=/path/to/Gowin/IDE or GW_SH=/path/to/gw_sh."; \
		exit 1; \
	fi

define run-gowin
	@echo "Building new-juice with $(GW_SH)"
	@cd "$(ROOT)" && env $(GOWIN_ENV) NEW_JUICE_ROOT="$(ROOT)" \
		"$(GW_SH)" "$(BUILD_TCL)"
	@mkdir -p "$(dir $(OUTPUT))"
	@cp "$(PNR_BITSTREAM)" "$(OUTPUT)"
	@echo "Generated $(OUTPUT)"
endef

$(OUTPUT): $(PROJECT_INPUTS) $(BUILD_TCL) | check-tools
	$(call run-gowin)
