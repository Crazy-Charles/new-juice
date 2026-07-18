# New Juice

FPGA design for the WonderTANG MSX interface, targeting the Gowin
GW2AR-LV18QN88C8/I7 device. The current design implements the MSX bus
interface, a slot expander, and an SDRAM-backed memory mapper.

At startup, the design also copies two ROM images from the onboard SPI flash
into SDRAM immediately above the 4 MiB memory-mapper region. The MSX `/WAIT`
line remains asserted until SDRAM initialization, its startup test, and the ROM
copy have completed.

## Hardware

- Gowin GW2AR-18C FPGA (`GW2AR-LV18QN88C8/I7`)
- 27 MHz board clock
- 3.58 MHz MSX CPU clock
- 32-bit SDRAM interface

## Project layout

- `new-juice.gprj` — Gowin EDA project
- `src/` — Verilog/SystemVerilog sources, pin constraints, and timing constraints
- `roms/` — ROM images used by the design
- `impl/` — Gowin implementation configuration

## Flash ROM layout

| ROM | SPI flash | SDRAM cache | Expanded subslot | MSX address |
| --- | --- | --- | --- | --- |
| MSX-DOS2 ASCII MegaROM | `0x100000–0x11FFFF` | `0x400000–0x41FFFF` | 0 | `0x4000–0x7FFF` |
| FM-PAC | `0x120000–0x123FFF` | `0x420000–0x423FFF` | 1 | `0x4000–0x7FFF` |

The DOS2 ROM is divided into eight 16 KiB banks. Writing the bank number to
`0x6000` selects the bank visible at `0x4000–0x7FFF`; only bits 2:0 are used.
The FM-PAC image is a fixed 16 KiB ROM.

## SD-card interface

The onboard microSD card is exposed through the DOS2 ROM in expanded subslot
0. Writing `1` to `0x7E00` overlays the SD transfer RAM and registers onto the
ROM; writing `0` restores normal ROM reads.

| Address | Access | Description |
| --- | --- | --- |
| `0x7C00–0x7DFF` | Read/write | 512-byte sector transfer RAM |
| `0x7E00` | Write | Enable or disable the SD overlay |
| `0x7E01` | Write | Command: `0x80` initialize, `1` read, `2` write |
| `0x7E02` | Read | Status: bit 7 busy, bit 1 timeout, bit 0 CRC error |
| `0x7E03–0x7E06` | Write | 32-bit sector address, least-significant byte first |
| `0x7E07–0x7E09` | Read | CSD device size |
| `0x7E0A` | Read | CSD size multiplier |
| `0x7E0B` | Read | CSD read block length |
| `0x7E0C` | Read | Card type: unknown, SDv1, SDv2, or SDHCv2 |
| `0x7E0D` | Read | Manufacturer ID |
| `0x7E0E–0x7E0F` | Read | OEM ID |
| `0x7E10–0x7E14` | Read | Product name |
| `0x7E15–0x7E18` | Read | Product serial number |

The status values are `0x00` for success/idle, `0x80` while busy, `0x01` for
a CRC error, and `0x02` for a timeout. Error bits can be combined with busy.

## Building

1. Open `new-juice.gprj` in Gowin EDA.
2. Run synthesis and place-and-route.
3. Program the generated bitstream onto the target board.

The project expects Gowin EDA support for the GW2AR-18C family.

## MSX bus pins

| MSX bus | FPGA signal | Direction | Notes |
| --- | --- | --- | --- |
| D7–D0 | `cd[7:0]` | Bidirectional | `datadir` controls direction: 0 = output, 1 = input |
| `/INT` | `int_out` | Output | Open-collector interrupt |
| `/BUSDIR` | `busdir_n` | Output | 0 = output, 1 = input |
| `/WAIT` | `wait_out` | Output | Open-collector CPU wait |
| `/RD` | `rd_n_in` | Input | Read strobe |
| `/WR` | `wr_n_in` | Input | Write strobe |
| `/SLTSL` | `sltsl_n_in` | Input | Slot select |
| CLOCK | `cpu_clkin` | Input | MSX CPU clock |

## Multiplexed inputs

`msel_n[2:0]` selects the signals presented on `mp[7:0]`.

| Input | `110` | `101` | `011` |
| --- | --- | --- | --- |
| MP0 | A0 | A8 | `/MERQ` |
| MP1 | A1 | A9 | `/IORQ` |
| MP2 | A2 | A10 | `/CS1` |
| MP3 | A3 | A11 | `/CS2` |
| MP4 | A4 | A12 | `/RESET` |
| MP5 | A5 | A13 | `/RFSH` |
| MP6 | A6 | A14 | `/CS12` |
| MP7 | A7 | A15 | `/M1` |
