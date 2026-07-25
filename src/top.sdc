// 27Mhz main clk
create_clock -name clkin -period 37.037 -waveform {0 18.518} [get_ports {clkin}] -add

// 216Mhz main clks
create_generated_clock -name main_clk -source [get_ports {clkin}] -master_clock clkin -divide_by 1 -multiply_by 4 -add [get_nets {main_clk}]
//create_generated_clock -name sdram_clk -source [get_ports {clkin}] -master_clock clkin -divide_by 1 -multiply_by 4 -duty_cycle 50 -phase 180 -add [get_nets {sdram_clk}]

// All 27 MHz <-> 108 MHz transfers use explicit synchronizers or bundled-data
// mailboxes. Do not time them as single-cycle synchronous paths.
set_clock_groups -asynchronous -group [get_clocks {clkin}] -group [get_clocks {main_clk}]
