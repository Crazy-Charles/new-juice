module top(
    input   clkin,
    input   s1,

    //output hp_ws,
    //output hp_din,
    //output hp_bck,
    //output pa_en,

    input cpu_clkin,
    input rd_n,
    input wr_n,
    input sltsl_n,

    output int_n,
    output busdir_n,
    output wait_n,
    output datadir,

    inout [7:0] cd,

    input [7:0] mp,

    output [2:0] msel_n,

    // flash
    //output mspi_cs,
    //output mspi_sclk,
    //inout mspi_miso,
    //inout mspi_mosi,
 
    // MicroSD
    //output sd_sclk,
    //inout  sd_cmd,      // MOSI
    //inout  sd_dat0,     // MISO
    //output sd_dat1,     // 1
    //output sd_dat2,     // 1
    //output sd_dat3,     // 1
   
    // SDRAM
    //output O_sdram_clk,
    //output O_sdram_cke,
    //output O_sdram_cs_n,            // chip select
    //output O_sdram_cas_n,           // columns address select
    //output O_sdram_ras_n,           // row address select
    //output O_sdram_wen_n,           // write enable
    //inout [31:0] IO_sdram_dq,       // 32 bit bidirectional data bus
    //output [10:0] O_sdram_addr,     // 11 bit multiplexed address bus
    //output [1:0] O_sdram_ba,        // two banks
    //output [3:0] O_sdram_dqm       // 32/4

    output led

);

    BUFG clk_buf(
    .O(clk),    // 27Mhz buffered output clock
    .I(clkin)   // 27Mhz input clock
    );

    BUFG cpu_clk_buf(
    .O(cpu_clk),    // 3.58Mhz buffered output clock
    .I(cpu_clkin)   // 3.58Mhz input clock
    );

    reg reset_n = 0;
    always_ff @(posedge clk) reset_n <= ~s1;

    // main pll
    rpll_main rpll_main(
        .clkout(clk_main), // 216 Mhz main clock
        .lock(rpll_main_lock), 
        .clkoutp(clkp_main), // 216 Mhz rotated main clock
        //.clkoutd(clkoutd), 
        .reset(reset_n),
        .clkin(clkin) //input clkin (27Mhz)
    );

    clockdiv2 clk_sdram_div(
        .clk_src(clk_main), // 216 Mhz main clock
        .reset_n(rpll_main_lock),
        .clk_div(clk_sdram) // 108 Mhz sdram clock
    );

    clockdiv2 clkp_sdram_div(
        .clk_src(clkp_main), // 216 Mhz rotated main clock
        .reset_n(rpll_main_lock),
        .clk_div(clkp_sdram) // 108 Mhz rotated sdram clock
    );

    // led indicator
    assign led = 1'b0;

    // data bus is tristated
    assign cd = 8'bzzzzzzzz;

    // multiplexer select lines
    assign msel_n = 3'b111;

    // triggers cpu interrupt (open collector)
    assign int_n = 1'b1;

    // holds cpu (open collector)
    assign wait_n = 1'b0;

    // bus direction 0 : output, 1 : input
    assign busdir_n = 1'b1; 
    
    // datadir 0: output, 1: input
    assign datadir = 1'b1;

endmodule