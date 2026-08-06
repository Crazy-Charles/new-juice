module debug_trace_terminal
(
    input cpu_clk,
    input pixel_clk,
    input reset_n,
    input display_enabled,
    input debug_wait_n,
    input [15:0] bus_address,
    input [7:0] bus_data,
    input m1_n,
    input merq_n,
    input rd_n,
    input wr_n,
    input rfsh_n,
    input [7:0] subslot,
    input [7:0] mapper_page0,
    input [7:0] mapper_page1,
    input [7:0] mapper_page2,
    input [7:0] mapper_page3,
    input [7:0] megaram_bank0,
    input [7:0] megaram_bank1,
    input [7:0] megaram_bank2,
    input [7:0] megaram_bank3,
    input [7:0] megaram_type,
    input [9:0] x,
    input [9:0] y,
    output pixel
);

    localparam [5:0] CH_SPACE = 6'd0;
    localparam [5:0] CH_0 = 6'd1;
    localparam [5:0] CH_A = 6'd11;
    localparam [5:0] CH_COLON = 6'd17;
    localparam [5:0] CH_LESS = 6'd18;
    localparam [5:0] CH_GREATER = 6'd19;
    localparam [5:0] CH_S = 6'd20;
    localparam [5:0] CH_M = 6'd21;
    localparam [5:0] CH_R = 6'd22;
    localparam [5:0] CH_T = 6'd23;

    function automatic [5:0] hex_character(input [3:0] value);
        begin
            hex_character = value < 4'd10 ? CH_0 + value : CH_A + value - 4'd10;
        end
    endfunction

    reg current_valid = 1'b0;
    reg [15:0] current_address = 16'd0;
    reg [15:0] next_code_address = 16'd0;
    reg [2:0] current_instruction_count = 3'd0;
    reg [7:0] current_instruction0 = 8'd0;
    reg [7:0] current_instruction1 = 8'd0;
    reg [7:0] current_instruction2 = 8'd0;
    reg [7:0] current_instruction3 = 8'd0;
    reg [2:0] current_data_count = 3'd0;
    reg [7:0] current_data0 = 8'd0;
    reg [7:0] current_data1 = 8'd0;
    reg [7:0] current_data2 = 8'd0;
    reg [7:0] current_data3 = 8'd0;
    reg [1:0] current_direction = 2'd0;
    reg [1:0] prefix_state = 2'd0;

    localparam [1:0] PREFIX_NONE = 2'd0;
    localparam [1:0] PREFIX_SIMPLE = 2'd1;
    localparam [1:0] PREFIX_INDEX = 2'd2;
    localparam [1:0] PREFIX_INDEX_CB = 2'd3;

    reg access_seen = 1'b0;
    reg [15:0] access_address = 16'd0;
    reg [7:0] access_data = 8'd0;
    reg access_is_m1 = 1'b0;
    reg access_is_write = 1'b0;

    reg writer_busy = 1'b0;
    reg [4:0] writer_column = 5'd0;
    reg [4:0] writer_slot = 5'd0;
    reg [15:0] writer_address = 16'd0;
    reg [2:0] writer_instruction_count = 3'd0;
    reg [7:0] writer_instruction0 = 8'd0;
    reg [7:0] writer_instruction1 = 8'd0;
    reg [7:0] writer_instruction2 = 8'd0;
    reg [7:0] writer_instruction3 = 8'd0;
    reg [2:0] writer_data_count = 3'd0;
    reg [7:0] writer_data0 = 8'd0;
    reg [7:0] writer_data1 = 8'd0;
    reg [7:0] writer_data2 = 8'd0;
    reg [7:0] writer_data3 = 8'd0;
    reg [1:0] writer_direction = 2'd0;
    reg [4:0] next_history_slot = 5'd0;
    reg [4:0] newest_history_slot = 5'd0;
    reg [4:0] history_count = 5'd0;

    wire memory_access = !merq_n && rfsh_n && (!rd_n || !wr_n);
    wire new_opcode_access = memory_access && !access_seen && !rd_n && !m1_n;
    // Prefix state is updated when each completed M1 byte is captured. Thus,
    // at the beginning of the following M1 cycle it tells us whether that
    // fetch continues ED/CB/DD/FD decoding or starts a new instruction.
    wire new_instruction = new_opcode_access &&
                           (!current_valid || prefix_state == PREFIX_NONE);

    reg [5:0] writer_character;
    always @* begin
        writer_character = CH_SPACE;
        case (writer_column)
            5'd0: writer_character = hex_character(writer_address[15:12]);
            5'd1: writer_character = hex_character(writer_address[11:8]);
            5'd2: writer_character = hex_character(writer_address[7:4]);
            5'd3: writer_character = hex_character(writer_address[3:0]);
            5'd4: writer_character = CH_COLON;
            5'd6: if (writer_instruction_count > 0)
                      writer_character = hex_character(writer_instruction0[7:4]);
            5'd7: if (writer_instruction_count > 0)
                      writer_character = hex_character(writer_instruction0[3:0]);
            5'd9: if (writer_instruction_count > 1)
                      writer_character = hex_character(writer_instruction1[7:4]);
            5'd10: if (writer_instruction_count > 1)
                       writer_character = hex_character(writer_instruction1[3:0]);
            5'd12: if (writer_instruction_count > 2)
                       writer_character = hex_character(writer_instruction2[7:4]);
            5'd13: if (writer_instruction_count > 2)
                       writer_character = hex_character(writer_instruction2[3:0]);
            5'd15: if (writer_instruction_count > 3)
                       writer_character = hex_character(writer_instruction3[7:4]);
            5'd16: if (writer_instruction_count > 3)
                       writer_character = hex_character(writer_instruction3[3:0]);
            5'd18: if (writer_direction == 2'd1) writer_character = CH_LESS;
                   else if (writer_direction == 2'd2) writer_character = CH_GREATER;
            5'd19: if (writer_direction == 2'd1) writer_character = CH_LESS;
                   else if (writer_direction == 2'd2) writer_character = CH_GREATER;
            5'd21: if (writer_data_count > 0)
                       writer_character = hex_character(writer_data0[7:4]);
            5'd22: if (writer_data_count > 0)
                       writer_character = hex_character(writer_data0[3:0]);
            5'd24: if (writer_data_count > 1)
                       writer_character = hex_character(writer_data1[7:4]);
            5'd25: if (writer_data_count > 1)
                       writer_character = hex_character(writer_data1[3:0]);
            5'd27: if (writer_data_count > 2)
                       writer_character = hex_character(writer_data2[7:4]);
            5'd28: if (writer_data_count > 2)
                       writer_character = hex_character(writer_data2[3:0]);
            5'd30: if (writer_data_count > 3)
                       writer_character = hex_character(writer_data3[7:4]);
            5'd31: if (writer_data_count > 3)
                       writer_character = hex_character(writer_data3[3:0]);
            default: writer_character = CH_SPACE;
        endcase
    end

    wire [9:0] history_write_address = {writer_slot, writer_column};
    reg [9:0] history_read_address;
    wire [5:0] history_character;

    dpram #(.widthad_a(10), .width_a(6)) trace_character_ram (
        .clock_a(cpu_clk),
        .address_a(history_write_address),
        .wren_a(writer_busy),
        .rden_a(1'b0),
        .data_a(writer_character),
        .q_a(),
        .clock_b(pixel_clk),
        .address_b(history_read_address),
        .wren_b(1'b0),
        .rden_b(1'b1),
        .data_b(6'd0),
        .q_b(history_character)
    );

    task automatic append_instruction_byte(input [7:0] value);
        begin
            case (current_instruction_count)
                3'd0: current_instruction0 <= value;
                3'd1: current_instruction1 <= value;
                3'd2: current_instruction2 <= value;
                3'd3: current_instruction3 <= value;
                default: current_instruction3 <= current_instruction3;
            endcase
            if (current_instruction_count < 3'd4)
                current_instruction_count <= current_instruction_count + 1'b1;
        end
    endtask

    task automatic append_data_byte(input [7:0] value,
                                    input [1:0] direction);
        begin
            case (current_data_count)
                3'd0: current_data0 <= value;
                3'd1: current_data1 <= value;
                3'd2: current_data2 <= value;
                3'd3: current_data3 <= value;
                default: current_data3 <= current_data3;
            endcase
            if (current_data_count < 3'd4)
                current_data_count <= current_data_count + 1'b1;
            current_direction <= direction;
        end
    endtask

    always_ff @(posedge cpu_clk or negedge reset_n) begin
        if (!reset_n) begin
            current_valid <= 1'b0;
            prefix_state <= PREFIX_NONE;
            access_seen <= 1'b0;
            writer_busy <= 1'b0;
            writer_column <= 5'd0;
            next_history_slot <= 5'd0;
            newest_history_slot <= 5'd0;
            history_count <= 5'd0;
        end else begin
            if (writer_busy) begin
                if (writer_column == 5'd31) begin
                    writer_busy <= 1'b0;
                    writer_column <= 5'd0;
                    newest_history_slot <= writer_slot;
                    next_history_slot <= writer_slot == 5'd20 ?
                                         5'd0 : writer_slot + 1'b1;
                    if (history_count < 5'd21)
                        history_count <= history_count + 1'b1;
                end else begin
                    writer_column <= writer_column + 1'b1;
                end
            end

            if (memory_access) begin
                access_address <= bus_address;
                access_data <= bus_data;
                if (!access_seen) begin
                    access_is_m1 <= !rd_n && !m1_n;
                    access_is_write <= !wr_n;
                end
                access_seen <= 1'b1;

                if (new_instruction) begin
                    if (current_valid && !writer_busy) begin
                        writer_busy <= 1'b1;
                        writer_column <= 5'd0;
                        writer_slot <= next_history_slot;
                        writer_address <= current_address;
                        writer_instruction_count <= current_instruction_count;
                        writer_instruction0 <= current_instruction0;
                        writer_instruction1 <= current_instruction1;
                        writer_instruction2 <= current_instruction2;
                        writer_instruction3 <= current_instruction3;
                        writer_data_count <= current_data_count;
                        writer_data0 <= current_data0;
                        writer_data1 <= current_data1;
                        writer_data2 <= current_data2;
                        writer_data3 <= current_data3;
                        writer_direction <= current_direction;
                    end

                    current_valid <= 1'b1;
                    current_address <= bus_address;
                    next_code_address <= bus_address + 1'b1;
                    current_instruction_count <= 3'd0;
                    current_data_count <= 3'd0;
                    current_direction <= 2'd0;
                end
            end else if (access_seen) begin
                access_seen <= 1'b0;
                if (current_valid) begin
                    if (access_is_write) begin
                        append_data_byte(access_data, 2'd2);
                    end else if (access_is_m1) begin
                        append_instruction_byte(access_data);
                        next_code_address <= access_address + 1'b1;
                        case (prefix_state)
                            PREFIX_NONE: begin
                                if (access_data == 8'hcb ||
                                    access_data == 8'hed)
                                    prefix_state <= PREFIX_SIMPLE;
                                else if (access_data == 8'hdd ||
                                         access_data == 8'hfd)
                                    prefix_state <= PREFIX_INDEX;
                                else
                                    prefix_state <= PREFIX_NONE;
                            end
                            PREFIX_INDEX: begin
                                if (access_data == 8'hdd ||
                                    access_data == 8'hfd)
                                    prefix_state <= PREFIX_INDEX;
                                else if (access_data == 8'hcb)
                                    prefix_state <= PREFIX_INDEX_CB;
                                else if (access_data == 8'hed)
                                    prefix_state <= PREFIX_SIMPLE;
                                else
                                    prefix_state <= PREFIX_NONE;
                            end
                            default: prefix_state <= PREFIX_NONE;
                        endcase
                    end else if (access_address == next_code_address) begin
                        append_instruction_byte(access_data);
                        next_code_address <= access_address + 1'b1;
                    end else begin
                        append_data_byte(access_data, 2'd1);
                    end
                end
            end
        end
    end

    localparam [9:0] X_START = 10'd104;
    localparam [9:0] Y_START = 10'd48;
    wire terminal_window = x >= X_START && x < X_START + 10'd512 &&
                           y >= Y_START && y < Y_START + 10'd384;
    wire [9:0] local_x = x - X_START;
    wire [9:0] local_y = y - Y_START;
    wire [4:0] requested_row = local_y[8:4];
    wire [4:0] requested_column = local_x[8:4];
    wire [5:0] requested_status_column = local_x[8:3];
    wire requested_history = terminal_window && requested_row <= 5'd20 &&
        history_count != 0 && requested_row >= 5'd21 - history_count;
    wire [4:0] requested_age = 5'd20 - requested_row;
    wire [5:0] wrapped_history_slot =
        newest_history_slot >= requested_age ?
        newest_history_slot - requested_age :
        newest_history_slot + 6'd21 - requested_age;

    reg [5:0] dynamic_character;
    always @* begin
        dynamic_character = CH_SPACE;
        if (requested_row == 5'd21 && current_valid) begin
            case (requested_column)
                5'd0: dynamic_character = hex_character(current_address[15:12]);
                5'd1: dynamic_character = hex_character(current_address[11:8]);
                5'd2: dynamic_character = hex_character(current_address[7:4]);
                5'd3: dynamic_character = hex_character(current_address[3:0]);
                5'd4: dynamic_character = CH_COLON;
                5'd6: if (debug_wait_n && current_instruction_count > 0)
                          dynamic_character = hex_character(current_instruction0[7:4]);
                5'd7: if (debug_wait_n && current_instruction_count > 0)
                          dynamic_character = hex_character(current_instruction0[3:0]);
                5'd9: if (debug_wait_n && current_instruction_count > 1)
                          dynamic_character = hex_character(current_instruction1[7:4]);
                5'd10: if (debug_wait_n && current_instruction_count > 1)
                           dynamic_character = hex_character(current_instruction1[3:0]);
                5'd12: if (debug_wait_n && current_instruction_count > 2)
                           dynamic_character = hex_character(current_instruction2[7:4]);
                5'd13: if (debug_wait_n && current_instruction_count > 2)
                           dynamic_character = hex_character(current_instruction2[3:0]);
                5'd15: if (debug_wait_n && current_instruction_count > 3)
                           dynamic_character = hex_character(current_instruction3[7:4]);
                5'd16: if (debug_wait_n && current_instruction_count > 3)
                           dynamic_character = hex_character(current_instruction3[3:0]);
                default: dynamic_character = CH_SPACE;
            endcase
        end else if (requested_row == 5'd23) begin
            case (requested_status_column)
                6'd0, 6'd1: dynamic_character = CH_S;
                6'd2: dynamic_character = CH_COLON;
                6'd3: dynamic_character = hex_character(subslot[7:4]);
                6'd4: dynamic_character = hex_character(subslot[3:0]);
                6'd6, 6'd7: dynamic_character = CH_M;
                6'd8: dynamic_character = CH_COLON;
                6'd9: dynamic_character = hex_character(mapper_page0[7:4]);
                6'd10: dynamic_character = hex_character(mapper_page0[3:0]);
                6'd11: dynamic_character = CH_COLON;
                6'd12: dynamic_character = hex_character(mapper_page1[7:4]);
                6'd13: dynamic_character = hex_character(mapper_page1[3:0]);
                6'd14: dynamic_character = CH_COLON;
                6'd15: dynamic_character = hex_character(mapper_page2[7:4]);
                6'd16: dynamic_character = hex_character(mapper_page2[3:0]);
                6'd17: dynamic_character = CH_COLON;
                6'd18: dynamic_character = hex_character(mapper_page3[7:4]);
                6'd19: dynamic_character = hex_character(mapper_page3[3:0]);
                6'd21: dynamic_character = CH_M;
                6'd22: dynamic_character = CH_R;
                6'd23: dynamic_character = CH_COLON;
                6'd24: dynamic_character = hex_character(megaram_bank0[7:4]);
                6'd25: dynamic_character = hex_character(megaram_bank0[3:0]);
                6'd26: dynamic_character = CH_COLON;
                6'd27: dynamic_character = hex_character(megaram_bank1[7:4]);
                6'd28: dynamic_character = hex_character(megaram_bank1[3:0]);
                6'd29: dynamic_character = CH_COLON;
                6'd30: dynamic_character = hex_character(megaram_bank2[7:4]);
                6'd31: dynamic_character = hex_character(megaram_bank2[3:0]);
                6'd32: dynamic_character = CH_COLON;
                6'd33: dynamic_character = hex_character(megaram_bank3[7:4]);
                6'd34: dynamic_character = hex_character(megaram_bank3[3:0]);
                6'd36: dynamic_character = CH_M;
                6'd37: dynamic_character = CH_T;
                6'd38: dynamic_character = CH_COLON;
                6'd39: dynamic_character = hex_character(megaram_type[7:4]);
                6'd40: dynamic_character = hex_character(megaram_type[3:0]);
                default: dynamic_character = CH_SPACE;
            endcase
        end
    end

    always @* begin
        history_read_address = {wrapped_history_slot[4:0], requested_column};
    end

    reg pixel_active = 1'b0;
    reg pixel_uses_history = 1'b0;
    reg [5:0] pixel_dynamic_character = CH_SPACE;
    reg [2:0] glyph_x = 3'd0;
    reg [2:0] glyph_y = 3'd0;
    always_ff @(posedge pixel_clk or negedge reset_n) begin
        if (!reset_n) begin
            pixel_active <= 1'b0;
            pixel_uses_history <= 1'b0;
            pixel_dynamic_character <= CH_SPACE;
            glyph_x <= 3'd0;
            glyph_y <= 3'd0;
        end else begin
            pixel_active <= display_enabled && terminal_window;
            pixel_uses_history <= requested_history;
            pixel_dynamic_character <= dynamic_character;
            glyph_x <= requested_row == 5'd23 ? local_x[2:0] : local_x[3:1];
            glyph_y <= local_y[3:1];
        end
    end

    wire [5:0] display_character = pixel_uses_history ?
                                 history_character : pixel_dynamic_character;
    reg [4:0] glyph_row;
    always @* begin
        glyph_row = 5'b00000;
        case (display_character)
            6'd1:  case (glyph_y) 0:glyph_row=5'b01110; 1:glyph_row=5'b10001; 2:glyph_row=5'b10011; 3:glyph_row=5'b10101; 4:glyph_row=5'b11001; 5:glyph_row=5'b10001; 6:glyph_row=5'b01110; default:glyph_row=0; endcase
            6'd2:  case (glyph_y) 0:glyph_row=5'b00100; 1:glyph_row=5'b01100; 2:glyph_row=5'b00100; 3:glyph_row=5'b00100; 4:glyph_row=5'b00100; 5:glyph_row=5'b00100; 6:glyph_row=5'b01110; default:glyph_row=0; endcase
            6'd3:  case (glyph_y) 0:glyph_row=5'b01110; 1:glyph_row=5'b10001; 2:glyph_row=5'b00001; 3:glyph_row=5'b00010; 4:glyph_row=5'b00100; 5:glyph_row=5'b01000; 6:glyph_row=5'b11111; default:glyph_row=0; endcase
            6'd4:  case (glyph_y) 0:glyph_row=5'b11110; 1:glyph_row=5'b00001; 2:glyph_row=5'b00001; 3:glyph_row=5'b01110; 4:glyph_row=5'b00001; 5:glyph_row=5'b00001; 6:glyph_row=5'b11110; default:glyph_row=0; endcase
            6'd5:  case (glyph_y) 0:glyph_row=5'b00010; 1:glyph_row=5'b00110; 2:glyph_row=5'b01010; 3:glyph_row=5'b10010; 4:glyph_row=5'b11111; 5:glyph_row=5'b00010; 6:glyph_row=5'b00010; default:glyph_row=0; endcase
            6'd6:  case (glyph_y) 0:glyph_row=5'b11111; 1:glyph_row=5'b10000; 2:glyph_row=5'b10000; 3:glyph_row=5'b11110; 4:glyph_row=5'b00001; 5:glyph_row=5'b00001; 6:glyph_row=5'b11110; default:glyph_row=0; endcase
            6'd7:  case (glyph_y) 0:glyph_row=5'b01110; 1:glyph_row=5'b10000; 2:glyph_row=5'b10000; 3:glyph_row=5'b11110; 4:glyph_row=5'b10001; 5:glyph_row=5'b10001; 6:glyph_row=5'b01110; default:glyph_row=0; endcase
            6'd8:  case (glyph_y) 0:glyph_row=5'b11111; 1:glyph_row=5'b00001; 2:glyph_row=5'b00010; 3:glyph_row=5'b00100; 4:glyph_row=5'b01000; 5:glyph_row=5'b01000; 6:glyph_row=5'b01000; default:glyph_row=0; endcase
            6'd9:  case (glyph_y) 0:glyph_row=5'b01110; 1:glyph_row=5'b10001; 2:glyph_row=5'b10001; 3:glyph_row=5'b01110; 4:glyph_row=5'b10001; 5:glyph_row=5'b10001; 6:glyph_row=5'b01110; default:glyph_row=0; endcase
            6'd10: case (glyph_y) 0:glyph_row=5'b01110; 1:glyph_row=5'b10001; 2:glyph_row=5'b10001; 3:glyph_row=5'b01111; 4:glyph_row=5'b00001; 5:glyph_row=5'b00001; 6:glyph_row=5'b01110; default:glyph_row=0; endcase
            6'd11: case (glyph_y) 0:glyph_row=5'b01110; 1:glyph_row=5'b10001; 2:glyph_row=5'b10001; 3:glyph_row=5'b11111; 4:glyph_row=5'b10001; 5:glyph_row=5'b10001; 6:glyph_row=5'b10001; default:glyph_row=0; endcase
            6'd12: case (glyph_y) 0:glyph_row=5'b11110; 1:glyph_row=5'b10001; 2:glyph_row=5'b10001; 3:glyph_row=5'b11110; 4:glyph_row=5'b10001; 5:glyph_row=5'b10001; 6:glyph_row=5'b11110; default:glyph_row=0; endcase
            6'd13: case (glyph_y) 0:glyph_row=5'b01111; 1:glyph_row=5'b10000; 2:glyph_row=5'b10000; 3:glyph_row=5'b10000; 4:glyph_row=5'b10000; 5:glyph_row=5'b10000; 6:glyph_row=5'b01111; default:glyph_row=0; endcase
            6'd14: case (glyph_y) 0:glyph_row=5'b11110; 1:glyph_row=5'b10001; 2:glyph_row=5'b10001; 3:glyph_row=5'b10001; 4:glyph_row=5'b10001; 5:glyph_row=5'b10001; 6:glyph_row=5'b11110; default:glyph_row=0; endcase
            6'd15: case (glyph_y) 0:glyph_row=5'b11111; 1:glyph_row=5'b10000; 2:glyph_row=5'b10000; 3:glyph_row=5'b11110; 4:glyph_row=5'b10000; 5:glyph_row=5'b10000; 6:glyph_row=5'b11111; default:glyph_row=0; endcase
            6'd16: case (glyph_y) 0:glyph_row=5'b11111; 1:glyph_row=5'b10000; 2:glyph_row=5'b10000; 3:glyph_row=5'b11110; 4:glyph_row=5'b10000; 5:glyph_row=5'b10000; 6:glyph_row=5'b10000; default:glyph_row=0; endcase
            CH_COLON: if (glyph_y == 3'd2 || glyph_y == 3'd5) glyph_row=5'b00100;
            CH_LESS: case (glyph_y) 1:glyph_row=5'b00001; 2:glyph_row=5'b00110; 3:glyph_row=5'b11000; 4:glyph_row=5'b00110; 5:glyph_row=5'b00001; default:glyph_row=0; endcase
            CH_GREATER: case (glyph_y) 1:glyph_row=5'b10000; 2:glyph_row=5'b01100; 3:glyph_row=5'b00011; 4:glyph_row=5'b01100; 5:glyph_row=5'b10000; default:glyph_row=0; endcase
            CH_S: case (glyph_y) 0:glyph_row=5'b01111; 1:glyph_row=5'b10000; 2:glyph_row=5'b10000; 3:glyph_row=5'b01110; 4:glyph_row=5'b00001; 5:glyph_row=5'b00001; 6:glyph_row=5'b11110; default:glyph_row=0; endcase
            CH_M: case (glyph_y) 0:glyph_row=5'b10001; 1:glyph_row=5'b11011; 2:glyph_row=5'b10101; 3:glyph_row=5'b10101; 4:glyph_row=5'b10001; 5:glyph_row=5'b10001; 6:glyph_row=5'b10001; default:glyph_row=0; endcase
            CH_R: case (glyph_y) 0:glyph_row=5'b11110; 1:glyph_row=5'b10001; 2:glyph_row=5'b10001; 3:glyph_row=5'b11110; 4:glyph_row=5'b10100; 5:glyph_row=5'b10010; 6:glyph_row=5'b10001; default:glyph_row=0; endcase
            CH_T: case (glyph_y) 0:glyph_row=5'b11111; 1:glyph_row=5'b00100; 2:glyph_row=5'b00100; 3:glyph_row=5'b00100; 4:glyph_row=5'b00100; 5:glyph_row=5'b00100; 6:glyph_row=5'b00100; default:glyph_row=0; endcase
            default: glyph_row = 5'b00000;
        endcase
    end

    wire glyph_pixel =
        (glyph_x == 3'd1 && glyph_row[4]) ||
        (glyph_x == 3'd2 && glyph_row[3]) ||
        (glyph_x == 3'd3 && glyph_row[2]) ||
        (glyph_x == 3'd4 && glyph_row[1]) ||
        (glyph_x == 3'd5 && glyph_row[0]);
    assign pixel = pixel_active && glyph_pixel;

endmodule
