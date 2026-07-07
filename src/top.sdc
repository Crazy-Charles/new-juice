// 27Mhz main clk
create_clock -name clkin -period 37.037 -waveform {0 18.518} [get_ports {clkin}] -add

// 3.58Mhz CPU clock
//create_clock -name cpu_clk -period 279.3650 -waveform {0 139.6825} [get_ports {cpu_clk}] -add

// 216Mhz main clks
//create_generated_clock -name clk_main -source [get_ports {clkin}] -master_clock clk -divide_by 1 -multiply_by 8 -add [get_nets {clk_main}]
//create_generated_clock -name clk_main_phased -source [get_ports {clkin}] -master_clock clk -divide_by 1 -multiply_by 8 -duty_cycle 50 -phase 180 -add [get_nets {clk_main_phased}]
