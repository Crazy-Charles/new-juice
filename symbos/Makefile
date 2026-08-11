SJASMPLUS ?= sjasmplus
DRIVER := -SDWTANG.DRV
SOURCE := Drv-WonderTANG.asm
LIST := Drv-WonderTANG.lst

.PHONY: all clean

all: $(DRIVER)

$(DRIVER): $(SOURCE)
	$(SJASMPLUS) --nologo --dirbol --cleanonerror --lst=$(LIST) --raw=$@ $<

clean:
	rm -f -- $(DRIVER) $(LIST) $(SOURCE:.asm=.sym)
