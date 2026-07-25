// SD-card sector engine using the card's SPI mode.
//
// The host-side interface intentionally matches sd_reader.sv so the existing
// SDC_ENABLE register page and 512-byte dual-port RAM need no software change.
module sd_spi_reader (
    input  wire        rstn,
    input  wire        clk,
    output reg         sdclk,
    output wire        sdcs,
    inout  wire        sdcmd,
    inout  wire        sddat0,
    output reg  [3:0]  card_stat,
    output reg  [1:0]  card_type,
    input  wire        rstart,
    input  wire [31:0] rsector,
    output wire        rbusy,
    output reg         rdone,
    output reg         outen,
    output reg  [8:0]  outaddr,
    output reg  [7:0]  outbyte,
    input  wire        wstart,
    input  wire [7:0]  inbyte,
    output reg [21:0]  c_size,
    output reg [2:0]   c_size_mult,
    output reg [3:0]   read_bl_len,
    output reg [7:0]   mid,
    output reg [15:0]  oid,
    output reg [39:0]  pnm,
    output reg [31:0]  psn,
    output reg         crc_error,
    output reg         timeout_error,
    input  wire        init
);

    localparam [1:0] UNKNOWN = 2'd0;
    localparam [1:0] SDV1    = 2'd1;
    localparam [1:0] SDV2    = 2'd2;
    localparam [1:0] SDHC    = 2'd3;

    localparam [7:0]
        ST_IDLE          = 8'd0,
        ST_POWER         = 8'd1,
        ST_R_CMD0        = 8'd2,
        ST_R_CMD8        = 8'd3,
        ST_R_CMD55       = 8'd4,
        ST_R_ACMD41      = 8'd5,
        ST_R_CMD58       = 8'd6,
        ST_R_CMD16       = 8'd7,
        ST_R_CMD9        = 8'd8,
        ST_CSD_TOKEN     = 8'd9,
        ST_CSD_DATA      = 8'd10,
        ST_CSD_CRC1      = 8'd11,
        ST_CSD_CRC2      = 8'd12,
        ST_R_CMD10       = 8'd13,
        ST_CID_TOKEN     = 8'd14,
        ST_CID_DATA      = 8'd15,
        ST_CID_CRC1      = 8'd16,
        ST_CID_CRC2      = 8'd17,
        ST_READY         = 8'd18,
        ST_R_CMD17       = 8'd19,
        ST_READ_TOKEN    = 8'd20,
        ST_READ_DATA     = 8'd21,
        ST_READ_CRC1     = 8'd22,
        ST_READ_CRC2     = 8'd23,
        ST_R_CMD24       = 8'd24,
        ST_WRITE_GAP     = 8'd25,
        ST_WRITE_TOKEN   = 8'd26,
        ST_WRITE_PREP    = 8'd27,
        ST_WRITE_WAIT    = 8'd28,
        ST_WRITE_DATA    = 8'd29,
        ST_WRITE_CRC1    = 8'd30,
        ST_WRITE_CRC2    = 8'd31,
        ST_WRITE_RESP    = 8'd32,
        ST_WRITE_BUSY    = 8'd33,
        ST_CMD_GAP       = 8'd240,
        ST_CMD_SEND      = 8'd241,
        ST_CMD_WAIT      = 8'd242,
        ST_CMD_EXTRA     = 8'd243;

    reg [7:0] state = ST_IDLE;
    reg cs_n = 1'b1;
    reg spi_mosi = 1'b1;
    wire spi_miso = sddat0;
    assign sdcs = cs_n;
    assign sdcmd = spi_mosi;
    assign sddat0 = 1'bz;
    assign rbusy = state != ST_READY && state != ST_IDLE;

    // SPI mode 0 byte engine. spi_div is a half-period in clk cycles.
    reg [8:0] spi_div = 9'd256;       // ~211 kHz at 108 MHz during init
    reg [8:0] spi_count = 9'd0;
    reg [7:0] spi_tx = 8'hff;
    reg [7:0] spi_rx = 8'hff;
    reg [2:0] spi_bit = 3'd7;
    reg spi_start = 1'b0;
    reg spi_busy = 1'b0;
    reg spi_done = 1'b0;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            sdclk <= 1'b0;
            spi_mosi <= 1'b1;
            spi_count <= 9'd0;
            spi_rx <= 8'hff;
            spi_bit <= 3'd7;
            spi_busy <= 1'b0;
            spi_done <= 1'b0;
        end else begin
            spi_done <= 1'b0;
            if (!spi_busy) begin
                sdclk <= 1'b0;
                if (spi_start) begin
                    spi_busy <= 1'b1;
                    spi_count <= spi_div - 1'b1;
                    spi_bit <= 3'd7;
                    spi_rx <= 8'h00;
                    spi_mosi <= spi_tx[7];
                end
            end else if (spi_count != 0) begin
                spi_count <= spi_count - 1'b1;
            end else begin
                spi_count <= spi_div - 1'b1;
                if (!sdclk) begin
                    sdclk <= 1'b1;
                    spi_rx[spi_bit] <= spi_miso;
                end else begin
                    sdclk <= 1'b0;
                    if (spi_bit == 0) begin
                        spi_busy <= 1'b0;
                        spi_done <= 1'b1;
                        spi_mosi <= 1'b1;
                    end else begin
                        spi_bit <= spi_bit - 1'b1;
                        spi_mosi <= spi_tx[spi_bit - 1'b1];
                    end
                end
            end
        end
    end

    reg xfer_wait = 1'b0;
    reg [47:0] cmd_packet = 48'hff;
    reg [2:0] cmd_index = 3'd0;
    reg [7:0] cmd_return = ST_IDLE;
    reg [2:0] cmd_extra = 3'd0;
    reg [5:0] cmd_timeout = 6'd0;
    reg [7:0] cmd_r1 = 8'hff;
    reg [31:0] cmd_response = 32'hffffffff;

    reg card_v2 = 1'b0;
    reg [12:0] init_tries = 13'd0;
    reg [15:0] token_timeout = 16'd0;
    reg [8:0] byte_index = 9'd0;
    reg [4:0] info_index = 5'd0;
    reg [127:0] info_shift = 128'd0;
    reg [31:0] sector_arg = 32'd0;

    task start_transfer;
        input [7:0] value;
        begin
            spi_tx <= value;
            spi_start <= 1'b1;
            xfer_wait <= 1'b1;
        end
    endtask

    task start_command;
        input [5:0] number;
        input [31:0] argument;
        input [7:0] crc;
        input [2:0] extra_bytes;
        input [7:0] return_state;
        begin
            cmd_packet <= {2'b01, number, argument, crc};
            cmd_index <= 3'd0;
            cmd_extra <= extra_bytes;
            cmd_return <= return_state;
            cmd_timeout <= 6'd0;
            cmd_r1 <= 8'hff;
            cmd_response <= 32'd0;
            cs_n <= 1'b1;
            xfer_wait <= 1'b0;
            state <= ST_CMD_GAP;
        end
    endtask

    task finish_operation;
        begin
            cs_n <= 1'b1;
            rdone <= 1'b1;
            state <= ST_READY;
            card_stat <= 4'h1;
            xfer_wait <= 1'b0;
        end
    endtask

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= ST_IDLE;
            cs_n <= 1'b1;
            spi_start <= 1'b0;
            spi_div <= 9'd256;
            xfer_wait <= 1'b0;
            card_stat <= 4'h0;
            card_type <= UNKNOWN;
            rdone <= 1'b0;
            outen <= 1'b0;
            outaddr <= 9'd0;
            outbyte <= 8'hff;
            c_size <= 22'd0;
            c_size_mult <= 3'd0;
            read_bl_len <= 4'd0;
            mid <= 8'd0;
            oid <= 16'h2020;
            pnm <= 40'h2020202020;
            psn <= 32'd0;
            crc_error <= 1'b0;
            timeout_error <= 1'b0;
            card_v2 <= 1'b0;
            init_tries <= 13'd0;
            token_timeout <= 16'd0;
            byte_index <= 9'd0;
            info_index <= 5'd0;
            info_shift <= 128'd0;
            sector_arg <= 32'd0;
        end else begin
            spi_start <= 1'b0;
            rdone <= 1'b0;
            outen <= 1'b0;

            case (state)
                ST_IDLE: begin
                    cs_n <= 1'b1;
                    card_stat <= 4'h0;
                    if (init) begin
                        spi_div <= 9'd256;
                        card_type <= UNKNOWN;
                        card_v2 <= 1'b0;
                        init_tries <= 13'd0;
                        byte_index <= 9'd0;
                        timeout_error <= 1'b0;
                        crc_error <= 1'b0;
                        state <= ST_POWER;
                    end
                end

                // At least 80 clocks with CS and MOSI high before CMD0.
                ST_POWER: begin
                    cs_n <= 1'b1;
                    if (!xfer_wait)
                        start_transfer(8'hff);
                    else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        if (byte_index == 9'd11)
                            start_command(6'd0, 32'd0, 8'h95, 3'd0,
                                          ST_R_CMD0);
                        else
                            byte_index <= byte_index + 1'b1;
                    end
                end

                ST_R_CMD0: begin
                    cs_n <= 1'b1;
                    if (cmd_r1 == 8'h01)
                        start_command(6'd8, 32'h000001aa, 8'h87, 3'd4,
                                      ST_R_CMD8);
                    else if (init_tries == 13'h1fff) begin
                        timeout_error <= 1'b1;
                        state <= ST_IDLE;
                    end else begin
                        init_tries <= init_tries + 1'b1;
                        start_command(6'd0, 32'd0, 8'h95, 3'd0,
                                      ST_R_CMD0);
                    end
                end

                ST_R_CMD8: begin
                    cs_n <= 1'b1;
                    card_v2 <= (cmd_r1 == 8'h01 &&
                                cmd_response[11:0] == 12'h1aa);
                    start_command(6'd55, 32'd0, 8'h01, 3'd0,
                                  ST_R_CMD55);
                end

                ST_R_CMD55:
                    start_command(6'd41,
                                  card_v2 ? 32'h40000000 : 32'd0,
                                  8'h01, 3'd0, ST_R_ACMD41);

                ST_R_ACMD41: begin
                    cs_n <= 1'b1;
                    if (cmd_r1 == 8'h00)
                        start_command(6'd58, 32'd0, 8'h01, 3'd4,
                                      ST_R_CMD58);
                    else if (init_tries == 13'h1fff) begin
                        timeout_error <= 1'b1;
                        state <= ST_IDLE;
                    end else begin
                        init_tries <= init_tries + 1'b1;
                        start_command(6'd55, 32'd0, 8'h01, 3'd0,
                                      ST_R_CMD55);
                    end
                end

                ST_R_CMD58: begin
                    cs_n <= 1'b1;
                    spi_div <= 9'd8;       // ~6.75 MHz after initialization
                    if (card_v2 && cmd_response[30])
                        card_type <= SDHC;
                    else if (card_v2)
                        card_type <= SDV2;
                    else
                        card_type <= SDV1;

                    if (card_v2 && cmd_response[30])
                        start_command(6'd9, 32'd0, 8'h01, 3'd0,
                                      ST_R_CMD9);
                    else
                        start_command(6'd16, 32'd512, 8'h01, 3'd0,
                                      ST_R_CMD16);
                end

                ST_R_CMD16:
                    start_command(6'd9, 32'd0, 8'h01, 3'd0, ST_R_CMD9);

                ST_R_CMD9: begin
                    if (cmd_r1 != 8'h00) begin
                        timeout_error <= 1'b1;
                        state <= ST_IDLE;
                    end else begin
                        token_timeout <= 16'd0;
                        state <= ST_CSD_TOKEN;
                    end
                end

                ST_CSD_TOKEN, ST_CID_TOKEN, ST_READ_TOKEN: begin
                    if (!xfer_wait)
                        start_transfer(8'hff);
                    else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        if (spi_rx == 8'hfe) begin
                            info_index <= 5'd0;
                            info_shift <= 128'd0;
                            byte_index <= 9'd0;
                            if (state == ST_CSD_TOKEN)
                                state <= ST_CSD_DATA;
                            else if (state == ST_CID_TOKEN)
                                state <= ST_CID_DATA;
                            else begin
                                outaddr <= 9'd0;
                                state <= ST_READ_DATA;
                            end
                        end else if (token_timeout == 16'hffff) begin
                            timeout_error <= 1'b1;
                            if (state == ST_READ_TOKEN)
                                finish_operation();
                            else
                                state <= ST_IDLE;
                        end else
                            token_timeout <= token_timeout + 1'b1;
                    end
                end

                ST_CSD_DATA, ST_CID_DATA: begin
                    if (!xfer_wait)
                        start_transfer(8'hff);
                    else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        info_shift <= {info_shift[119:0], spi_rx};
                        if (info_index == 5'd15)
                            state <= (state == ST_CSD_DATA) ?
                                     ST_CSD_CRC1 : ST_CID_CRC1;
                        else
                            info_index <= info_index + 1'b1;
                    end
                end

                ST_CSD_CRC1, ST_CID_CRC1, ST_READ_CRC1: begin
                    if (!xfer_wait)
                        start_transfer(8'hff);
                    else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        if (state == ST_CSD_CRC1)
                            state <= ST_CSD_CRC2;
                        else if (state == ST_CID_CRC1)
                            state <= ST_CID_CRC2;
                        else
                            state <= ST_READ_CRC2;
                    end
                end

                ST_CSD_CRC2: begin
                    if (!xfer_wait)
                        start_transfer(8'hff);
                    else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        cs_n <= 1'b1;
                        if (info_shift[127:126] == 2'b01) begin
                            c_size <= {info_shift[69:64],
                                       info_shift[63:56],
                                       info_shift[55:48]};
                            c_size_mult <= 3'd2;
                            read_bl_len <= 4'hf;
                        end else begin
                            c_size <= {10'd0, info_shift[73:62]};
                            c_size_mult <= info_shift[49:47];
                            read_bl_len <= info_shift[83:80];
                        end
                        start_command(6'd10, 32'd0, 8'h01, 3'd0,
                                      ST_R_CMD10);
                    end
                end

                ST_R_CMD10: begin
                    if (cmd_r1 != 8'h00) begin
                        timeout_error <= 1'b1;
                        state <= ST_IDLE;
                    end else begin
                        token_timeout <= 16'd0;
                        state <= ST_CID_TOKEN;
                    end
                end

                ST_CID_CRC2: begin
                    if (!xfer_wait)
                        start_transfer(8'hff);
                    else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        cs_n <= 1'b1;
                        mid <= info_shift[127:120];
                        oid <= info_shift[119:104];
                        pnm <= info_shift[103:64];
                        psn <= info_shift[55:24];
                        card_stat <= 4'h1;
                        state <= ST_READY;
                    end
                end

                ST_READY: begin
                    cs_n <= 1'b1;
                    card_stat <= 4'h1;
                    if (rstart) begin
                        sector_arg <= (card_type == SDHC) ?
                                      rsector : {rsector[22:0], 9'd0};
                        start_command(6'd17,
                            (card_type == SDHC) ?
                                rsector : {rsector[22:0], 9'd0},
                            8'h01, 3'd0, ST_R_CMD17);
                    end else if (wstart) begin
                        sector_arg <= (card_type == SDHC) ?
                                      rsector : {rsector[22:0], 9'd0};
                        start_command(6'd24,
                            (card_type == SDHC) ?
                                rsector : {rsector[22:0], 9'd0},
                            8'h01, 3'd0, ST_R_CMD24);
                    end
                end

                ST_R_CMD17: begin
                    if (cmd_r1 == 8'h00) begin
                        token_timeout <= 16'd0;
                        state <= ST_READ_TOKEN;
                    end else begin
                        timeout_error <= 1'b1;
                        finish_operation();
                    end
                end

                ST_READ_DATA: begin
                    if (!xfer_wait)
                        start_transfer(8'hff);
                    else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        outbyte <= spi_rx;
                        outaddr <= byte_index;
                        outen <= 1'b1;
                        if (byte_index == 9'd511)
                            state <= ST_READ_CRC1;
                        else
                            byte_index <= byte_index + 1'b1;
                    end
                end

                ST_READ_CRC2: begin
                    if (!xfer_wait)
                        start_transfer(8'hff);
                    else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        finish_operation();
                    end
                end

                ST_R_CMD24: begin
                    if (cmd_r1 == 8'h00)
                        state <= ST_WRITE_GAP;
                    else begin
                        timeout_error <= 1'b1;
                        finish_operation();
                    end
                end

                ST_WRITE_GAP, ST_WRITE_TOKEN: begin
                    if (!xfer_wait)
                        start_transfer(state == ST_WRITE_GAP ?
                                       8'hff : 8'hfe);
                    else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        if (state == ST_WRITE_GAP)
                            state <= ST_WRITE_TOKEN;
                        else begin
                            byte_index <= 9'd0;
                            state <= ST_WRITE_PREP;
                        end
                    end
                end

                ST_WRITE_PREP: begin
                    outaddr <= byte_index;
                    outen <= 1'b1;
                    state <= ST_WRITE_WAIT;
                end

                ST_WRITE_WAIT:
                    state <= ST_WRITE_DATA;

                ST_WRITE_DATA: begin
                    if (!xfer_wait)
                        start_transfer(inbyte);
                    else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        if (byte_index == 9'd511)
                            state <= ST_WRITE_CRC1;
                        else begin
                            byte_index <= byte_index + 1'b1;
                            state <= ST_WRITE_PREP;
                        end
                    end
                end

                ST_WRITE_CRC1, ST_WRITE_CRC2: begin
                    if (!xfer_wait)
                        start_transfer(8'hff);
                    else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        state <= (state == ST_WRITE_CRC1) ?
                                 ST_WRITE_CRC2 : ST_WRITE_RESP;
                    end
                end

                ST_WRITE_RESP: begin
                    if (!xfer_wait)
                        start_transfer(8'hff);
                    else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        if (spi_rx != 8'hff) begin
                            if ((spi_rx & 8'h1f) != 8'h05)
                                crc_error <= 1'b1;
                            token_timeout <= 16'd0;
                            state <= ST_WRITE_BUSY;
                        end
                    end
                end

                ST_WRITE_BUSY: begin
                    if (!xfer_wait)
                        start_transfer(8'hff);
                    else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        if (spi_rx == 8'hff)
                            finish_operation();
                        else if (token_timeout == 16'hffff) begin
                            timeout_error <= 1'b1;
                            finish_operation();
                        end else
                            token_timeout <= token_timeout + 1'b1;
                    end
                end

                // Generic SPI command sender and R1/R3/R7 receiver.
                ST_CMD_GAP: begin
                    cs_n <= 1'b1;
                    if (!xfer_wait)
                        start_transfer(8'hff);
                    else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        cs_n <= 1'b0;
                        state <= ST_CMD_SEND;
                    end
                end

                ST_CMD_SEND: begin
                    if (!xfer_wait) begin
                        case (cmd_index)
                            3'd0: start_transfer(cmd_packet[47:40]);
                            3'd1: start_transfer(cmd_packet[39:32]);
                            3'd2: start_transfer(cmd_packet[31:24]);
                            3'd3: start_transfer(cmd_packet[23:16]);
                            3'd4: start_transfer(cmd_packet[15:8]);
                            default: start_transfer(cmd_packet[7:0]);
                        endcase
                    end else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        if (cmd_index == 3'd5)
                            state <= ST_CMD_WAIT;
                        else
                            cmd_index <= cmd_index + 1'b1;
                    end
                end

                ST_CMD_WAIT: begin
                    if (!xfer_wait)
                        start_transfer(8'hff);
                    else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        if (!spi_rx[7]) begin
                            cmd_r1 <= spi_rx;
                            if (cmd_extra == 0)
                                state <= cmd_return;
                            else begin
                                cmd_index <= 3'd0;
                                state <= ST_CMD_EXTRA;
                            end
                        end else if (cmd_timeout == 6'd63) begin
                            cmd_r1 <= 8'hff;
                            timeout_error <= 1'b1;
                            state <= cmd_return;
                        end else
                            cmd_timeout <= cmd_timeout + 1'b1;
                    end
                end

                ST_CMD_EXTRA: begin
                    if (!xfer_wait)
                        start_transfer(8'hff);
                    else if (spi_done) begin
                        xfer_wait <= 1'b0;
                        cmd_response <= {cmd_response[23:0], spi_rx};
                        if (cmd_index + 1'b1 == cmd_extra)
                            state <= cmd_return;
                        else
                            cmd_index <= cmd_index + 1'b1;
                    end
                end

                default:
                    state <= ST_IDLE;
            endcase
        end
    end
endmodule
