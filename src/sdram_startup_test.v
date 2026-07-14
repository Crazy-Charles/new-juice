module sdram_startup_test
#(
    parameter integer CLK_FREQ_HZ = 108_000_000
)
(
    input clk,
    input reset_n,
    input sdrc_init_done,
    input sdrc_cmd_ack,
    input [31:0] sdrc_data_in,

    output sdrc_cmd_en,
    output [2:0] sdrc_cmd,
    output sdrc_precharge_ctrl,
    output sdram_power_down,
    output sdram_selfrefresh,
    output [20:0] sdrc_addr,
    output [3:0] sdrc_dqm,
    output [31:0] sdrc_data,
    output [7:0] sdrc_data_len,

    output test_passed,
    output test_failed,
    output wait_n,
    output led
);

    localparam [2:0] SDRAM_CMD_READ = 3'b101;
    localparam [2:0] SDRAM_CMD_WRITE = 3'b100;
    localparam [31:0] LFSR_SEED = 32'h1a2b3c4d;
    localparam [15:0] LAST_TEST_ADDR = 16'hfffe;

    localparam [2:0] STATE_WAIT_INIT = 3'd0;
    localparam [2:0] STATE_WRITE_CMD = 3'd1;
    localparam [2:0] STATE_WRITE_ACK = 3'd2;
    localparam [2:0] STATE_READ_CMD = 3'd3;
    localparam [2:0] STATE_READ_ACK = 3'd4;
    localparam [2:0] STATE_READ_CHECK = 3'd5;
    localparam [2:0] STATE_PASS = 3'd6;
    localparam [2:0] STATE_FAIL = 3'd7;

    localparam [2:0] LED_START_OFF = 3'd0;
    localparam [2:0] LED_ONE_ON = 3'd1;
    localparam [2:0] LED_ONE_OFF = 3'd2;
    localparam [2:0] LED_ZERO_ON = 3'd3;
    localparam [2:0] LED_BIT_GAP = 3'd4;
    localparam [2:0] LED_REPEAT_OFF = 3'd5;

    // Each bit occupies five seconds. Its visible pattern lasts four
    // seconds, followed by one second dark to separate adjacent bits.
    localparam integer FAST_HALF_CYCLES = CLK_FREQ_HZ / 2;
    localparam integer LONG_ON_CYCLES = CLK_FREQ_HZ * 4;
    localparam integer START_OFF_CYCLES = CLK_FREQ_HZ * 10;
    localparam integer BIT_GAP_CYCLES = CLK_FREQ_HZ;
    localparam integer REPEAT_OFF_CYCLES = CLK_FREQ_HZ * 5;

    reg [2:0] state = STATE_WAIT_INIT;
    reg [15:0] test_addr = 16'd0;
    reg [15:0] error_addr = 16'd0;
    reg [31:0] lfsr = LFSR_SEED;
    reg sdrc_cmd_en_reg = 1'b0;
    reg [2:0] sdrc_cmd_reg = SDRAM_CMD_WRITE;
    reg [20:0] sdrc_addr_reg = 21'd0;
    reg [3:0] sdrc_dqm_reg = 4'b1111;
    reg [31:0] sdrc_data_reg = 32'd0;
    reg test_passed_reg = 1'b0;
    reg test_failed_reg = 1'b0;

    reg [2:0] led_state = LED_START_OFF;
    reg [30:0] led_count = 31'd0;
    reg [3:0] led_bit_index = 4'd15;
    reg [1:0] led_one_count = 2'd0;

    wire [7:0] expected_byte = lfsr[7:0];
    wire [7:0] read_byte =
        (test_addr[1:0] == 2'd0) ? sdrc_data_in[7:0] :
        (test_addr[1:0] == 2'd1) ? sdrc_data_in[15:8] :
        (test_addr[1:0] == 2'd2) ? sdrc_data_in[23:16] :
                                         sdrc_data_in[31:24];

    function automatic [31:0] next_lfsr;
        input [31:0] value;
        begin
            next_lfsr = {value[30:0], value[31] ^ value[21] ^ value[1] ^ value[0]};
        end
    endfunction

    function automatic [3:0] byte_dqm;
        input [1:0] lane;
        begin
            case (lane)
                2'd0: byte_dqm = 4'b1110;
                2'd1: byte_dqm = 4'b1101;
                2'd2: byte_dqm = 4'b1011;
                default: byte_dqm = 4'b0111;
            endcase
        end
    endfunction

    always_ff @(posedge clk or negedge reset_n)
    begin
        if (!reset_n) begin
            state <= STATE_WAIT_INIT;
            test_addr <= 16'd0;
            error_addr <= 16'd0;
            lfsr <= LFSR_SEED;
            sdrc_cmd_en_reg <= 1'b0;
            sdrc_cmd_reg <= SDRAM_CMD_WRITE;
            sdrc_addr_reg <= 21'd0;
            sdrc_dqm_reg <= 4'b1111;
            sdrc_data_reg <= 32'd0;
            test_passed_reg <= 1'b0;
            test_failed_reg <= 1'b0;
        end else begin
            sdrc_cmd_en_reg <= 1'b0;

            case (state)
                STATE_WAIT_INIT: begin
                    if (sdrc_init_done) begin
                        test_addr <= 16'd0;
                        lfsr <= LFSR_SEED;
                        state <= STATE_WRITE_CMD;
                    end
                end

                STATE_WRITE_CMD: begin
                    sdrc_cmd_reg <= SDRAM_CMD_WRITE;
                    sdrc_addr_reg <= {7'd0, test_addr[15:2]};
                    sdrc_dqm_reg <= byte_dqm(test_addr[1:0]);
                    sdrc_data_reg <= {4{expected_byte}};
                    sdrc_cmd_en_reg <= 1'b1;
                    state <= STATE_WRITE_ACK;
                end

                STATE_WRITE_ACK: begin
                    if (sdrc_cmd_ack) begin
                        if (test_addr == LAST_TEST_ADDR) begin
                            // All 65,535 writes are complete. Restart the
                            // deterministic sequence for the readback pass.
                            test_addr <= 16'd0;
                            lfsr <= LFSR_SEED;
                            state <= STATE_READ_CMD;
                        end else begin
                            test_addr <= test_addr + 1'b1;
                            lfsr <= next_lfsr(lfsr);
                            state <= STATE_WRITE_CMD;
                        end
                    end
                end

                STATE_READ_CMD: begin
                    sdrc_cmd_reg <= SDRAM_CMD_READ;
                    sdrc_addr_reg <= {7'd0, test_addr[15:2]};
                    sdrc_dqm_reg <= byte_dqm(test_addr[1:0]);
                    sdrc_data_reg <= 32'd0;
                    sdrc_cmd_en_reg <= 1'b1;
                    state <= STATE_READ_ACK;
                end

                STATE_READ_ACK: begin
                    if (sdrc_cmd_ack) begin
                        state <= STATE_READ_CHECK;
                    end
                end

                STATE_READ_CHECK: begin
                    if (read_byte != expected_byte) begin
                        error_addr <= test_addr;
                        test_failed_reg <= 1'b1;
                        state <= STATE_FAIL;
                    end else if (test_addr == LAST_TEST_ADDR) begin
                        test_passed_reg <= 1'b1;
                        state <= STATE_PASS;
                    end else begin
                        test_addr <= test_addr + 1'b1;
                        lfsr <= next_lfsr(lfsr);
                        state <= STATE_READ_CMD;
                    end
                end

                STATE_PASS: begin
                    state <= STATE_PASS;
                end

                default: begin
                    state <= STATE_FAIL;
                end
            endcase
        end
    end

    // On failure, repeatedly transmit error_addr[15:0], MSB first:
    // ten-second dark preamble, four flashes for one, one long flash
    // for zero, and a one-second dark separator between bits.
    always_ff @(posedge clk or negedge reset_n)
    begin
        if (!reset_n || !test_failed_reg) begin
            led_state <= LED_START_OFF;
            led_count <= 31'd0;
            led_bit_index <= 4'd15;
            led_one_count <= 2'd0;
        end else begin
            case (led_state)
                LED_START_OFF: begin
                    if (led_count == START_OFF_CYCLES - 1) begin
                        led_count <= 31'd0;
                        led_bit_index <= 4'd15;
                        led_one_count <= 2'd0;
                        led_state <= error_addr[15] ? LED_ONE_ON : LED_ZERO_ON;
                    end else begin
                        led_count <= led_count + 1'b1;
                    end
                end

                LED_ONE_ON: begin
                    if (led_count == FAST_HALF_CYCLES - 1) begin
                        led_count <= 31'd0;
                        led_state <= LED_ONE_OFF;
                    end else begin
                        led_count <= led_count + 1'b1;
                    end
                end

                LED_ONE_OFF: begin
                    if (led_count == FAST_HALF_CYCLES - 1) begin
                        led_count <= 31'd0;
                        if (led_one_count == 2'd3) begin
                            led_one_count <= 2'd0;
                            led_state <= LED_BIT_GAP;
                        end else begin
                            led_one_count <= led_one_count + 1'b1;
                            led_state <= LED_ONE_ON;
                        end
                    end else begin
                        led_count <= led_count + 1'b1;
                    end
                end

                LED_ZERO_ON: begin
                    if (led_count == LONG_ON_CYCLES - 1) begin
                        led_count <= 31'd0;
                        led_state <= LED_BIT_GAP;
                    end else begin
                        led_count <= led_count + 1'b1;
                    end
                end

                LED_BIT_GAP: begin
                    if (led_count == BIT_GAP_CYCLES - 1) begin
                        led_count <= 31'd0;
                        if (led_bit_index == 4'd0) begin
                            led_state <= LED_REPEAT_OFF;
                        end else begin
                            led_bit_index <= led_bit_index - 1'b1;
                            led_state <= error_addr[led_bit_index - 1'b1] ? LED_ONE_ON : LED_ZERO_ON;
                        end
                    end else begin
                        led_count <= led_count + 1'b1;
                    end
                end

                default: begin
                    if (led_count == REPEAT_OFF_CYCLES - 1) begin
                        led_count <= 31'd0;
                        led_bit_index <= 4'd15;
                        led_one_count <= 2'd0;
                        led_state <= error_addr[15] ? LED_ONE_ON : LED_ZERO_ON;
                    end else begin
                        led_count <= led_count + 1'b1;
                    end
                end
            endcase
        end
    end

    assign sdrc_cmd_en = sdrc_cmd_en_reg;
    assign sdrc_cmd = sdrc_cmd_reg;
    assign sdrc_precharge_ctrl = 1'b1;
    assign sdram_power_down = 1'b0;
    assign sdram_selfrefresh = 1'b0;
    assign sdrc_addr = sdrc_addr_reg;
    assign sdrc_dqm = sdrc_dqm_reg;
    assign sdrc_data = sdrc_data_reg;
    assign sdrc_data_len = 8'd0;

    assign test_passed = test_passed_reg;
    assign test_failed = test_failed_reg;
    assign wait_n = test_passed_reg && !test_failed_reg;
    assign led = test_failed_reg &&
                 ((led_state == LED_ONE_ON) || (led_state == LED_ZERO_ON));

endmodule
