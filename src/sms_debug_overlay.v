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

    localparam [4:0] CHAR_LBRACKET = 5'd16;
    localparam [4:0] CHAR_RBRACKET = 5'd17;
    localparam [4:0] CHAR_COLON = 5'd18;
    localparam [4:0] CHAR_SPACE = 5'd19;

    reg [9:0] local_x;
    reg [9:0] local_y;
    reg [4:0] character;
    reg [4:0] glyph_bits;
    reg pixel_reg;

    function automatic [4:0] glyph_row;
        input [4:0] glyph;
        input [2:0] row;
        begin
            glyph_row = 5'b00000;
            case (glyph)
                5'h0: case (row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b10011; 3:glyph_row=5'b10101;
                    4:glyph_row=5'b11001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b01110; default:glyph_row=5'b00000;
                endcase
                5'h1: case (row)
                    0:glyph_row=5'b00100; 1:glyph_row=5'b01100;
                    2:glyph_row=5'b00100; 3:glyph_row=5'b00100;
                    4:glyph_row=5'b00100; 5:glyph_row=5'b00100;
                    6:glyph_row=5'b01110; default:glyph_row=5'b00000;
                endcase
                5'h2: case (row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b00001; 3:glyph_row=5'b00010;
                    4:glyph_row=5'b00100; 5:glyph_row=5'b01000;
                    6:glyph_row=5'b11111; default:glyph_row=5'b00000;
                endcase
                5'h3: case (row)
                    0:glyph_row=5'b11110; 1:glyph_row=5'b00001;
                    2:glyph_row=5'b00001; 3:glyph_row=5'b01110;
                    4:glyph_row=5'b00001; 5:glyph_row=5'b00001;
                    6:glyph_row=5'b11110; default:glyph_row=5'b00000;
                endcase
                5'h4: case (row)
                    0:glyph_row=5'b00010; 1:glyph_row=5'b00110;
                    2:glyph_row=5'b01010; 3:glyph_row=5'b10010;
                    4:glyph_row=5'b11111; 5:glyph_row=5'b00010;
                    6:glyph_row=5'b00010; default:glyph_row=5'b00000;
                endcase
                5'h5: case (row)
                    0:glyph_row=5'b11111; 1:glyph_row=5'b10000;
                    2:glyph_row=5'b10000; 3:glyph_row=5'b11110;
                    4:glyph_row=5'b00001; 5:glyph_row=5'b00001;
                    6:glyph_row=5'b11110; default:glyph_row=5'b00000;
                endcase
                5'h6: case (row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10000;
                    2:glyph_row=5'b10000; 3:glyph_row=5'b11110;
                    4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b01110; default:glyph_row=5'b00000;
                endcase
                5'h7: case (row)
                    0:glyph_row=5'b11111; 1:glyph_row=5'b00001;
                    2:glyph_row=5'b00010; 3:glyph_row=5'b00100;
                    4:glyph_row=5'b01000; 5:glyph_row=5'b01000;
                    6:glyph_row=5'b01000; default:glyph_row=5'b00000;
                endcase
                5'h8: case (row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b10001; 3:glyph_row=5'b01110;
                    4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b01110; default:glyph_row=5'b00000;
                endcase
                5'h9: case (row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b10001; 3:glyph_row=5'b01111;
                    4:glyph_row=5'b00001; 5:glyph_row=5'b00001;
                    6:glyph_row=5'b01110; default:glyph_row=5'b00000;
                endcase
                5'hA: case (row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b10001; 3:glyph_row=5'b11111;
                    4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b10001; default:glyph_row=5'b00000;
                endcase
                5'hB: case (row)
                    0:glyph_row=5'b11110; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b10001; 3:glyph_row=5'b11110;
                    4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b11110; default:glyph_row=5'b00000;
                endcase
                5'hC: case (row)
                    0:glyph_row=5'b01111; 1:glyph_row=5'b10000;
                    2:glyph_row=5'b10000; 3:glyph_row=5'b10000;
                    4:glyph_row=5'b10000; 5:glyph_row=5'b10000;
                    6:glyph_row=5'b01111; default:glyph_row=5'b00000;
                endcase
                5'hD: case (row)
                    0:glyph_row=5'b11110; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b10001; 3:glyph_row=5'b10001;
                    4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b11110; default:glyph_row=5'b00000;
                endcase
                5'hE: case (row)
                    0:glyph_row=5'b11111; 1:glyph_row=5'b10000;
                    2:glyph_row=5'b10000; 3:glyph_row=5'b11110;
                    4:glyph_row=5'b10000; 5:glyph_row=5'b10000;
                    6:glyph_row=5'b11111; default:glyph_row=5'b00000;
                endcase
                5'hF: case (row)
                    0:glyph_row=5'b11111; 1:glyph_row=5'b10000;
                    2:glyph_row=5'b10000; 3:glyph_row=5'b11110;
                    4:glyph_row=5'b10000; 5:glyph_row=5'b10000;
                    6:glyph_row=5'b10000; default:glyph_row=5'b00000;
                endcase
                CHAR_LBRACKET: case (row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b01000;
                    2:glyph_row=5'b01000; 3:glyph_row=5'b01000;
                    4:glyph_row=5'b01000; 5:glyph_row=5'b01000;
                    6:glyph_row=5'b01110; default:glyph_row=5'b00000;
                endcase
                CHAR_RBRACKET: case (row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b00010;
                    2:glyph_row=5'b00010; 3:glyph_row=5'b00010;
                    4:glyph_row=5'b00010; 5:glyph_row=5'b00010;
                    6:glyph_row=5'b01110; default:glyph_row=5'b00000;
                endcase
                CHAR_COLON: case (row)
                    1:glyph_row=5'b00100; 2:glyph_row=5'b00100;
                    4:glyph_row=5'b00100; 5:glyph_row=5'b00100;
                    default:glyph_row=5'b00000;
                endcase
                default: glyph_row=5'b00000;
            endcase
        end
    endfunction

    always @* begin
        local_x = x - X_START;
        local_y = y - Y_START;
        character = CHAR_SPACE;
        glyph_bits = 5'b00000;
        pixel_reg = 1'b0;

        // 20 characters: [AAAA] [00:11:22:33]
        if (x >= X_START && x < X_START + 10'd320 &&
            y >= Y_START && y < Y_START + 10'd16) begin
            case (local_x[8:4])
                5'd0:  character = CHAR_LBRACKET;
                5'd1:  character = {1'b0, address[15:12]};
                5'd2:  character = {1'b0, address[11:8]};
                5'd3:  character = {1'b0, address[7:4]};
                5'd4:  character = {1'b0, address[3:0]};
                5'd5:  character = CHAR_RBRACKET;
                5'd6:  character = CHAR_SPACE;
                5'd7:  character = CHAR_LBRACKET;
                5'd8:  character = {1'b0, page0[7:4]};
                5'd9:  character = {1'b0, page0[3:0]};
                5'd10: character = CHAR_COLON;
                5'd11: character = {1'b0, page1[7:4]};
                5'd12: character = {1'b0, page1[3:0]};
                5'd13: character = CHAR_COLON;
                5'd14: character = {1'b0, page2[7:4]};
                5'd15: character = {1'b0, page2[3:0]};
                5'd16: character = CHAR_COLON;
                5'd17: character = {1'b0, page3[7:4]};
                5'd18: character = {1'b0, page3[3:0]};
                5'd19: character = CHAR_RBRACKET;
                default: character = CHAR_SPACE;
            endcase

            glyph_bits = glyph_row(character, local_y[3:1]);
            if (local_x[3:1] >= 3'd1 && local_x[3:1] <= 3'd5)
                pixel_reg = glyph_bits[5-local_x[3:1]];
        end
    end

    assign pixel = pixel_reg;

endmodule
