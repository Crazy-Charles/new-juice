module sd_registers
(
    input clk,
    input reset_n,
    input cpu_clk,
    input [15:0] addr,
    input [7:0] data_in,
    input merq_n,
    input iorq_n,
    input m1_n,
    input rd_n,
    input wr_n,
    input sltsl_n,
    input subslot0_selected,

    output [7:0] data_out,
    output data_out_en,
    output overlay_enabled,
    output busy,

    output sd_sclk,
    inout sd_cmd,
    inout sd_dat0,
    output sd_dat1,
    output sd_dat2,
    output sd_dat3
);

    localparam [15:0] SDC_SDATA       = 16'h7c00;
    localparam [15:0] SDC_ENABLE      = 16'h7e00;
    localparam [15:0] SDC_CMD         = SDC_ENABLE + 1;
    localparam [15:0] SDC_STATUS      = SDC_CMD + 1;
    localparam [15:0] SDC_SADDR       = SDC_STATUS + 1;
    localparam [15:0] SDC_C_SIZE      = SDC_SADDR + 4;
    localparam [15:0] SDC_C_SIZE_MULT = SDC_C_SIZE + 3;
    localparam [15:0] SDC_RD_BL_LEN   = SDC_C_SIZE_MULT + 1;
    localparam [15:0] SDC_CTYPE       = SDC_RD_BL_LEN + 1;
    localparam [15:0] SDC_MID         = SDC_CTYPE + 1;
    localparam [15:0] SDC_OID         = SDC_MID + 1;
    localparam [15:0] SDC_PNM         = SDC_OID + 2;
    localparam [15:0] SDC_PSN         = SDC_PNM + 5;
    localparam [15:0] SDC_END         = 16'h7eff;

    reg sd_enabled = 1'b0;
    reg sd_read_start = 1'b0;
    reg sd_write_start = 1'b0;
    reg sd_init_start = 1'b0;
    reg [31:0] sd_sector = 32'd0;
    reg [7:0] register_data = 8'hff;
    reg [1:0] cpu_clk_sync = 2'b00;
    reg write_cycle_seen = 1'b0;

    wire memory_cycle = !sltsl_n && subslot0_selected && !merq_n &&
                        iorq_n && m1_n;
    // The level-shifted CPU clock is asynchronous to main_clk. Synchronize
    // its level rather than debouncing it: at 3.58 MHz each phase spans many
    // 108 MHz clocks. As in the original WonderTANG design, CPU-side RAM and
    // register writes are allowed only during the high CPU-clock phase.
    wire cpu_clk_high = cpu_clk_sync[1];
    wire cpu_write_strobe = cpu_clk_high && memory_cycle && !wr_n &&
                            !write_cycle_seen;
    wire enable_write = cpu_write_strobe && addr == SDC_ENABLE;
    wire ram_selected = memory_cycle && sd_enabled &&
                        addr >= SDC_SDATA && addr < SDC_ENABLE;
    wire register_selected = memory_cycle && sd_enabled &&
                             addr >= SDC_ENABLE && addr <= SDC_END;

    wire [7:0] ram_data_out;
    wire [8:0] sd_data_addr;
    wire [7:0] sd_data_out;
    wire [7:0] sd_data_in;
    wire sd_data_enable;
    wire sd_done;
    wire [3:0] sd_card_status;
    wire [1:0] sd_card_type;
    wire [21:0] sd_c_size;
    wire [2:0] sd_c_size_mult;
    wire [3:0] sd_read_bl_len;
    wire [7:0] sd_mid;
    wire [15:0] sd_oid;
    wire [39:0] sd_pnm;
    wire [31:0] sd_psn;
    wire sd_crc_error;
    wire sd_timeout_error;

    dpram #(
        .widthad_a(9),
        .width_a(8)
    ) sector_ram (
        .clock_a(clk),
        .wren_a(ram_selected && cpu_write_strobe),
        .rden_a(ram_selected && cpu_clk_high && !rd_n),
        .address_a(addr[8:0]),
        .data_a(data_in),
        .q_a(ram_data_out),
        .clock_b(clk),
        .wren_b(sd_read_start && sd_data_enable),
        .rden_b(sd_write_start && sd_data_enable),
        .address_b(sd_data_addr),
        .data_b(sd_data_out),
        .q_b(sd_data_in)
    );

    sd_reader #(
        .CLK_DIV(3'd4),
        .SIMULATE(0)
    ) sd_card_controller (
        .rstn(reset_n),
        .clk(clk),
        .sdclk(sd_sclk),
        .sdcmd(sd_cmd),
        .sddat0(sd_dat0),
        .card_stat(sd_card_status),
        .card_type(sd_card_type),
        .rstart(sd_read_start),
        .rsector(sd_sector),
        .rbusy(busy),
        .rdone(sd_done),
        .outen(sd_data_enable),
        .outaddr(sd_data_addr),
        .outbyte(sd_data_out),
        .wstart(sd_write_start),
        .inbyte(sd_data_in),
        .c_size(sd_c_size),
        .c_size_mult(sd_c_size_mult),
        .read_bl_len(sd_read_bl_len),
        .mid(sd_mid),
        .oid(sd_oid),
        .pnm(sd_pnm),
        .psn(sd_psn),
        .crc_error(sd_crc_error),
        .timeout_error(sd_timeout_error),
        .init(sd_init_start)
    );

    // DAT1-DAT3 must remain high so the card starts in native SD mode.
    assign sd_dat1 = 1'b1;
    assign sd_dat2 = 1'b1;
    assign sd_dat3 = 1'b1;

    always_ff @(posedge clk or negedge reset_n)
    begin
        if (!reset_n) begin
            sd_enabled <= 1'b0;
            sd_read_start <= 1'b0;
            sd_write_start <= 1'b0;
            sd_init_start <= 1'b0;
            sd_sector <= 32'd0;
            register_data <= 8'hff;
            cpu_clk_sync <= 2'b00;
            write_cycle_seen <= 1'b0;
        end else begin
            cpu_clk_sync <= {cpu_clk_sync[0], cpu_clk};

            if (!cpu_clk_high || wr_n || !memory_cycle)
                write_cycle_seen <= 1'b0;
            else if (cpu_write_strobe)
                write_cycle_seen <= 1'b1;

            if (enable_write)
                sd_enabled <= data_in[0];

            if (sd_done) begin
                sd_read_start <= 1'b0;
                sd_write_start <= 1'b0;
            end

            if (register_selected && cpu_write_strobe) begin
                case (addr)
                    SDC_CMD: begin
                        sd_read_start <= sd_read_start | data_in[0];
                        sd_write_start <= sd_write_start | data_in[1];
                        sd_init_start <= sd_init_start | data_in[7];
                    end
                    SDC_SADDR + 0: sd_sector[7:0] <= data_in;
                    SDC_SADDR + 1: sd_sector[15:8] <= data_in;
                    SDC_SADDR + 2: sd_sector[23:16] <= data_in;
                    SDC_SADDR + 3: sd_sector[31:24] <= data_in;
                    default: begin end
                endcase
            end

            if (register_selected && !rd_n) begin
                case (addr)
                    SDC_ENABLE:       register_data <= {7'b0, sd_enabled};
                    SDC_STATUS:       register_data <= {busy, 5'b0, sd_timeout_error, sd_crc_error};
                    SDC_C_SIZE + 0:   register_data <= sd_c_size[7:0];
                    SDC_C_SIZE + 1:   register_data <= sd_c_size[15:8];
                    SDC_C_SIZE + 2:   register_data <= {2'b0, sd_c_size[21:16]};
                    SDC_C_SIZE_MULT:  register_data <= {5'b0, sd_c_size_mult};
                    SDC_RD_BL_LEN:    register_data <= {4'b0, sd_read_bl_len};
                    SDC_CTYPE:        register_data <= {6'b0, sd_card_type};
                    SDC_MID:          register_data <= sd_mid;
                    SDC_OID + 0:      register_data <= sd_oid[7:0];
                    SDC_OID + 1:      register_data <= sd_oid[15:8];
                    SDC_PNM + 0:      register_data <= sd_pnm[7:0];
                    SDC_PNM + 1:      register_data <= sd_pnm[15:8];
                    SDC_PNM + 2:      register_data <= sd_pnm[23:16];
                    SDC_PNM + 3:      register_data <= sd_pnm[31:24];
                    SDC_PNM + 4:      register_data <= sd_pnm[39:32];
                    SDC_PSN + 0:      register_data <= sd_psn[7:0];
                    SDC_PSN + 1:      register_data <= sd_psn[15:8];
                    SDC_PSN + 2:      register_data <= sd_psn[23:16];
                    SDC_PSN + 3:      register_data <= sd_psn[31:24];
                    default:          register_data <= 8'hff;
                endcase
            end
        end
    end

    assign data_out = ram_selected ? ram_data_out : register_data;
    assign data_out_en = (ram_selected || register_selected) && !rd_n;
    assign overlay_enabled = sd_enabled;

endmodule
