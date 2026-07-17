module top
(
    input   clkin,
    input   s1,
    input   s2,
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
    output [3:0] O_sdram_dqm,      // 32/4

    output led

);
    wire clk;
    BUFG clk_buf(
    .O(clk),    // 27Mhz buffered output clock
    .I(clkin)   // 27Mhz input clock
    );

    wire cpu_clk;
    BUFG cpu_clk_buf(
    .O(cpu_clk),    // 3.58Mhz buffered output clock
    .I(cpu_clkin)   // 3.58Mhz input clock
    );

    reg reset_n = 0;
    always_ff @(posedge clk) reset_n <= ~s1;
    wire board_reset_n;
    wire active_module_reset_n;
    reg [1:0] s2_sync = 2'b00;
    reg board_enabled = 1'b0;
    
    // main pll
    wire main_clk;
    wire sdram_clk;
    wire rpll_main_lock;
    rpll_main rpll_main(
        .clkout(main_clk), // 108 Mhz main clock
        .lock(rpll_main_lock), 
        .clkoutp(sdram_clk), // 108 Mhz rotated SDRAM clock
        .reset(~reset_n),
        .clkin(clkin) //input clkin (27Mhz)
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
    wire [7:0] sdram_mapper_data_out;
    wire sdram_mapper_data_out_en;
    wire [3:0] page0_subslot_en;
    wire [3:0] page1_subslot_en;
    wire [3:0] page2_subslot_en;
    wire [3:0] page3_subslot_en;
    wire int_n;
    wire wait_n;
    wire [7:0] data_out;
    wire data_out_en;
    wire mapper_port_read;
    wire [7:0] cd_in;

    wire sdrc_cmd_en;
    wire [2:0] sdrc_cmd;
    wire sdrc_precharge_ctrl;
    wire sdram_power_down;
    wire sdram_selfrefresh;
    wire [20:0] sdrc_addr;
    wire [3:0] sdrc_dqm;
    wire [31:0] sdrc_data;
    wire [7:0] sdrc_data_len;
    wire [31:0] sdrc_data_in;
    wire sdrc_init_done;
    wire sdrc_cmd_ack;
    wire mapper_sdrc_cmd_en;
    wire [2:0] mapper_sdrc_cmd;
    wire mapper_sdrc_precharge_ctrl;
    wire mapper_sdram_power_down;
    wire mapper_sdram_selfrefresh;
    wire [20:0] mapper_sdrc_addr;
    wire [3:0] mapper_sdrc_dqm;
    wire [31:0] mapper_sdrc_data;
    wire [7:0] mapper_sdrc_data_len;
    wire test_sdrc_cmd_en;
    wire [2:0] test_sdrc_cmd;
    wire test_sdrc_precharge_ctrl;
    wire test_sdram_power_down;
    wire test_sdram_selfrefresh;
    wire [20:0] test_sdrc_addr;
    wire [3:0] test_sdrc_dqm;
    wire [31:0] test_sdrc_data;
    wire [7:0] test_sdrc_data_len;
    wire startup_test_passed;
    wire startup_test_failed;
    wire startup_test_wait_n;
    wire startup_test_led;
    wire native_sdram_rd;
    wire native_sdram_wr;
    wire native_sdram_refresh;
    wire [22:0] native_sdram_addr;
    wire [15:0] native_sdram_din;
    wire [1:0] native_sdram_wdm;
    wire [15:0] native_sdram_dout;
    wire [31:0] native_sdram_dout32;
    wire native_sdram_data_ready;
    wire native_sdram_busy;
    wire native_sdram_enabled;

    always_ff @(posedge main_clk or negedge board_reset_n)
    begin
        if (!board_reset_n) begin
            // s2_sync <= 2'b00;
            board_enabled <= 1'b0;
        end else begin
            // s2_sync <= {s2_sync[0], s2};
            //if (s2_sync == 2'b01) begin
                board_enabled <= 1'b1;
            //end
        end
    end

    assign board_reset_n = rpll_main_lock && reset_n;
    
    input_debouncer
    #(
        .WIDTH(3)
    )
    bus_data_debouncer(
        .clk(main_clk),
        .reset_n(board_reset_n),
        .in({rd_n_in, wr_n_in, sltsl_n_in}),
        .out({rd_n, wr_n, sltsl_n})
    );

    input_debouncer
    #(
        .WIDTH(8)
    )
    bus_control_debouncer(
        .clk(main_clk),
        .reset_n(board_reset_n),
        .in(cd),
        .out(cd_in)
    );

    mp_debouncer mp_debouncer_inst(
        .clk(main_clk),
        .reset_n(board_reset_n),
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
        .reset_n(board_enabled),
        .addr(addr),
        .data_in(cd_in),
        .merq_n(merq_n),
        .iorq_n(iorq_n),
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

    sdram_startup_test
    #(
        .CLK_FREQ_HZ(108_000_000),
        .USE_ADDRESS_PATTERN(1'b1)
    )
    sdram_startup_test_inst(
        .clk(main_clk),
        .reset_n(board_enabled),
        .sdrc_init_done(sdrc_init_done),
        .sdrc_cmd_ack(sdrc_cmd_ack),
        .sdrc_data_in(sdrc_data_in),
        .sdrc_cmd_en(test_sdrc_cmd_en),
        .sdrc_cmd(test_sdrc_cmd),
        .sdrc_precharge_ctrl(test_sdrc_precharge_ctrl),
        .sdram_power_down(test_sdram_power_down),
        .sdram_selfrefresh(test_sdram_selfrefresh),
        .sdrc_addr(test_sdrc_addr),
        .sdrc_dqm(test_sdrc_dqm),
        .sdrc_data(test_sdrc_data),
        .sdrc_data_len(test_sdrc_data_len),
        .test_passed(startup_test_passed),
        .test_failed(startup_test_failed),
        .wait_n(startup_test_wait_n),
        .led(startup_test_led)
    );

    sdram_mapper sdram_mapper_inst(
        .clk(main_clk),
        .reset_n(board_enabled && startup_test_passed),
        .addr(addr),
        .data_in(cd_in),
        .merq_n(merq_n),
        .iorq_n(iorq_n),
        .rd_n(rd_n),
        .wr_n(wr_n),
        .rfsh_n(rfsh_n),
        .m1_n(m1_n),
        .sltsl_n(sltsl_n),
        .page0_subslot_en(page0_subslot_en),
        .page1_subslot_en(page1_subslot_en),
        .page2_subslot_en(page2_subslot_en),
        .page3_subslot_en(page3_subslot_en),
        .data_out(sdram_mapper_data_out),
        .data_out_en(sdram_mapper_data_out_en),
        .wait_n(),
        .sdrc_cmd_en(mapper_sdrc_cmd_en),
        .sdrc_cmd(mapper_sdrc_cmd),
        .sdrc_precharge_ctrl(mapper_sdrc_precharge_ctrl),
        .sdram_power_down(mapper_sdram_power_down),
        .sdram_selfrefresh(mapper_sdram_selfrefresh),
        .sdrc_addr(mapper_sdrc_addr),
        .sdrc_dqm(mapper_sdrc_dqm),
        .sdrc_data(mapper_sdrc_data),
        .sdrc_data_len(mapper_sdrc_data_len),
        .sdrc_data_in(sdrc_data_in),
        .sdrc_init_done(sdrc_init_done),
        .sdrc_cmd_ack(sdrc_cmd_ack)
    );

    assign sdrc_cmd_en = board_enabled ?
        (startup_test_passed ? mapper_sdrc_cmd_en : test_sdrc_cmd_en) : 1'b0;
    assign sdrc_cmd = startup_test_passed ? mapper_sdrc_cmd : test_sdrc_cmd;
    assign sdrc_precharge_ctrl = startup_test_passed ? mapper_sdrc_precharge_ctrl : test_sdrc_precharge_ctrl;
    assign sdram_power_down = startup_test_passed ? mapper_sdram_power_down : test_sdram_power_down;
    assign sdram_selfrefresh = startup_test_passed ? mapper_sdram_selfrefresh : test_sdram_selfrefresh;
    assign sdrc_addr = startup_test_passed ? mapper_sdrc_addr : test_sdrc_addr;
    assign sdrc_dqm = startup_test_passed ? mapper_sdrc_dqm : test_sdrc_dqm;
    assign sdrc_data = startup_test_passed ? mapper_sdrc_data : test_sdrc_data;
    assign sdrc_data_len = startup_test_passed ? mapper_sdrc_data_len : test_sdrc_data_len;

    assign data_out = sdram_mapper_data_out_en ? sdram_mapper_data_out : slot_expander_data_out;
    //assign data_out = slot_expander_data_out;

    assign data_out_en = board_enabled && (sdram_mapper_data_out_en || slot_expander_data_out_en);
    //assign data_out_en = board_enabled && (slot_expander_data_out_en);

    assign mapper_port_read = board_enabled && !iorq_n && m1_n && !rd_n && addr[7:2] == 6'b111111;
    
    cd_demux cd_demux_inst(
        .data_out(data_out),
        .data_out_en(data_out_en),
        .wait_in_n(startup_test_wait_n),
        .rd_n(rd_n),
        .sltsl_n(sltsl_n),
        .mapper_port_read(mapper_port_read),
        .cd(cd),
        .busdir_n(busdir_n),
        .datadir(datadir),
        .wait_n(wait_n)
    );

    sdram_command_adapter sdram_command_adapter_inst(
        .clk(main_clk),
        .reset_n(board_enabled),
        .rfsh_n(rfsh_n),
        .cmd_en(sdrc_cmd_en),
        .cmd(sdrc_cmd),
        .cmd_addr(sdrc_addr),
        .cmd_dqm(sdrc_dqm),
        .cmd_data(sdrc_data),
        .read_data(sdrc_data_in),
        .init_done(sdrc_init_done),
        .cmd_ack(sdrc_cmd_ack),
        .rd(native_sdram_rd),
        .wr(native_sdram_wr),
        .refresh(native_sdram_refresh),
        .addr(native_sdram_addr),
        .din(native_sdram_din),
        .wdm(native_sdram_wdm),
        .dout32(native_sdram_dout32),
        .data_ready(native_sdram_data_ready),
        .busy(native_sdram_busy),
        .enabled(native_sdram_enabled)
    );

    sdram
    #(
        .FREQ(108_000_000),
        .CAS(5'd3),
        .T_WR(5'd3),
        .T_MRD(5'd2),
        .T_RP(5'd2),
        .T_RCD(5'd2),
        .T_RC(5'd7)
    )
    sdram_inst(
        .SDRAM_DQ(IO_sdram_dq),
        .SDRAM_A(O_sdram_addr),
        .SDRAM_BA(O_sdram_ba),
        .SDRAM_nCS(O_sdram_cs_n),
        .SDRAM_nWE(O_sdram_wen_n),
        .SDRAM_nRAS(O_sdram_ras_n),
        .SDRAM_nCAS(O_sdram_cas_n),
        .SDRAM_CLK(O_sdram_clk),
        .SDRAM_CKE(O_sdram_cke),
        .SDRAM_DQM(O_sdram_dqm),
        .clk(main_clk),
        .clk_sdram(sdram_clk),
        .resetn(board_enabled),
        .rd(native_sdram_rd),
        .wr(native_sdram_wr),
        .refresh(native_sdram_refresh),
        .addr(native_sdram_addr),
        .din(native_sdram_din),
        .wdm(native_sdram_wdm),
        .dout(native_sdram_dout),
        .dout32(native_sdram_dout32),
        .data_ready(native_sdram_data_ready),
        .busy(native_sdram_busy),
        .enabled(native_sdram_enabled)
    );

    // triggers cpu interrupt (open collector)
    assign int_n = 1'b1;

    assign int_out = ~int_n;
    assign wait_out = ~wait_n;

    assign led = startup_test_led;

endmodule
