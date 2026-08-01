module sound_scope
(
    input                    clk,
    input                    reset_n,
    input      [7:0]         x,
    input      [7:0]         y,
    input      [9:0]         psg_sample,
    input signed [10:0]      scc_sample,
    input signed [15:0]      opll_sample,
    input signed [15:0]      opm_sample,
    output reg [5:0]         pixel
);

    localparam [5:0] COLOR_BLACK   = 6'b000000;
    localparam [5:0] COLOR_DIM     = 6'b010101;
    localparam [5:0] COLOR_SILVER  = 6'b101010;
    localparam [5:0] COLOR_WHITE   = 6'b111111;
    localparam [5:0] COLOR_GREEN   = 6'b001100;
    localparam [5:0] COLOR_YELLOW  = 6'b111100;
    localparam [5:0] COLOR_RED     = 6'b110000;
    localparam [5:0] COLOR_CYAN    = 6'b001111;
    localparam [5:0] COLOR_AMBER   = 6'b111000;
    localparam [5:0] COLOR_MAGENTA = 6'b110011;

    reg [10:0] envelope_divider = 11'd0;
    reg [5:0] peak_divider = 6'd0;
    reg [7:0] psg_level = 8'd0;
    reg [7:0] scc_level = 8'd0;
    reg [7:0] opll_level = 8'd0;
    reg [7:0] opm_level = 8'd0;
    reg [7:0] psg_peak = 8'd0;
    reg [7:0] scc_peak = 8'd0;
    reg [7:0] opll_peak = 8'd0;
    reg [7:0] opm_peak = 8'd0;

    function automatic [7:0] magnitude11;
        input signed [10:0] value;
        reg [10:0] magnitude;
        begin
            magnitude = value[10] ? (~value + 1'b1) : value;
            magnitude11 = magnitude[10] ? 8'hff : magnitude[9:2];
        end
    endfunction

    function automatic [7:0] magnitude16;
        input signed [15:0] value;
        reg [15:0] magnitude;
        begin
            magnitude = value[15] ? (~value + 1'b1) : value;
            magnitude16 = magnitude[15] ? 8'hff : magnitude[14:7];
        end
    endfunction

    wire [7:0] psg_magnitude = psg_sample[9:2];
    wire [7:0] scc_magnitude = magnitude11(scc_sample);
    wire [7:0] opll_magnitude = magnitude16(opll_sample);
    wire [7:0] opm_magnitude = magnitude16(opm_sample);

    always_ff @(posedge clk or negedge reset_n)
    begin
        if (!reset_n) begin
            envelope_divider <= 11'd0;
            peak_divider <= 6'd0;
            psg_level <= 8'd0;
            scc_level <= 8'd0;
            opll_level <= 8'd0;
            opm_level <= 8'd0;
            psg_peak <= 8'd0;
            scc_peak <= 8'd0;
            opll_peak <= 8'd0;
            opm_peak <= 8'd0;
        end else begin
            envelope_divider <= envelope_divider + 1'b1;
            if (&envelope_divider) begin
                peak_divider <= peak_divider + 1'b1;
                // Classic VU envelope: instantaneous attack with a linear
                // decay. This responds crisply without four arithmetic
                // smoothing filters or long carry chains.
                if (psg_magnitude >= psg_level)
                    psg_level <= psg_magnitude;
                else if (psg_level != 8'd0)
                    psg_level <= psg_level - 1'b1;

                if (scc_magnitude >= scc_level)
                    scc_level <= scc_magnitude;
                else if (scc_level != 8'd0)
                    scc_level <= scc_level - 1'b1;

                if (opll_magnitude >= opll_level)
                    opll_level <= opll_magnitude;
                else if (opll_level != 8'd0)
                    opll_level <= opll_level - 1'b1;

                if (opm_magnitude >= opm_level)
                    opm_level <= opm_magnitude;
                else if (opm_level != 8'd0)
                    opm_level <= opm_level - 1'b1;

                if (psg_magnitude > psg_peak)
                    psg_peak <= psg_magnitude;
                else if (&peak_divider && psg_peak != 8'd0)
                    psg_peak <= psg_peak - 1'b1;

                if (scc_magnitude > scc_peak)
                    scc_peak <= scc_magnitude;
                else if (&peak_divider && scc_peak != 8'd0)
                    scc_peak <= scc_peak - 1'b1;

                if (opll_magnitude > opll_peak)
                    opll_peak <= opll_magnitude;
                else if (&peak_divider && opll_peak != 8'd0)
                    opll_peak <= opll_peak - 1'b1;

                if (opm_magnitude > opm_peak)
                    opm_peak <= opm_magnitude;
                else if (&peak_divider && opm_peak != 8'd0)
                    opm_peak <= opm_peak - 1'b1;
            end
        end
    end

    // Five-by-seven source-name glyphs. Glyph numbers are local to this
    // module: 0=P, 1=S, 2=G, 3=C, 4=O, 5=L, 6=M.
    function automatic [4:0] glyph_row;
        input [2:0] glyph;
        input [2:0] row;
        begin
            glyph_row = 5'b00000;
            case (glyph)
                3'd0: case (row) // P
                    0: glyph_row=5'b11110; 1: glyph_row=5'b10001;
                    2: glyph_row=5'b10001; 3: glyph_row=5'b11110;
                    4: glyph_row=5'b10000; 5: glyph_row=5'b10000;
                    6: glyph_row=5'b10000; default: glyph_row=5'b00000;
                endcase
                3'd1: case (row) // S
                    0: glyph_row=5'b01111; 1: glyph_row=5'b10000;
                    2: glyph_row=5'b10000; 3: glyph_row=5'b01110;
                    4: glyph_row=5'b00001; 5: glyph_row=5'b00001;
                    6: glyph_row=5'b11110; default: glyph_row=5'b00000;
                endcase
                3'd2: case (row) // G
                    0: glyph_row=5'b01110; 1: glyph_row=5'b10001;
                    2: glyph_row=5'b10000; 3: glyph_row=5'b10111;
                    4: glyph_row=5'b10001; 5: glyph_row=5'b10001;
                    6: glyph_row=5'b01110; default: glyph_row=5'b00000;
                endcase
                3'd3: case (row) // C
                    0: glyph_row=5'b01111; 1: glyph_row=5'b10000;
                    2: glyph_row=5'b10000; 3: glyph_row=5'b10000;
                    4: glyph_row=5'b10000; 5: glyph_row=5'b10000;
                    6: glyph_row=5'b01111; default: glyph_row=5'b00000;
                endcase
                3'd4: case (row) // O
                    0: glyph_row=5'b01110; 1: glyph_row=5'b10001;
                    2: glyph_row=5'b10001; 3: glyph_row=5'b10001;
                    4: glyph_row=5'b10001; 5: glyph_row=5'b10001;
                    6: glyph_row=5'b01110; default: glyph_row=5'b00000;
                endcase
                3'd5: case (row) // L
                    0: glyph_row=5'b10000; 1: glyph_row=5'b10000;
                    2: glyph_row=5'b10000; 3: glyph_row=5'b10000;
                    4: glyph_row=5'b10000; 5: glyph_row=5'b10000;
                    6: glyph_row=5'b11111; default: glyph_row=5'b00000;
                endcase
                3'd6: case (row) // M
                    0: glyph_row=5'b10001; 1: glyph_row=5'b11011;
                    2: glyph_row=5'b10101; 3: glyph_row=5'b10101;
                    4: glyph_row=5'b10001; 5: glyph_row=5'b10001;
                    6: glyph_row=5'b10001; default: glyph_row=5'b00000;
                endcase
                default: glyph_row=5'b00000;
            endcase
        end
    endfunction

    function automatic label_pixel;
        input [1:0] panel;
        input [6:0] xx;
        input [6:0] yy;
        reg [6:0] start_x;
        reg [6:0] dx;
        reg [1:0] character;
        reg [2:0] column;
        reg [2:0] glyph;
        reg [4:0] bits;
        begin
            label_pixel = 1'b0;
            start_x = panel == 2'd2 ? 7'd52 : 7'd55;
            if (yy >= 7'd8 && yy < 7'd15 && xx >= start_x) begin
                dx = xx - start_x;
                character = 2'd0;
                column = 3'd0;
                if (dx < 7'd5) begin
                    character = 2'd0; column = dx[2:0];
                end else if (dx >= 7'd6 && dx < 7'd11) begin
                    character = 2'd1; column = dx[2:0] - 3'd6;
                end else if (dx >= 7'd12 && dx < 7'd17) begin
                    character = 2'd2; column = dx[2:0] - 3'd4;
                end else if (panel == 2'd2 &&
                             dx >= 7'd18 && dx < 7'd23) begin
                    character = 2'd3; column = dx[2:0] - 3'd2;
                end else begin
                    character = 2'd0; column = 3'd7;
                end

                glyph = 3'd0;
                case (panel)
                    2'd0: case (character)
                        0: glyph=3'd0; 1: glyph=3'd1; default: glyph=3'd2;
                    endcase
                    2'd1: case (character)
                        0: glyph=3'd1; default: glyph=3'd3;
                    endcase
                    2'd2: case (character)
                        0: glyph=3'd4; 1: glyph=3'd0; default: glyph=3'd5;
                    endcase
                    default: case (character)
                        0: glyph=3'd4; 1: glyph=3'd0; default: glyph=3'd6;
                    endcase
                endcase
                bits = glyph_row(glyph, yy - 7'd8);
                if (column < 3'd5)
                    label_pixel = bits[4-column];
            end
        end
    endfunction

    reg [1:0] panel;
    reg [6:0] local_x;
    reg [6:0] local_y;
    reg [7:0] level;
    reg [7:0] peak;
    reg [5:0] accent;
    reg [5:0] background;
    reg [5:0] segment;
    reg [7:0] filled_segments;
    reg [7:0] peak_position;
    reg [7:0] needle_position;

    always_comb
    begin
        panel = {y >= 8'd96, x[7]};
        local_x = x[6:0];
        local_y = y >= 8'd96 ? y[6:0] - 7'd96 : y[6:0];

        level = psg_level;
        peak = psg_peak;
        accent = COLOR_GREEN;
        background = 6'b000100;
        case (panel)
            2'd1: begin
                level=scc_level; peak=scc_peak;
                accent=COLOR_CYAN; background=6'b000101;
            end
            2'd2: begin
                level=opll_level; peak=opll_peak;
                accent=COLOR_AMBER; background=6'b010100;
            end
            2'd3: begin
                level=opm_level; peak=opm_peak;
                accent=COLOR_MAGENTA; background=6'b010001;
            end
            default: begin end
        endcase

        // Approximate 107/256 scaling without a multiplier. Positions cover
        // pixels 10 through 116 inside each 128-pixel-wide meter panel.
        peak_position = 8'd10 + (peak >> 2) + (peak >> 3) +
                        (peak >> 5) + (peak >> 6);
        needle_position = 8'd10 + (level >> 2) + (level >> 3) +
                          (level >> 5) + (level >> 6);
        filled_segments = level >> 3;
        segment = (local_x - 7'd10) >> 2;

        // Subtle horizontal scanlines over four differently tinted metal
        // faceplates, with a black title recess at the top of each deck.
        pixel = local_y[1:0] == 2'b00 ? COLOR_BLACK : background;
        if (local_y >= 7'd4 && local_y <= 7'd19)
            pixel = COLOR_BLACK;
        if (local_y == 7'd21 || local_y == 7'd22)
            pixel = accent;

        if (label_pixel(panel, local_x, local_y))
            pixel = accent;

        // Twenty-seven four-pixel LED segments. The last five segments move
        // through amber into red, like a classic cassette-deck peak meter.
        if (local_x >= 7'd10 && local_x <= 7'd117 &&
            local_y >= 7'd34 && local_y <= 7'd57) begin
            if (local_x[1:0] == 2'b11)
                pixel = COLOR_BLACK;
            else if (segment < filled_segments) begin
                if (segment < 6'd17)
                    pixel = COLOR_GREEN;
                else if (segment < 6'd23)
                    pixel = COLOR_YELLOW;
                else
                    pixel = COLOR_RED;
                if (local_y == 7'd35)
                    pixel = COLOR_WHITE;
            end else begin
                pixel = COLOR_DIM;
            end

            if (local_x == peak_position[6:0])
                pixel = COLOR_WHITE;
        end

        // Calibrated-looking tick marks and a second live needle underneath
        // the LED bank make each quadrant read as an independent instrument.
        if (local_y == 7'd65 && local_x >= 7'd10 && local_x <= 7'd117)
            pixel = COLOR_SILVER;
        if ((local_x == 7'd10 || local_x == 7'd31 ||
             local_x == 7'd52 || local_x == 7'd74 ||
             local_x == 7'd95 || local_x == 7'd117) &&
            local_y >= 7'd62 && local_y <= 7'd68)
            pixel = COLOR_SILVER;
        if (local_x == needle_position[6:0] &&
            local_y >= 7'd70 && local_y <= 7'd84)
            pixel = accent;
        if (local_y == 7'd84 && local_x >= 7'd10 && local_x <= 7'd117)
            pixel = COLOR_DIM;

        // Bezel, center cross and four small mounting screws per panel.
        if (local_x == 7'd0 || local_x == 7'd127 ||
            local_y == 7'd0 || local_y == 7'd95)
            pixel = COLOR_SILVER;
        if (((local_x >= 7'd4 && local_x <= 7'd5) ||
             (local_x >= 7'd122 && local_x <= 7'd123)) &&
            ((local_y >= 7'd4 && local_y <= 7'd5) ||
             (local_y >= 7'd90 && local_y <= 7'd91)))
            pixel = COLOR_WHITE;
    end

endmodule
