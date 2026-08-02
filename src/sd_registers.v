module sd_registers
(
    input clk,
    input sd_clk,
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
    reg [15:0] register_read_addr = 16'd0;
    reg register_read_pending = 1'b0;
    reg [15:0] register_write_addr = 16'd0;
    reg [7:0] register_write_data = 8'd0;
    reg register_write_pending = 1'b0;
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
    wire sd_busy;
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
    wire [134:0] sd_status_async = {
        sd_done,
        sd_busy,
        sd_card_status,
        sd_card_type,
        sd_c_size,
        sd_c_size_mult,
        sd_read_bl_len,
        sd_mid,
        sd_oid,
        sd_pnm,
        sd_psn,
        sd_crc_error,
        sd_timeout_error
    };
    (* syn_preserve = 1, ASYNC_REG = "TRUE" *)
    reg [134:0] sd_status_meta = 135'd0;
    reg [134:0] sd_status_sync = 135'd0;

    wire sd_done_cpu;
    wire sd_busy_cpu;
    wire [3:0] sd_card_status_cpu;
    wire [1:0] sd_card_type_cpu;
    wire [21:0] sd_c_size_cpu;
    wire [2:0] sd_c_size_mult_cpu;
    wire [3:0] sd_read_bl_len_cpu;
    wire [7:0] sd_mid_cpu;
    wire [15:0] sd_oid_cpu;
    wire [39:0] sd_pnm_cpu;
    wire [31:0] sd_psn_cpu;
    wire sd_crc_error_cpu;
    wire sd_timeout_error_cpu;

    assign {
        sd_done_cpu,
        sd_busy_cpu,
        sd_card_status_cpu,
        sd_card_type_cpu,
        sd_c_size_cpu,
        sd_c_size_mult_cpu,
        sd_read_bl_len_cpu,
        sd_mid_cpu,
        sd_oid_cpu,
        sd_pnm_cpu,
        sd_psn_cpu,
        sd_crc_error_cpu,
        sd_timeout_error_cpu
    } = sd_status_sync;

    (* syn_preserve = 1, ASYNC_REG = "TRUE" *)
    reg [1:0] sd_read_start_sync = 2'b00;
    (* syn_preserve = 1, ASYNC_REG = "TRUE" *)
    reg [1:0] sd_write_start_sync = 2'b00;
    (* syn_preserve = 1, ASYNC_REG = "TRUE" *)
    reg [1:0] sd_init_start_sync = 2'b00;
    reg sd_read_start_sync_d = 1'b0;
    reg sd_write_start_sync_d = 1'b0;
    reg sd_init_start_sync_d = 1'b0;
    reg sd_read_pending = 1'b0;
    reg sd_write_pending = 1'b0;
    reg sd_init_pending = 1'b0;
    reg [31:0] sd_sector_meta = 32'd0;
    reg [31:0] sd_sector_sync = 32'd0;
    wire sd_read_start_pulse =
        sd_read_start_sync[1] && !sd_read_start_sync_d;
    wire sd_write_start_pulse =
        sd_write_start_sync[1] && !sd_write_start_sync_d;
    wire sd_init_start_pulse =
        sd_init_start_sync[1] && !sd_init_start_sync_d;

    always_ff @(posedge sd_clk or negedge reset_n)
    begin
        if (!reset_n) begin
            sd_read_start_sync <= 2'b00;
            sd_write_start_sync <= 2'b00;
            sd_init_start_sync <= 2'b00;
            sd_read_start_sync_d <= 1'b0;
            sd_write_start_sync_d <= 1'b0;
            sd_init_start_sync_d <= 1'b0;
            sd_read_pending <= 1'b0;
            sd_write_pending <= 1'b0;
            sd_init_pending <= 1'b0;
            sd_sector_meta <= 32'd0;
            sd_sector_sync <= 32'd0;
        end else begin
            sd_read_start_sync <=
                {sd_read_start_sync[0], sd_read_start};
            sd_write_start_sync <=
                {sd_write_start_sync[0], sd_write_start};
            sd_init_start_sync <=
                {sd_init_start_sync[0], sd_init_start};
            sd_read_start_sync_d <= sd_read_start_sync[1];
            sd_write_start_sync_d <= sd_write_start_sync[1];
            sd_init_start_sync_d <= sd_init_start_sync[1];
            sd_sector_meta <= sd_sector;
            sd_sector_sync <= sd_sector_meta;

            if (sd_read_start_pulse)
                sd_read_pending <= 1'b1;
            else if (sd_read_pending && sd_card_status == 4'd13)
                sd_read_pending <= 1'b0;

            if (sd_write_start_pulse)
                sd_write_pending <= 1'b1;
            else if (sd_write_pending && sd_card_status == 4'd15)
                sd_write_pending <= 1'b0;

            if (sd_init_start_pulse)
                sd_init_pending <= 1'b1;
            else if (sd_init_pending && sd_card_status != 4'd2)
                sd_init_pending <= 1'b0;
        end
    end

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
        .clock_b(sd_clk),
        .wren_b(sd_read_start_sync[1] && sd_data_enable),
        .rden_b(sd_write_start_sync[1] && sd_data_enable),
        .address_b(sd_data_addr),
        .data_b(sd_data_out),
        .q_b(sd_data_in)
    );

    sd_reader #(
        .CLK_DIV(3'd2),
        .SIMULATE(0)
    ) sd_card_controller (
        .rstn(reset_n),
        .clk(sd_clk),
        .sdclk(sd_sclk),
        .sdcmd(sd_cmd),
        .sddat0(sd_dat0),
        .card_stat(sd_card_status),
        .card_type(sd_card_type),
        .rstart(sd_read_pending),
        .rsector(sd_sector_sync),
        .rbusy(sd_busy),
        .rdone(sd_done),
        .outen(sd_data_enable),
        .outaddr(sd_data_addr),
        .outbyte(sd_data_out),
        .wstart(sd_write_pending),
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
        .init(sd_init_pending)
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
            register_read_addr <= 16'd0;
            register_read_pending <= 1'b0;
            register_write_addr <= 16'd0;
            register_write_data <= 8'd0;
            register_write_pending <= 1'b0;
            cpu_clk_sync <= 2'b00;
            write_cycle_seen <= 1'b0;
            sd_status_meta <= 135'd0;
            sd_status_sync <= 135'd0;
        end else begin
            cpu_clk_sync <= {cpu_clk_sync[0], cpu_clk};
            sd_status_meta <= sd_status_async;
            sd_status_sync <= sd_status_meta;
            register_read_pending <= register_selected && !rd_n;
            if (register_selected && !rd_n)
                register_read_addr <= addr;

            // Pipeline CPU register writes. The external address/control
            // decode otherwise feeds every SD command and sector register in
            // one 108 MHz cycle. Capturing all writes in this subslot keeps
            // the first stage small; irrelevant addresses fall through the
            // registered case below without changing state.
            register_write_pending <= cpu_write_strobe;
            if (cpu_write_strobe) begin
                register_write_addr <= addr;
                register_write_data <= data_in;
            end

            if (!cpu_clk_high || wr_n || !memory_cycle)
                write_cycle_seen <= 1'b0;
            else if (cpu_write_strobe)
                write_cycle_seen <= 1'b1;

            if (sd_done_cpu) begin
                sd_read_start <= 1'b0;
                sd_write_start <= 1'b0;
                sd_init_start <= 1'b0;
            end

            if (register_write_pending) begin
                case (register_write_addr)
                    SDC_ENABLE:
                        sd_enabled <= register_write_data[0];
                    SDC_CMD: begin
                        if (sd_enabled) begin
                            sd_read_start <=
                                sd_read_start | register_write_data[0];
                            sd_write_start <=
                                sd_write_start | register_write_data[1];
                            sd_init_start <=
                                sd_init_start | register_write_data[7];
                        end
                    end
                    SDC_SADDR + 0:
                        if (sd_enabled)
                            sd_sector[7:0] <= register_write_data;
                    SDC_SADDR + 1:
                        if (sd_enabled)
                            sd_sector[15:8] <= register_write_data;
                    SDC_SADDR + 2:
                        if (sd_enabled)
                            sd_sector[23:16] <= register_write_data;
                    SDC_SADDR + 3:
                        if (sd_enabled)
                            sd_sector[31:24] <= register_write_data;
                    default: begin end
                endcase
            end

            // Decode the captured address one 108 MHz cycle after the read
            // begins. An MSX bus cycle spans many such clocks, so this removes
            // a long address-to-readback path without affecting CPU timing.
            if (register_read_pending) begin
                case (register_read_addr)
                    SDC_ENABLE:       register_data <= {7'b0, sd_enabled};
                    SDC_STATUS:       register_data <= {sd_busy_cpu, 5'b0, sd_timeout_error_cpu, sd_crc_error_cpu};
                    SDC_C_SIZE + 0:   register_data <= sd_c_size_cpu[7:0];
                    SDC_C_SIZE + 1:   register_data <= sd_c_size_cpu[15:8];
                    SDC_C_SIZE + 2:   register_data <= {2'b0, sd_c_size_cpu[21:16]};
                    SDC_C_SIZE_MULT:  register_data <= {5'b0, sd_c_size_mult_cpu};
                    SDC_RD_BL_LEN:    register_data <= {4'b0, sd_read_bl_len_cpu};
                    SDC_CTYPE:        register_data <= {6'b0, sd_card_type_cpu};
                    SDC_MID:          register_data <= sd_mid_cpu;
                    SDC_OID + 0:      register_data <= sd_oid_cpu[7:0];
                    SDC_OID + 1:      register_data <= sd_oid_cpu[15:8];
                    SDC_PNM + 0:      register_data <= sd_pnm_cpu[7:0];
                    SDC_PNM + 1:      register_data <= sd_pnm_cpu[15:8];
                    SDC_PNM + 2:      register_data <= sd_pnm_cpu[23:16];
                    SDC_PNM + 3:      register_data <= sd_pnm_cpu[31:24];
                    SDC_PNM + 4:      register_data <= sd_pnm_cpu[39:32];
                    SDC_PSN + 0:      register_data <= sd_psn_cpu[7:0];
                    SDC_PSN + 1:      register_data <= sd_psn_cpu[15:8];
                    SDC_PSN + 2:      register_data <= sd_psn_cpu[23:16];
                    SDC_PSN + 3:      register_data <= sd_psn_cpu[31:24];
                    default:          register_data <= 8'hff;
                endcase
            end
        end
    end

    assign data_out = ram_selected ? ram_data_out : register_data;
    assign data_out_en = (ram_selected || register_selected) && !rd_n;
    assign overlay_enabled = sd_enabled;
    assign busy = sd_busy_cpu;

endmodule
