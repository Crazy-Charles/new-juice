# WonderTANG MSX-Interface

# Direct MSX-BUS Pins:

MSX BUS | PIN | MODE | NOTE
---| --- | --- | ---
D7-D0 | cd[7:0] | InOut  | **datadir** pin controls the flow: 0 : output, 1: input
/INT | int_n | Ouput | Triggers interrupt. Open collector.
/BUSDIR | busdir_n | Output | controls the data bus direction: 0 : output , 1 input
/WAIT | wait_n | Output | Holds CPU. Open collector.
/RD | rd_n | Input |
/WR | wr_n | Input | 
/SLTSL | sltsl_n | Input |
CLOCK | cpu_clk | Input | 


# Multiplexed Input Pins

msel_n[2:0] controls the multiplexing input for these signals through mp[7:0]:

/MSEL | 110 | 101 | 011
--- | --- | --- | ---
MP0 | A0 | A8 | /MERQ
MP1 | A1 | A9 | /IORQ
MP2 | A2 | A10 | /CS1
MP3 | A3 | A11 | /CS2
MP4 | A4 | A12 | /RESET
MP5 | A5 | A13 | /RFSH
MP6 | A6 | A14 | /CS12
MP7 | A7 | A15 | /M1


