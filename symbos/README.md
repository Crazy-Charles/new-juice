# WonderTANG SymbOS mass-storage driver

`-SDWTANG.DRV` provides sector read/write access to the WonderTANG microSD
controller from SymbOS on MSX. It supports an unpartitioned/superfloppy card
(`partition 0`) and MBR primary partitions 1–4 on controller channel 0. A
typical partitioned Nextor card should use `partition 1`, not `partition 0`.

Build it with SjASMPlus:

```sh
make -C symbos
```

The source targets the `SMD3` SymbOS 4 MSX mass-storage ABI. During each sector
operation it maps the WonderTANG slot into page 1, enables the transfer RAM and
register overlay at `0x7C00–0x7EFF`, maps the SymbOS transfer buffer into page
0, then restores both pages before returning or moving to the next sector.

SymbOS is started from MSX-DOS/Nextor, so the driver reuses the SD controller
state initialized during boot. It checks the controller's card-type register
and reports `not ready` if it is zero; it does not issue a second initialization
command, which the current FPGA state machine does not support after boot.

The driver is derived from the GPL-3.0 `Drv-SDMega.asm` and
`Drv-FDCNational.asm` drivers in
[Prodatron/symdrv-msx-massstorage](https://github.com/Prodatron/symdrv-msx-massstorage),
with the controller interface adapted from WonderTANG's Nextor driver.
