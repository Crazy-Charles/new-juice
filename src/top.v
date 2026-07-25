module top
(
    input   clkin,
    input   s1,
    input   s2,

    output hp_ws,
    output hp_din,
    output hp_bck,
    output pa_en,

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
    output mspi_cs,
    output mspi_sclk,
    inout mspi_miso,
    inout mspi_mosi,
 
    // MicroSD
    output sd_sclk,
    inout sd_cmd,
    inout sd_dat0,
    output sd_dat1,
    output sd_dat2,
    output sd_dat3,
   
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

    // The external MSX CPU clock is sampled in the 108 MHz domain. It is not
    // used directly as an FPGA clock, avoiding a large asynchronous global
    // clock tree and its associated skew.
    wire cpu_clk = cpu_clkin;

    reg reset_n = 0;
    always_ff @(posedge clk) reset_n <= ~s1;
    wire board_reset_n;
    wire active_module_reset_n;
    reg [1:0] s2_sync = 2'b00;
    reg board_enabled = 1'b0;

    wire audio_bclk_raw;
    wire audio_bclk_rise;
    wire audio_req;
    wire audio_hp_bck;
    wire audio_hp_ws;
    wire audio_hp_din;
    wire [13:0] psg_pcm;
    wire signed [15:0] psg_audio_sample;
    wire signed [15:0] opll_audio_sample;
    wire signed [10:0] scc_sound;
    wire signed [15:0] scc_audio_sample;
    wire signed [17:0] audio_mix_wide;
    wire [15:0] mixed_audio_sample;
    reg [15:0] audio_sample_hold = 16'd0;
    (* syn_preserve = 1, ASYNC_REG = "TRUE" *)
    reg [1:0] audio_req_sync = 2'b00;
    reg audio_req_sync_d = 1'b0;

    // Diagnostic switches. Keep the audio logic running while its physical
    // pins remain static to distinguish an RTL problem from reconfiguration
    // behavior on the dual-purpose SSPI pins.
    localparam AUDIO_LOGIC_ENABLED = 1'b1;
    localparam AUDIO_BCK_ENABLED = 1'b1;
    localparam AUDIO_WS_ENABLED = 1'b1;
    localparam AUDIO_WS_IDLE_HIGH = 1'b0;
    localparam AUDIO_DIN_ENABLED = 1'b1;
    localparam AUDIO_PA_ENABLED = 1'b1;
    localparam INCLUDE_OPLL = 1'b1;

    generate
        if (AUDIO_LOGIC_ENABLED) begin : audio_logic_enabled
            clockdiv #(
                .CLK_HZ(27_000_000),
                .OUT_HZ(705_600)
            ) audio_clock_divider (
                .clk_src(clk),
                .reset_n(board_reset_n),
                .clk_div(audio_bclk_raw),
                .clk_rise(audio_bclk_rise)
            );

            audio_drive audio_drive_inst (
                .clk(clk),
                .bit_enable(audio_bclk_rise),
                .bit_clock(audio_bclk_raw),
                .rst_n(board_reset_n),
                .idata(audio_sample_hold),
                .req(audio_req),
                .HP_BCK(audio_hp_bck),
                .HP_WS(audio_hp_ws),
                .HP_DIN(audio_hp_din)
            );
        end else begin : audio_logic_disabled
            assign audio_bclk_raw = 1'b0;
            assign audio_bclk_rise = 1'b0;
            assign audio_req = 1'b0;
            assign audio_hp_bck = 1'b0;
            assign audio_hp_ws = 1'b0;
            assign audio_hp_din = 1'b0;
        end

        if (AUDIO_BCK_ENABLED) begin : audio_bck_enabled
            assign hp_bck = audio_hp_bck;
        end else begin : audio_bck_disabled
            assign hp_bck = 1'b0;
        end

        if (AUDIO_WS_ENABLED) begin : audio_ws_enabled
            assign hp_ws = audio_hp_ws;
        end else begin : audio_ws_disabled
            assign hp_ws = AUDIO_WS_IDLE_HIGH;
        end

        if (AUDIO_DIN_ENABLED) begin : audio_din_enabled
            assign hp_din = audio_hp_din;
        end else begin : audio_din_disabled
            assign hp_din = 1'b0;
        end

        if (AUDIO_PA_ENABLED) begin : audio_pa_enabled
            assign pa_en = 1'b1;
        end else begin : audio_pa_disabled
            assign pa_en = 1'b0;
        end
    endgenerate
    
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

    // audio_req is asserted for one audio bit-clock cycle before audio_drive
    // loads idata. Synchronize that request into the 108 MHz domain and take
    // one coherent snapshot of the mix. The holding register then remains
    // stable for far longer than the audio-domain setup/hold requirement.
    always_ff @(posedge main_clk or negedge board_reset_n)
    begin
        if (!board_reset_n) begin
            audio_req_sync <= 2'b00;
            audio_req_sync_d <= 1'b0;
            audio_sample_hold <= 16'd0;
        end else begin
            audio_req_sync <= {audio_req_sync[0], audio_req};
            audio_req_sync_d <= audio_req_sync[1];

            if (audio_req_sync[1] && !audio_req_sync_d)
                audio_sample_hold <= mixed_audio_sample;
        end
    end

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
    wire [7:0] flash_rom_data_out;
    wire flash_rom_data_out_en;
    wire flash_rom_wait_n;
    wire flash_rom_loaded;
    wire mapper_wait_n;
    wire [7:0] smr_data_out;
    wire smr_data_out_en;
    wire smr_wait_n;
    wire [7:0] sd_data_out;
    wire sd_data_out_en;
    wire sd_overlay_enabled;
    wire sd_busy;
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
    wire smr_sdrc_cmd_en;
    wire [2:0] smr_sdrc_cmd;
    wire [20:0] smr_sdrc_addr;
    wire [3:0] smr_sdrc_dqm;
    wire [31:0] smr_sdrc_data;
    wire rom_sdrc_cmd_en;
    wire [2:0] rom_sdrc_cmd;
    wire [20:0] rom_sdrc_addr;
    wire [3:0] rom_sdrc_dqm;
    wire [31:0] rom_sdrc_data;
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
    reg [2:0] psg_cpu_clk_sync = 3'b000;
    reg psg_clock_phase = 1'b0;
    reg psg_clock_enable = 1'b0;
    reg cpu_clock_rise_enable = 1'b0;
    wire psg_address_write;
    wire psg_data_write;
    wire psg_bdir;
    wire psg_bc;
    wire [7:0] psg_data_out_unused;
    wire [11:0] psg_channel_a_unused;
    wire [11:0] psg_channel_b_unused;
    wire [11:0] psg_channel_c_unused;
    wire [13:0] psg_mix_unsigned_unused;
    wire opll_write_selected;

    always_ff @(posedge main_clk or negedge board_reset_n)
    begin
        if (!board_reset_n) begin
            board_enabled <= 1'b0;
        end else begin
            board_enabled <= 1'b1;
        end
    end

    assign board_reset_n = rpll_main_lock && reset_n;

    // Synchronize the external 3.58 MHz CPU clock into the 108 MHz domain.
    // Every second detected rising edge produces one main_clk-wide enable,
    // giving the PSG its required ~1.789 MHz operating rate.
    always_ff @(posedge main_clk or negedge board_reset_n)
    begin
        if (!board_reset_n) begin
            psg_cpu_clk_sync <= 3'b000;
            psg_clock_phase <= 1'b0;
            psg_clock_enable <= 1'b0;
            cpu_clock_rise_enable <= 1'b0;
        end else begin
            psg_cpu_clk_sync <= {psg_cpu_clk_sync[1:0], cpu_clk};
            psg_clock_enable <= 1'b0;
            cpu_clock_rise_enable <= 1'b0;

            if (psg_cpu_clk_sync[1] && !psg_cpu_clk_sync[2]) begin
                cpu_clock_rise_enable <= 1'b1;
                psg_clock_phase <= ~psg_clock_phase;
                if (psg_clock_phase)
                    psg_clock_enable <= 1'b1;
            end
        end
    end

    // MSX PSG I/O ports. This is deliberately a write-only slave: port A2
    // reads are not decoded and the PSG output data is never put on cd.
    assign psg_address_write = board_enabled && !iorq_n && m1_n && !wr_n &&
                               addr[7:0] == 8'hA0;
    assign psg_data_write = board_enabled && !iorq_n && m1_n && !wr_n &&
                            addr[7:0] == 8'hA1;
    assign psg_bdir = psg_address_write || psg_data_write;
    assign psg_bc = psg_address_write;

    ym2149_audio psg_inst (
        .clk_i(main_clk),
        .en_clk_psg_i(psg_clock_enable),
        .sel_n_i(1'b1),
        .reset_n_i(board_reset_n),
        .bc_i(psg_bc),
        .bdir_i(psg_bdir),
        .data_i(cd_in),
        .data_r_o(psg_data_out_unused),
        .ch_a_o(psg_channel_a_unused),
        .ch_b_o(psg_channel_b_unused),
        .ch_c_o(psg_channel_c_unused),
        .mix_audio_o(psg_mix_unsigned_unused),
        .pcm14s_o(psg_pcm)
    );

    // MSX-Music/YM2413 ports 7C (address) and 7D (data). Both are write-only.
    assign opll_write_selected = board_enabled && !iorq_n && m1_n && !wr_n &&
                                 addr[7:1] == 7'h3E;

    generate
        if (INCLUDE_OPLL) begin : opll_enabled_impl
            wire [13:0] opll_audio_raw;

            // Run VM2413 on its native MSX clock so its internal paths are
            // timed at the rate for which the core was designed.
            opll opll_inst (
                .xin(cpu_clk),
                .xout(),
                .xena(1'b1),
                .d(cd_in),
                .a(addr[0]),
                .cs_n(~opll_write_selected),
                .we_n(wr_n),
                .ic_n(active_module_reset_n),
                .mixout(opll_audio_raw)
            );

            // VM2413 mixout is signed, zero-centered 14-bit PCM.
            assign opll_audio_sample =
                {{2{opll_audio_raw[13]}}, opll_audio_raw};
        end else begin : opll_disabled_impl
            assign opll_audio_sample = 16'sd0;
        end
    endgenerate

    // pcm14s_o deliberately recenters disabled channels around a negative DC
    // level, which is inappropriate for this digital output path. The unsigned
    // mix has true zero at silence and avoids the constant boot-time noise.
    assign psg_audio_sample = {2'b00, psg_mix_unsigned_unused};
    // Scale the 11-bit SCC output into the same useful range, then saturate
    // the three-source mix instead of allowing peaks to wrap around.
    assign scc_audio_sample = {scc_sound, 5'b00000};
    assign audio_mix_wide =
        {{2{psg_audio_sample[15]}}, psg_audio_sample} +
        {{2{opll_audio_sample[15]}}, opll_audio_sample} +
        {{2{scc_audio_sample[15]}}, scc_audio_sample};
    assign mixed_audio_sample =
        audio_mix_wide[17:15] == 3'b000 ||
        audio_mix_wide[17:15] == 3'b111 ? audio_mix_wide[15:0] :
        audio_mix_wide[17] ? 16'h8000 :
                             16'h7FFF;
    
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

    // Keep all CPU-bus-visible state at deterministic defaults until both the
    // internal memories are ready and the MSX has released its reset signal.
    assign active_module_reset_n =
        board_enabled && flash_rom_loaded && reset_in_n;

    slot_expander slot_expander_inst(
        .clk(main_clk),
        .reset_n(active_module_reset_n),
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
        .reset_n(active_module_reset_n),
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
        .wait_n(mapper_wait_n),
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

    super_megaram #(
        .INCLUDE_SCC(1'b1)
    ) super_megaram_inst(
        .clk(main_clk),
        .cpu_clk(cpu_clk),
        .reset_n(active_module_reset_n),
        .addr(addr),
        .data_in(cd_in),
        .merq_n(merq_n),
        .iorq_n(iorq_n),
        .rd_n(rd_n),
        .wr_n(wr_n),
        .rfsh_n(rfsh_n),
        .m1_n(m1_n),
        .sltsl_n(sltsl_n),
        .page1_subslot_en(page1_subslot_en),
        .page2_subslot_en(page2_subslot_en),
        .data_out(smr_data_out),
        .data_out_en(smr_data_out_en),
        .wait_n(smr_wait_n),
        .scc_sound(scc_sound),
        .sdrc_cmd_en(smr_sdrc_cmd_en),
        .sdrc_cmd(smr_sdrc_cmd),
        .sdrc_addr(smr_sdrc_addr),
        .sdrc_dqm(smr_sdrc_dqm),
        .sdrc_data(smr_sdrc_data),
        .sdrc_data_in(sdrc_data_in),
        .sdrc_init_done(sdrc_init_done),
        .sdrc_cmd_ack(sdrc_cmd_ack)
    );

    sd_registers sd_registers_inst(
        .clk(main_clk),
        .sd_clk(clk),
        // Start SD initialization as soon as the FPGA clocks are ready. Do
        // not hold the card controller in reset while waiting for the MSX
        // CPU reset or BIOS flash loading to complete.
        .reset_n(board_enabled),
        .cpu_clk(cpu_clk),
        .addr(addr),
        .data_in(cd_in),
        .merq_n(merq_n),
        .iorq_n(iorq_n),
        .m1_n(m1_n),
        .rd_n(rd_n),
        .wr_n(wr_n),
        .sltsl_n(sltsl_n),
        .subslot0_selected(page1_subslot_en[0]),
        .data_out(sd_data_out),
        .data_out_en(sd_data_out_en),
        .overlay_enabled(sd_overlay_enabled),
        .busy(sd_busy),
        .sd_sclk(sd_sclk),
        .sd_cmd(sd_cmd),
        .sd_dat0(sd_dat0),
        .sd_dat1(sd_dat1),
        .sd_dat2(sd_dat2),
        .sd_dat3(sd_dat3)
    );

    flash_roms flash_roms_inst(
        .clk(main_clk),
        .reset_n(board_enabled),
        .load_enable(startup_test_passed),
        .addr(addr),
        .data_in(cd_in),
        .merq_n(merq_n),
        .iorq_n(iorq_n),
        .rd_n(rd_n),
        .wr_n(wr_n),
        .rfsh_n(rfsh_n),
        .sltsl_n(sltsl_n),
        .page1_subslot_en(page1_subslot_en),
        .dos2_overlay_enabled(sd_overlay_enabled),
        .data_out(flash_rom_data_out),
        .data_out_en(flash_rom_data_out_en),
        .wait_n(flash_rom_wait_n),
        .loaded(flash_rom_loaded),
        .mspi_cs(mspi_cs),
        .mspi_sclk(mspi_sclk),
        .mspi_miso(mspi_miso),
        .mspi_mosi(mspi_mosi),
        .sdrc_cmd_en(rom_sdrc_cmd_en),
        .sdrc_cmd(rom_sdrc_cmd),
        .sdrc_addr(rom_sdrc_addr),
        .sdrc_dqm(rom_sdrc_dqm),
        .sdrc_data(rom_sdrc_data),
        .sdrc_data_in(sdrc_data_in),
        .sdrc_cmd_ack(sdrc_cmd_ack)
    );

    assign sdrc_cmd_en = board_enabled ?
        (startup_test_passed ?
            (rom_sdrc_cmd_en || smr_sdrc_cmd_en || mapper_sdrc_cmd_en) :
            test_sdrc_cmd_en) : 1'b0;
    assign sdrc_cmd = startup_test_passed ?
        (rom_sdrc_cmd_en ? rom_sdrc_cmd :
         smr_sdrc_cmd_en ? smr_sdrc_cmd : mapper_sdrc_cmd) :
        test_sdrc_cmd;
    assign sdrc_precharge_ctrl = startup_test_passed ? mapper_sdrc_precharge_ctrl : test_sdrc_precharge_ctrl;
    assign sdram_power_down = startup_test_passed ? mapper_sdram_power_down : test_sdram_power_down;
    assign sdram_selfrefresh = startup_test_passed ? mapper_sdram_selfrefresh : test_sdram_selfrefresh;
    assign sdrc_addr = startup_test_passed ?
        (rom_sdrc_cmd_en ? rom_sdrc_addr :
         smr_sdrc_cmd_en ? smr_sdrc_addr : mapper_sdrc_addr) :
        test_sdrc_addr;
    assign sdrc_dqm = startup_test_passed ?
        (rom_sdrc_cmd_en ? rom_sdrc_dqm :
         smr_sdrc_cmd_en ? smr_sdrc_dqm : mapper_sdrc_dqm) :
        test_sdrc_dqm;
    assign sdrc_data = startup_test_passed ?
        (rom_sdrc_cmd_en ? rom_sdrc_data :
         smr_sdrc_cmd_en ? smr_sdrc_data : mapper_sdrc_data) :
        test_sdrc_data;
    assign sdrc_data_len = startup_test_passed ? mapper_sdrc_data_len : test_sdrc_data_len;

    assign data_out = sd_data_out_en ? sd_data_out :
                      flash_rom_data_out_en ? flash_rom_data_out :
                      smr_data_out_en ? smr_data_out :
                      sdram_mapper_data_out_en ? sdram_mapper_data_out : slot_expander_data_out;

    assign data_out_en = active_module_reset_n &&
        (sd_data_out_en || flash_rom_data_out_en ||
         smr_data_out_en || sdram_mapper_data_out_en ||
         slot_expander_data_out_en);

    assign mapper_port_read = active_module_reset_n &&
        !iorq_n && m1_n && !rd_n && addr[7:2] == 6'b111111;
    
    cd_demux cd_demux_inst(
        .data_out(data_out),
        .data_out_en(data_out_en),
        .wait_in_n(startup_test_wait_n && flash_rom_wait_n &&
                   smr_wait_n && mapper_wait_n),
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

    // Before the SDRAM test passes, preserve its failure-code blinker.
    // Afterwards the LED indicates an active SD-card command.
    assign led = startup_test_passed ? sd_busy : startup_test_led;

endmodule
