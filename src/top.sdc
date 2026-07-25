// 27Mhz main clk
create_clock -name clkin -period 37.037 -waveform {0 18.518} [get_ports {clkin}] -add

// 216Mhz main clks
create_generated_clock -name main_clk -source [get_ports {clkin}] -master_clock clkin -divide_by 1 -multiply_by 4 -add [get_nets {main_clk}]
//create_generated_clock -name sdram_clk -source [get_ports {clkin}] -master_clock clkin -divide_by 1 -multiply_by 4 -duty_cycle 50 -phase 180 -add [get_nets {sdram_clk}]

// Fixed-period audio clock: 27 MHz / 38 = 710.526 kHz
create_generated_clock -name audio_bclk_raw -source [get_ports {clkin}] -master_clock clkin -divide_by 38 -add [get_nets {audio_bclk_raw}]
