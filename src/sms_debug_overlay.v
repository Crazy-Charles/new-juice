module sms_debug_overlay
#(
    parameter X_START = 10'd112,
    parameter Y_START = 10'd432
)
(
    input [9:0] x,
    input [9:0] y,
    input [15:0] address,
    input [7:0] page0,
    input [7:0] page1,
    input [7:0] page2,
    input [7:0] page3,
    input [7:0] bank0,
    input [7:0] bank1,
    input [7:0] bank2,
    input [7:0] bank3,
    input [63:0] read_history,
    input [15:0] read_tags,
    output pixel,
    output reg [1:0] color
);

    wire [9:0] local_x = x - X_START;
    wire [9:0] local_y = y - Y_START;
    wire [4:0] character_cell = local_x[8:4];
    wire separator = local_y == 10'd16;
    wire line = local_y >= 10'd17;
    wire [9:0] line_y = line ? local_y - 10'd17 : local_y;
    wire [2:0] glyph_x = local_x[3:1];
    wire [2:0] glyph_y = line_y[3:1];

    reg [3:0] digit;
    reg digit_valid;
    reg colon;
    reg [39:0] glyph_bitmap;
    reg [4:0] glyph_row;

    // Compact 5x8 monospaced hexadecimal font. Each glyph uses five visible
    // columns plus cell spacing, matching a conventional 6x8 bitmap font.
    always @* begin
        case (digit)
            4'h0: glyph_bitmap = {5'b01110, 5'b10001, 5'b10011, 5'b10101,
                                  5'b11001, 5'b10001, 5'b01110, 5'b00000};
            4'h1: glyph_bitmap = {5'b00100, 5'b01100, 5'b00100, 5'b00100,
                                  5'b00100, 5'b00100, 5'b01110, 5'b00000};
            4'h2: glyph_bitmap = {5'b01110, 5'b10001, 5'b00001, 5'b00010,
                                  5'b00100, 5'b01000, 5'b11111, 5'b00000};
            4'h3: glyph_bitmap = {5'b11110, 5'b00001, 5'b00001, 5'b01110,
                                  5'b00001, 5'b00001, 5'b11110, 5'b00000};
            4'h4: glyph_bitmap = {5'b00010, 5'b00110, 5'b01010, 5'b10010,
                                  5'b11111, 5'b00010, 5'b00010, 5'b00000};
            4'h5: glyph_bitmap = {5'b11111, 5'b10000, 5'b10000, 5'b11110,
                                  5'b00001, 5'b00001, 5'b11110, 5'b00000};
            4'h6: glyph_bitmap = {5'b01110, 5'b10000, 5'b10000, 5'b11110,
                                  5'b10001, 5'b10001, 5'b01110, 5'b00000};
            4'h7: glyph_bitmap = {5'b11111, 5'b00001, 5'b00010, 5'b00100,
                                  5'b01000, 5'b01000, 5'b01000, 5'b00000};
            4'h8: glyph_bitmap = {5'b01110, 5'b10001, 5'b10001, 5'b01110,
                                  5'b10001, 5'b10001, 5'b01110, 5'b00000};
            4'h9: glyph_bitmap = {5'b01110, 5'b10001, 5'b10001, 5'b01111,
                                  5'b00001, 5'b00001, 5'b01110, 5'b00000};
            4'hA: glyph_bitmap = {5'b01110, 5'b10001, 5'b10001, 5'b11111,
                                  5'b10001, 5'b10001, 5'b10001, 5'b00000};
            4'hB: glyph_bitmap = {5'b11110, 5'b10001, 5'b10001, 5'b11110,
                                  5'b10001, 5'b10001, 5'b11110, 5'b00000};
            4'hC: glyph_bitmap = {5'b01111, 5'b10000, 5'b10000, 5'b10000,
                                  5'b10000, 5'b10000, 5'b01111, 5'b00000};
            4'hD: glyph_bitmap = {5'b11110, 5'b10001, 5'b10001, 5'b10001,
                                  5'b10001, 5'b10001, 5'b11110, 5'b00000};
            4'hE: glyph_bitmap = {5'b11111, 5'b10000, 5'b10000, 5'b11110,
                                  5'b10000, 5'b10000, 5'b11111, 5'b00000};
            default: glyph_bitmap = {5'b11111, 5'b10000, 5'b10000, 5'b11110,
                                     5'b10000, 5'b10000, 5'b10000, 5'b00000};
        endcase

        case (glyph_y)
            3'd0: glyph_row = glyph_bitmap[39:35];
            3'd1: glyph_row = glyph_bitmap[34:30];
            3'd2: glyph_row = glyph_bitmap[29:25];
            3'd3: glyph_row = glyph_bitmap[24:20];
            3'd4: glyph_row = glyph_bitmap[19:15];
            3'd5: glyph_row = glyph_bitmap[14:10];
            3'd6: glyph_row = glyph_bitmap[9:5];
            default: glyph_row = glyph_bitmap[4:0];
        endcase
    end

    always @* begin
        digit = 4'd0;
        digit_valid = 1'b1;
        colon = 1'b0;
        color = 2'd1;

        if (!line) begin
            // AAAA P0:P1:P2:P3 B0:B1:B2:B3, with Pn/Bn replaced by
            // their two-digit hexadecimal values.
            case (character_cell)
                5'd0:  digit = address[15:12];
                5'd1:  digit = address[11:8];
                5'd2:  digit = address[7:4];
                5'd3:  digit = address[3:0];
                5'd4:  digit_valid = 1'b0;
                5'd5:  digit = page0[7:4];
                5'd6:  digit = page0[3:0];
                5'd7:  begin digit_valid = 1'b0; colon = 1'b1; end
                5'd8:  digit = page1[7:4];
                5'd9:  digit = page1[3:0];
                5'd10: begin digit_valid = 1'b0; colon = 1'b1; end
                5'd11: digit = page2[7:4];
                5'd12: digit = page2[3:0];
                5'd13: begin digit_valid = 1'b0; colon = 1'b1; end
                5'd14: digit = page3[7:4];
                5'd15: digit = page3[3:0];
                5'd16: digit_valid = 1'b0;
                5'd17: digit = bank0[7:4];
                5'd18: digit = bank0[3:0];
                5'd19: begin digit_valid = 1'b0; colon = 1'b1; end
                5'd20: digit = bank1[7:4];
                5'd21: digit = bank1[3:0];
                5'd22: begin digit_valid = 1'b0; colon = 1'b1; end
                5'd23: digit = bank2[7:4];
                5'd24: digit = bank2[3:0];
                5'd25: begin digit_valid = 1'b0; colon = 1'b1; end
                5'd26: digit = bank3[7:4];
                5'd27: digit = bank3[3:0];
                default: digit_valid = 1'b0;
            endcase
        end else begin
            // Eight most recent CPU-bus reads, oldest at the left and newest
            // at the right, separated by one blank character cell.
            case (character_cell)
                5'd0:  begin digit = read_history[63:60];
                              color = read_tags[15:14]; end
                5'd1:  begin digit = read_history[59:56];
                              color = read_tags[15:14]; end
                5'd2:  digit_valid = 1'b0;
                5'd3:  begin digit = read_history[55:52];
                              color = read_tags[13:12]; end
                5'd4:  begin digit = read_history[51:48];
                              color = read_tags[13:12]; end
                5'd5:  digit_valid = 1'b0;
                5'd6:  begin digit = read_history[47:44];
                              color = read_tags[11:10]; end
                5'd7:  begin digit = read_history[43:40];
                              color = read_tags[11:10]; end
                5'd8:  digit_valid = 1'b0;
                5'd9:  begin digit = read_history[39:36];
                              color = read_tags[9:8]; end
                5'd10: begin digit = read_history[35:32];
                              color = read_tags[9:8]; end
                5'd11: digit_valid = 1'b0;
                5'd12: begin digit = read_history[31:28];
                              color = read_tags[7:6]; end
                5'd13: begin digit = read_history[27:24];
                              color = read_tags[7:6]; end
                5'd14: digit_valid = 1'b0;
                5'd15: begin digit = read_history[23:20];
                              color = read_tags[5:4]; end
                5'd16: begin digit = read_history[19:16];
                              color = read_tags[5:4]; end
                5'd17: digit_valid = 1'b0;
                5'd18: begin digit = read_history[15:12];
                              color = read_tags[3:2]; end
                5'd19: begin digit = read_history[11:8];
                              color = read_tags[3:2]; end
                5'd20: digit_valid = 1'b0;
                5'd21: begin digit = read_history[7:4];
                              color = read_tags[1:0]; end
                5'd22: begin digit = read_history[3:0];
                              color = read_tags[1:0]; end
                default: digit_valid = 1'b0;
            endcase
        end
    end

    wire digit_pixel = digit_valid &&
        ((glyph_x == 3'd1 && glyph_row[4]) ||
         (glyph_x == 3'd2 && glyph_row[3]) ||
         (glyph_x == 3'd3 && glyph_row[2]) ||
         (glyph_x == 3'd4 && glyph_row[1]) ||
         (glyph_x == 3'd5 && glyph_row[0]));
    wire colon_pixel = colon && glyph_x == 3'd3 &&
        (glyph_y == 3'd2 || glyph_y == 3'd5);
    wire overlay_window = x >= X_START && x < X_START + 10'd448 &&
                          y >= Y_START && y < Y_START + 10'd33;

    assign pixel = overlay_window && !separator &&
                   (digit_pixel || colon_pixel);

endmodule
