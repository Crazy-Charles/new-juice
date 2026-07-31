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
OPENFPGALOADER ?= openFPGALoader
PROGRAMMER_BOARD ?= tangnano20k
PROGRAMMER_FLAGS ?= -f
ROM_PROGRAMMER_FLAGS ?= -f --external-flash

DOS2_ROM := $(ROOT)/roms/Nextor-2.1.1.WonderTANG.ROM.bin
DOS2_ROM_OFFSET ?= 1048576
FM_ROM := $(ROOT)/roms/16k_fm_opl.bin
FM_ROM_OFFSET ?= 1179648
SFG_ROM := $(ROOT)/roms/SFG01.ROM

PROJECT_INPUTS := \
	$(PROJECT) \
	$(shell find $(ROOT)/src -path $(ROOT)/src/jtopl -prune -o -path $(ROOT)/src/jt49 -prune -o -path $(ROOT)/src/jt51 -prune -o -type f -print) \
	$(shell find $(ROOT)/src/jtopl/hdl -type f) \
	$(shell find $(ROOT)/src/jt49/hdl -type f) \
	$(shell find $(ROOT)/src/jt51/hdl -maxdepth 1 -type f) \
	$(shell find $(ROOT)/roms -type f)

.DEFAULT_GOAL := all

.PHONY: all build rebuild program reprogram roms check-tools check-programmer

all: build

build: $(OUTPUT)

rebuild: check-tools
	$(call run-gowin)

program: check-programmer $(OUTPUT)
	@echo "Programming $(OUTPUT) with $(OPENFPGALOADER)"
	@"$(OPENFPGALOADER)" -b "$(PROGRAMMER_BOARD)" \
		$(PROGRAMMER_FLAGS) "$(OUTPUT)"

reprogram: check-programmer
	@if [ ! -f "$(OUTPUT)" ]; then \
		echo "Built bitstream not found: $(OUTPUT)"; \
		echo "Run 'make build' first."; \
		exit 1; \
	fi
	@echo "Reprogramming $(OUTPUT) with $(OPENFPGALOADER)"
	@"$(OPENFPGALOADER)" -b "$(PROGRAMMER_BOARD)" \
		$(PROGRAMMER_FLAGS) "$(OUTPUT)"

roms: check-programmer $(DOS2_ROM) $(FM_ROM) $(SFG_ROM)
	@echo "Programming DOS2 ROM at offset $(DOS2_ROM_OFFSET)"
	@"$(OPENFPGALOADER)" -b "$(PROGRAMMER_BOARD)" \
		$(ROM_PROGRAMMER_FLAGS) -o "$(DOS2_ROM_OFFSET)" "$(DOS2_ROM)"
	@combined_rom="$$(mktemp -t new-juice-fm-sfg)"; \
		trap 'rm -f "$$combined_rom"' EXIT; \
		cp "$(FM_ROM)" "$$combined_rom"; \
		dd if="$(SFG_ROM)" of="$$combined_rom" bs=16384 seek=1 \
			conv=notrunc status=none; \
		echo "Programming FM and SFG-01 ROMs at offset $(FM_ROM_OFFSET)"; \
		"$(OPENFPGALOADER)" -b "$(PROGRAMMER_BOARD)" \
			$(ROM_PROGRAMMER_FLAGS) -o "$(FM_ROM_OFFSET)" "$$combined_rom"

check-tools:
	@if [ ! -x "$(GW_SH)" ]; then \
		echo "Gowin command-line tool not found: $(GW_SH)"; \
		echo "Set GOWIN_IDE=/path/to/Gowin/IDE or GW_SH=/path/to/gw_sh."; \
		exit 1; \
	fi

check-programmer:
	@if ! command -v "$(OPENFPGALOADER)" >/dev/null 2>&1; then \
		echo "openFPGALoader not found: $(OPENFPGALOADER)"; \
		echo "Install openFPGALoader or set OPENFPGALOADER=/path/to/openFPGALoader."; \
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
