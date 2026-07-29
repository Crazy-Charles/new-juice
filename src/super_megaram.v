module super_megaram
#(
    // Keep the mapper fully operational while allowing IKASCC to be compiled
    // out for timing/isolation testing.
    parameter INCLUDE_SCC = 1'b0
)
(
    input clk,
    input cpu_clk,
    input reset_n,

    input [15:0] addr,
    input [7:0] data_in,
    input merq_n,
    input iorq_n,
    input rd_n,
    input wr_n,
    input rfsh_n,
    input m1_n,
    input sltsl_n,
    input [3:0] page0_subslot_en,
    input [3:0] page1_subslot_en,
    input [3:0] page2_subslot_en,

    output [7:0] data_out,
    output data_out_en,
    output wait_n,
    output signed [10:0] scc_sound,

    output sdrc_cmd_en,
    output [2:0] sdrc_cmd,
    output [20:0] sdrc_addr,
    output [3:0] sdrc_dqm,
    output [31:0] sdrc_data,
    input [31:0] sdrc_data_in,
    input sdrc_init_done,
    input sdrc_cmd_ack
);

    localparam [4:0] MODE_DDX_SCC = 5'd0;
    localparam [4:0] MODE_DDX = 5'd1;
    localparam [4:0] MODE_K4 = 5'd4;
    localparam [4:0] MODE_K5 = 5'd5;
    localparam [4:0] MODE_ASCII8 = 5'd8;
    // Internal encoding is independent of the command byte written to 8Fh.
    // Keep it at 16 so selecting ASCII16 does not perturb its datapath decode.
    localparam [4:0] MODE_ASCII16 = 5'd16;

    localparam [2:0] SDRAM_CMD_READ = 3'b101;
    localparam [2:0] SDRAM_CMD_WRITE = 3'b100;
    localparam [22:0] SDRAM_SMR_BASE = 23'h400000;

    localparam [2:0] STATE_IDLE = 3'd0;
    localparam [2:0] STATE_CMD = 3'd1;
    localparam [2:0] STATE_WAIT_ACK = 3'd2;
    localparam [2:0] STATE_DONE = 3'd3;

    reg [4:0] operation_mode = MODE_DDX_SCC;
    reg rom_mode = 1'b1;
    reg [7:0] bank [0:3];

    reg [2:0] state = STATE_IDLE;
    reg access_is_read = 1'b0;
    reg [1:0] access_byte_lane = 2'b00;
    reg [7:0] read_data = 8'hff;
    reg [20:0] sdrc_addr_reg = 21'd0;
    reg [3:0] sdrc_dqm_reg = 4'b1111;
    reg [31:0] sdrc_data_reg = 32'd0;
    reg [2:0] sdrc_cmd_reg = SDRAM_CMD_READ;
    reg sdrc_cmd_en_reg = 1'b0;
    reg cpu_cycle_seen = 1'b0;
    reg read_data_active = 1'b0;
    reg [15:0] ikascc_addr_latched = 16'd0;
    reg [7:0] ikascc_data_latched = 8'd0;

    reg bank_write_selected;
    reg [1:0] bank_write_index;

    wire port_8e_selected = !iorq_n && m1_n && addr[7:0] == 8'h8e;
    wire port_8f_write = !iorq_n && m1_n && !wr_n &&
                         addr[7:0] == 8'h8f;

    // Of the accepted port-8F mode encodings, only K4 (4) and K5 (5)
    // have bit 2 set. Keep this decode shallow because it feeds the
    // CPU-to-SDRAM command path.
    wire page0_fixed_mode = operation_mode[2];
    wire page0_smr_selected = !sltsl_n && page0_subslot_en[2] &&
                              page0_fixed_mode;
    wire page1_smr_selected = !sltsl_n && page1_subslot_en[2];
    wire page2_smr_selected = !sltsl_n && page2_subslot_en[2];
    wire smr_slot_selected =
        (addr[15:14] == 2'b00 && page0_smr_selected) ||
        (addr[15:14] == 2'b01 && page1_smr_selected) ||
        (addr[15:14] == 2'b10 && page2_smr_selected);
    wire memory_cycle = !merq_n && iorq_n && rfsh_n && smr_slot_selected;

    wire scc_mode = operation_mode == MODE_DDX_SCC ||
                    operation_mode == MODE_K5;
    wire scc_window = addr[15:11] == 5'b10011;
    wire scc_enabled = scc_mode && bank[2] == 8'h3f;
    wire scc_window_active = INCLUDE_SCC && scc_enabled && scc_window;
    wire scc_access_selected = memory_cycle && scc_window_active &&
                               (!rd_n || !wr_n);

    always @(*)
    begin
        bank_write_selected = 1'b0;
        bank_write_index = 2'd0;

        if (memory_cycle && rom_mode && !wr_n) begin
            case (operation_mode)
                MODE_DDX_SCC, MODE_DDX: begin
                    if (addr[11:0] == 12'h000) begin
                        case (addr[15:12])
                            4'h4, 4'h5: begin bank_write_selected = 1'b1; bank_write_index = 2'd0; end
                            4'h6, 4'h7: begin bank_write_selected = 1'b1; bank_write_index = 2'd1; end
                            4'h8, 4'h9: begin bank_write_selected = 1'b1; bank_write_index = 2'd2; end
                            4'ha, 4'hb: begin bank_write_selected = 1'b1; bank_write_index = 2'd3; end
                            default: ;
                        endcase
                    end
                end
                MODE_ASCII8: begin
                    if (addr >= 16'h6000 && addr <= 16'h67ff) begin
                        bank_write_selected = 1'b1;
                        bank_write_index = 2'd0;
                    end else if (addr >= 16'h6800 && addr <= 16'h6fff) begin
                        bank_write_selected = 1'b1;
                        bank_write_index = 2'd1;
                    end else if (addr >= 16'h7000 && addr <= 16'h77ff) begin
                        bank_write_selected = 1'b1;
                        bank_write_index = 2'd2;
                    end else if (addr >= 16'h7800 && addr <= 16'h7fff) begin
                        bank_write_selected = 1'b1;
                        bank_write_index = 2'd3;
                    end
                end
                MODE_ASCII16: begin
                    if (addr >= 16'h6000 && addr <= 16'h67ff) begin
                        bank_write_selected = 1'b1;
                        bank_write_index = 2'd0;
                    end else if (addr >= 16'h7000 && addr <= 16'h77ff) begin
                        bank_write_selected = 1'b1;
                        bank_write_index = 2'd2;
                    end
                end
                MODE_K4: begin
                    if (addr >= 16'h4000 && addr <= 16'h5fff) begin
                        bank_write_selected = 1'b1;
                        bank_write_index = 2'd0;
                    end else if (addr >= 16'h6000 && addr <= 16'h7fff) begin
                        bank_write_selected = 1'b1;
                        bank_write_index = 2'd1;
                    end else if (addr >= 16'h8000 && addr <= 16'h9fff) begin
                        bank_write_selected = 1'b1;
                        bank_write_index = 2'd2;
                    end else if (addr >= 16'ha000 && addr <= 16'hbfff) begin
                        bank_write_selected = 1'b1;
                        bank_write_index = 2'd3;
                    end
                end
                MODE_K5: begin
                    if (addr >= 16'h5000 && addr <= 16'h57ff) begin
                        bank_write_selected = 1'b1;
                        bank_write_index = 2'd0;
                    end else if (addr >= 16'h7000 && addr <= 16'h77ff) begin
                        bank_write_selected = 1'b1;
                        bank_write_index = 2'd1;
                    end else if (addr >= 16'h9000 && addr <= 16'h97ff) begin
                        bank_write_selected = 1'b1;
                        bank_write_index = 2'd2;
                    end else if (addr >= 16'hb000 && addr <= 16'hb7ff) begin
                        bank_write_selected = 1'b1;
                        bank_write_index = 2'd3;
                    end
                end
                default: ;
            endcase
        end
    end

    // SCC accesses and ROM-mode mapper writes are mutually exclusive with
    // SDRAM accesses. Decode that directly so neither the IKASCC select nor
    // the mapper-write network sits in the SDRAM command/address path.
    wire memory_read_selected =
        memory_cycle && !rd_n && !scc_window_active;
    wire memory_write_selected =
        memory_cycle && !wr_n && !rom_mode && !scc_window_active;
    wire memory_access_selected =
        memory_read_selected || memory_write_selected;

    // K4 and K5 expose a fixed physical bank throughout page 0. This
    // deliberately bypasses the programmable bank registers.
    wire [7:0] selected_8k_bank =
        (addr[15:14] == 2'b00) ?
            {6'b000000, operation_mode[0], 1'b0} :
        (addr[15:13] == 3'b010) ? bank[0] :
        (addr[15:13] == 3'b011) ? bank[1] :
        (addr[15:13] == 3'b100) ? bank[2] :
                                  bank[3];
    wire [6:0] selected_16k_bank =
        (addr[15:14] == 2'b01) ? bank[0][6:0] : bank[2][6:0];
    wire [20:0] selected_smr_offset =
        (operation_mode == MODE_ASCII16) ?
            {selected_16k_bank, addr[13:0]} :
            {selected_8k_bank, addr[12:0]};
    wire [22:0] selected_sdram_byte_addr =
        SDRAM_SMR_BASE + {2'b00, selected_smr_offset};
    wire [1:0] byte_lane = selected_sdram_byte_addr[1:0];
    wire [3:0] byte_dqm =
        (byte_lane == 2'd0) ? 4'b1110 :
        (byte_lane == 2'd1) ? 4'b1101 :
        (byte_lane == 2'd2) ? 4'b1011 :
                              4'b0111;

    wire cpu_cycle_active = memory_access_selected && sdrc_init_done;
    wire start_access = state == STATE_IDLE && cpu_cycle_active &&
                        !cpu_cycle_seen;
    wire [4:0] ikascc_mapper_addr =
        (bank_write_index == 2'd0) ? 5'b01010 :
        (bank_write_index == 2'd1) ? 5'b01110 :
        (bank_write_index == 2'd2) ? 5'b10010 :
                                     5'b10110;
    wire ikascc_bus_selected = bank_write_selected || scc_access_selected;

    always_ff @(posedge clk or negedge reset_n)
    begin
        if (!reset_n) begin
            operation_mode <= MODE_DDX_SCC;
            rom_mode <= 1'b1;
            bank[0] <= 8'h00;
            bank[1] <= 8'h01;
            bank[2] <= 8'h02;
            bank[3] <= 8'h03;
            state <= STATE_IDLE;
            access_is_read <= 1'b0;
            access_byte_lane <= 2'b00;
            read_data <= 8'hff;
            sdrc_addr_reg <= 21'd0;
            sdrc_dqm_reg <= 4'b1111;
            sdrc_data_reg <= 32'd0;
            sdrc_cmd_reg <= SDRAM_CMD_READ;
            sdrc_cmd_en_reg <= 1'b0;
            cpu_cycle_seen <= 1'b0;
            read_data_active <= 1'b0;
            ikascc_addr_latched <= 16'd0;
            ikascc_data_latched <= 8'd0;
        end else begin
            sdrc_cmd_en_reg <= 1'b0;

            if (port_8e_selected && !rd_n)
                rom_mode <= 1'b0;
            else if (port_8e_selected && !wr_n)
                rom_mode <= 1'b1;

            if (port_8f_write) begin
                case (data_in)
                    8'd0: operation_mode <= MODE_DDX_SCC;
                    8'd1: operation_mode <= MODE_DDX;
                    8'd4: operation_mode <= MODE_K4;
                    8'd5: operation_mode <= MODE_K5;
                    8'd8: operation_mode <= MODE_ASCII8;
                    8'h16: operation_mode <= MODE_ASCII16;
                    // Invalid or transient commands recover to the power-on
                    // mapper instead of retaining an arbitrary previous mode.
                    default: operation_mode <= MODE_DDX_SCC;
                endcase
            end

            if (bank_write_selected)
                bank[bank_write_index] <= data_in;

            if (ikascc_bus_selected) begin
                ikascc_addr_latched <=
                    {bank_write_selected ? ikascc_mapper_addr : addr[15:11],
                     addr[10:0]};
                ikascc_data_latched <= data_in;
            end

            if (!memory_read_selected)
                read_data_active <= 1'b0;

            if (!memory_access_selected)
                cpu_cycle_seen <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    if (start_access) begin
                        access_is_read <= memory_read_selected;
                        access_byte_lane <= byte_lane;
                        sdrc_addr_reg <= selected_sdram_byte_addr[22:2];
                        sdrc_dqm_reg <= byte_dqm;
                        sdrc_data_reg <= {4{data_in}};
                        sdrc_cmd_reg <= memory_read_selected ?
                                        SDRAM_CMD_READ : SDRAM_CMD_WRITE;
                        sdrc_cmd_en_reg <= 1'b1;
                        cpu_cycle_seen <= 1'b1;
                        state <= STATE_CMD;
                    end
                end
                STATE_CMD: begin
                    state <= STATE_WAIT_ACK;
                end
                STATE_WAIT_ACK: begin
                    if (sdrc_cmd_ack) begin
                        if (access_is_read) begin
                            case (access_byte_lane)
                                2'd0: read_data <= sdrc_data_in[7:0];
                                2'd1: read_data <= sdrc_data_in[15:8];
                                2'd2: read_data <= sdrc_data_in[23:16];
                                default: read_data <= sdrc_data_in[31:24];
                            endcase
                            if (memory_read_selected)
                                read_data_active <= 1'b1;
                        end
                        state <= STATE_DONE;
                    end
                end
                default: begin
                    if (!memory_access_selected)
                        state <= STATE_IDLE;
                end
            endcase
        end
    end

    generate
        if (INCLUDE_SCC) begin : scc_enabled_impl
            wire [7:0] ikascc_data_out;
            wire ikascc_data_out_en;
            wire signed [10:0] ikascc_sound;

            IKASCC #(
                .IMPL_TYPE(1),
                .RAM_BLOCK(1)
            ) ikascc_inst (
                .i_EMUCLK(cpu_clk),
                .i_MCLK_PCEN_n(1'b0),
                .i_RST_n(reset_n),
                .i_CS_n(~ikascc_bus_selected),
                .i_RD_n(rd_n),
                .i_WR_n(wr_n),
                .i_ABLO(ikascc_bus_selected ? addr[7:0] :
                                             ikascc_addr_latched[7:0]),
                .i_ABHI(ikascc_bus_selected ?
                            (bank_write_selected ?
                                ikascc_mapper_addr : addr[15:11]) :
                            ikascc_addr_latched[15:11]),
                .i_DB(ikascc_bus_selected ?
                          data_in : ikascc_data_latched),
                .o_DB(ikascc_data_out),
                .o_DB_OE(ikascc_data_out_en),
                .o_ROMCS_n(),
                .o_ROMADDR(),
                .o_SOUND(ikascc_sound),
                .o_TEST()
            );

            assign data_out =
                ikascc_data_out_en ? ikascc_data_out : read_data;
            assign data_out_en =
                (scc_access_selected && ikascc_data_out_en) ||
                (read_data_active && access_is_read &&
                 memory_read_selected);
            assign scc_sound = scc_mode ? ikascc_sound : 11'sd0;
        end else begin : scc_disabled_impl
            assign data_out = read_data;
            assign data_out_en =
                read_data_active && access_is_read &&
                memory_read_selected;
            assign scc_sound = 11'sd0;
        end
    endgenerate

    assign wait_n = !memory_access_selected ||
                    (sdrc_init_done && state == STATE_DONE);

    assign sdrc_cmd_en = sdrc_cmd_en_reg;
    assign sdrc_cmd = sdrc_cmd_reg;
    assign sdrc_addr = sdrc_addr_reg;
    assign sdrc_dqm = sdrc_dqm_reg;
    assign sdrc_data = sdrc_data_reg;

endmodule
