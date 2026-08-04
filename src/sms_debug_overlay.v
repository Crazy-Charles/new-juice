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
    output pixel
);

    wire [9:0] local_x = x - X_START;
    wire [9:0] local_y = y - Y_START;
    wire [4:0] character_cell = local_x[8:4];
    wire [2:0] glyph_x = local_x[3:1];
    wire [2:0] glyph_y = local_y[3:1];

    reg [3:0] digit;
    reg digit_valid;
    reg bracket_left;
    reg bracket_right;
    reg colon;
    reg [6:0] segments;

    // Seven-segment hexadecimal digits are much smaller than the previous
    // full 5x7 character ROM. Segment order is {a,b,c,d,e,f,g}; B and D use
    // their conventional lower-case seven-segment forms.
    always @* begin
        case (digit)
            4'h0: segments = 7'b1111110;
            4'h1: segments = 7'b0110000;
            4'h2: segments = 7'b1101101;
            4'h3: segments = 7'b1111001;
            4'h4: segments = 7'b0110011;
            4'h5: segments = 7'b1011011;
            4'h6: segments = 7'b1011111;
            4'h7: segments = 7'b1110000;
            4'h8: segments = 7'b1111111;
            4'h9: segments = 7'b1111011;
            4'hA: segments = 7'b1110111;
            4'hB: segments = 7'b0011111;
            4'hC: segments = 7'b1001110;
            4'hD: segments = 7'b0111101;
            4'hE: segments = 7'b1001111;
            default: segments = 7'b1000111;
        endcase
    end

    always @* begin
        digit = 4'd0;
        digit_valid = 1'b1;
        bracket_left = 1'b0;
        bracket_right = 1'b0;
        colon = 1'b0;

        case (character_cell)
            5'd0:  begin digit_valid = 1'b0; bracket_left = 1'b1; end
            5'd1:  digit = address[15:12];
            5'd2:  digit = address[11:8];
            5'd3:  digit = address[7:4];
            5'd4:  digit = address[3:0];
            5'd5:  begin digit_valid = 1'b0; bracket_right = 1'b1; end
            5'd6:  digit_valid = 1'b0;
            5'd7:  begin digit_valid = 1'b0; bracket_left = 1'b1; end
            5'd8:  digit = page0[7:4];
            5'd9:  digit = page0[3:0];
            5'd10: begin digit_valid = 1'b0; colon = 1'b1; end
            5'd11: digit = page1[7:4];
            5'd12: digit = page1[3:0];
            5'd13: begin digit_valid = 1'b0; colon = 1'b1; end
            5'd14: digit = page2[7:4];
            5'd15: digit = page2[3:0];
            5'd16: begin digit_valid = 1'b0; colon = 1'b1; end
            5'd17: digit = page3[7:4];
            5'd18: digit = page3[3:0];
            5'd19: begin digit_valid = 1'b0; bracket_right = 1'b1; end
            default: digit_valid = 1'b0;
        endcase
    end

    wire horizontal = glyph_x >= 3'd2 && glyph_x <= 3'd4;
    wire upper_vertical = glyph_y >= 3'd1 && glyph_y <= 3'd3;
    wire lower_vertical = glyph_y >= 3'd4 && glyph_y <= 3'd6;
    wire digit_pixel = digit_valid && (
        (segments[6] && glyph_y == 3'd0 && horizontal) ||
        (segments[5] && glyph_x == 3'd5 && upper_vertical) ||
        (segments[4] && glyph_x == 3'd5 && lower_vertical) ||
        (segments[3] && glyph_y == 3'd7 && horizontal) ||
        (segments[2] && glyph_x == 3'd1 && lower_vertical) ||
        (segments[1] && glyph_x == 3'd1 && upper_vertical) ||
        (segments[0] && glyph_y == 3'd3 && horizontal));
    wire left_bracket_pixel = bracket_left &&
        ((glyph_x == 3'd2) ||
         (glyph_x >= 3'd2 && glyph_x <= 3'd4 &&
          (glyph_y == 3'd0 || glyph_y == 3'd7)));
    wire right_bracket_pixel = bracket_right &&
        ((glyph_x == 3'd4) ||
         (glyph_x >= 3'd2 && glyph_x <= 3'd4 &&
          (glyph_y == 3'd0 || glyph_y == 3'd7)));
    wire colon_pixel = colon && glyph_x == 3'd3 &&
        (glyph_y == 3'd2 || glyph_y == 3'd5);
    wire overlay_window = x >= X_START && x < X_START + 10'd320 &&
                          y >= Y_START && y < Y_START + 10'd16;

    assign pixel = overlay_window &&
                   (digit_pixel || left_bracket_pixel ||
                    right_bracket_pixel || colon_pixel);

endmodule
