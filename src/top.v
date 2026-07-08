module top(
    input   clkin,
    input   s1,

    //output hp_ws,
    //output hp_din,
    //output hp_bck,
    //output pa_en,

    input cpu_clkin,
    input rd_n_in,
    input wr_n_in,
    input sltsl_n_in,

    output int_out,
    output busdir_n,
    output wait_out,
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
    output O_sdram_clk,
    output O_sdram_cke,
    output O_sdram_cs_n,            // chip select
    output O_sdram_cas_n,           // columns address select
    output O_sdram_ras_n,           // row address select
    output O_sdram_wen_n,           // write enable
    inout [31:0] IO_sdram_dq,       // 32 bit bidirectional data bus
    output [10:0] O_sdram_addr,     // 11 bit multiplexed address bus
    output [1:0] O_sdram_ba,        // two banks
    output [3:0] O_sdram_dqm       // 32/4

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
        .clkout(main_clk), // 216 Mhz main clock
        .lock(rpll_main_lock), 
        .clkoutp(main_cke), // 216 Mhz rotated main clock
        //.clkoutd(clkoutd), 
        .reset(~reset_n),
        .clkin(clkin) //input clkin (27Mhz)
    );

    clockdiv2 clk_sdram_div(
        .clk_src(main_clk), // 216 Mhz main clock
        .reset_n(rpll_main_lock),
        .clk_div(sdram_clk) // 108 Mhz sdram clock
    );

    clockdiv2 clkp_sdram_div(
        .clk_src(main_cke), // 216 Mhz rotated main clock
        .reset_n(rpll_main_lock),
        .clk_div(sdram_cke) // 108 Mhz rotated sdram clock
    );

    wire [7:0] a_lo;
    wire [7:0] a_hi;
    wire [15:0] addr;
    wire merq_n;
    wire iorq_n;
    wire cs1_n;
    wire cs2_n;
    wire reset_in_n;
    wire rfsh_n;
    wire cs12_n;
    wire m1_n;
    wire inputs_latched;
    wire rd_n;
    wire wr_n;
    wire sltsl_n;
    wire [7:0] slot_expander_data_out;
    wire slot_expander_data_out_en;
    wire [3:0] page0_subslot_en;
    wire [3:0] page1_subslot_en;
    wire [3:0] page2_subslot_en;
    wire [3:0] page3_subslot_en;
    wire ws2812_out;
    wire ws2812_done;
    wire startup_reset_n;
    wire int_n;
    wire wait_n;

    assign startup_reset_n = rpll_main_lock && reset_n;

    ws2812
    #(
        .CLK_FRE(216_000_000)
    )
    ws2812_inst(
        .clk(main_clk),
        .rst_n(startup_reset_n),
        .WS2812(ws2812_out),
        .done(ws2812_done)
    );

    input_debouncer
    #(
        .WIDTH(3),
        .DEBOUNCE_CYCLES(8)
    )
    bus_control_debouncer(
        .clk(main_clk),
        .reset_n(rpll_main_lock),
        .in({rd_n_in, wr_n_in, sltsl_n_in}),
        .out({rd_n, wr_n, sltsl_n})
    );

    mp_debouncer
    #(
        .DEBOUNCE_CYCLES(8)
    )
    mp_debouncer_inst(
        .clk(main_clk),
        .reset_n(rpll_main_lock),
        .mp(mp),
        .msel_n(msel_n),
        .a_lo(a_lo),
        .a_hi(a_hi),
        .addr(addr),
        .merq_n(merq_n),
        .iorq_n(iorq_n),
        .cs1_n(cs1_n),
        .cs2_n(cs2_n),
        .reset_in_n(reset_in_n),
        .rfsh_n(rfsh_n),
        .cs12_n(cs12_n),
        .m1_n(m1_n),
        .inputs_latched(inputs_latched)
    );

    slot_expander slot_expander_inst(
        .clk(main_clk),
        .reset_n(rpll_main_lock),
        .addr(addr),
        .data_in(cd),
        .merq_n(merq_n),
        .rd_n(rd_n),
        .wr_n(wr_n),
        .sltsl_n(sltsl_n),
        .data_out(slot_expander_data_out),
        .data_out_en(slot_expander_data_out_en),
        .page0_subslot_en(page0_subslot_en),
        .page1_subslot_en(page1_subslot_en),
        .page2_subslot_en(page2_subslot_en),
        .page3_subslot_en(page3_subslot_en)
    );

    cd_demux cd_demux_inst(
        .startup_done(ws2812_done),
        .ws2812_out(ws2812_out),
        .data_out(slot_expander_data_out),
        .data_out_en(slot_expander_data_out_en),
        .cd(cd),
        .busdir_n(busdir_n),
        .datadir(datadir),
        .wait_n(wait_n)
    );

	SDRAM your_instance_name(
		.O_sdram_clk(sdram_clk), //output O_sdram_clk
		.O_sdram_cke(sdram_cke), //output O_sdram_cke
		.O_sdram_cs_n(O_sdram_cs_n), //output O_sdram_cs_n
		.O_sdram_cas_n(O_sdram_cas_n), //output O_sdram_cas_n
		.O_sdram_ras_n(O_sdram_ras_n), //output O_sdram_ras_n
		.O_sdram_wen_n(O_sdram_wen_n), //output O_sdram_wen_n
		.O_sdram_dqm(O_sdram_dqm), //output [3:0] O_sdram_dqm
		.O_sdram_addr(O_sdram_addr), //output [10:0] O_sdram_addr
		.O_sdram_ba(O_sdram_ba), //output [1:0] O_sdram_ba
		.IO_sdram_dq(IO_sdram_dq), //inout [31:0] IO_sdram_dq
		.I_sdrc_rst_n(I_sdrc_rst_n), //input I_sdrc_rst_n
		.I_sdrc_clk(I_sdrc_clk), //input I_sdrc_clk
		.I_sdram_clk(I_sdram_clk), //input I_sdram_clk
		.I_sdrc_cmd_en(I_sdrc_cmd_en), //input I_sdrc_cmd_en
		.I_sdrc_cmd(I_sdrc_cmd), //input [2:0] I_sdrc_cmd
		.I_sdrc_precharge_ctrl(I_sdrc_precharge_ctrl), //input I_sdrc_precharge_ctrl
		.I_sdram_power_down(I_sdram_power_down), //input I_sdram_power_down
		.I_sdram_selfrefresh(I_sdram_selfrefresh), //input I_sdram_selfrefresh
		.I_sdrc_addr(I_sdrc_addr), //input [20:0] I_sdrc_addr
		.I_sdrc_dqm(I_sdrc_dqm), //input [3:0] I_sdrc_dqm
		.I_sdrc_data(I_sdrc_data), //input [31:0] I_sdrc_data
		.I_sdrc_data_len(I_sdrc_data_len), //input [7:0] I_sdrc_data_len
		.O_sdrc_data(O_sdrc_data), //output [31:0] O_sdrc_data
		.O_sdrc_init_done(O_sdrc_init_done), //output O_sdrc_init_done
		.O_sdrc_cmd_ack(O_sdrc_cmd_ack) //output O_sdrc_cmd_ack
	);  

    // triggers cpu interrupt (open collector)
    assign int_n = 1'b1;

    assign int_out = ~int_n;
    assign wait_out = ~wait_n;

    // led indicator
    assign led = ws2812_done; //1'b0;

endmodule
