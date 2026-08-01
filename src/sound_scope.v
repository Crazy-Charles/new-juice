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
    reg [12:0] history_divider = 13'd0;
    reg [5:0] peak_divider = 6'd0;
    reg [7:0] psg_level = 8'd0;
    reg [7:0] scc_level = 8'd0;
    reg [7:0] opll_level = 8'd0;
    reg [7:0] opm_level = 8'd0;
    reg [7:0] psg_peak = 8'd0;
    reg [7:0] scc_peak = 8'd0;
    reg [7:0] opll_peak = 8'd0;
    reg [7:0] opm_peak = 8'd0;
    reg [9:0] psg_dc_level = 10'd0;
    reg [5:0] psg_bar_history [0:13];
    reg [5:0] scc_bar_history [0:13];
    reg [5:0] opll_bar_history [0:13];
    reg [5:0] opm_bar_history [0:13];
    reg signed [5:0] psg_wave_history [0:55];
    reg signed [5:0] scc_wave_history [0:55];
    reg signed [5:0] opll_wave_history [0:55];
    reg signed [5:0] opm_wave_history [0:55];
    integer history_index;

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
    wire signed [10:0] psg_centered =
        $signed({1'b0, psg_sample}) -
        $signed({1'b0, psg_dc_level});
    wire signed [10:0] psg_wave_scaled = psg_centered >>> 4;
    wire signed [5:0] psg_wave_sample =
        psg_wave_scaled > 11'sd31 ? 6'sd31 :
        psg_wave_scaled < -11'sd32 ? 6'sb100000 :
        psg_wave_scaled[5:0];
    wire signed [5:0] scc_wave_sample = scc_sample >>> 5;
    wire signed [5:0] opll_wave_sample = opll_sample >>> 10;
    wire signed [5:0] opm_wave_sample = opm_sample >>> 10;

    always_ff @(posedge clk or negedge reset_n)
    begin
        if (!reset_n) begin
            envelope_divider <= 11'd0;
            history_divider <= 13'd0;
            peak_divider <= 6'd0;
            psg_level <= 8'd0;
            scc_level <= 8'd0;
            opll_level <= 8'd0;
            opm_level <= 8'd0;
            psg_peak <= 8'd0;
            scc_peak <= 8'd0;
            opll_peak <= 8'd0;
            opm_peak <= 8'd0;
            psg_dc_level <= 10'd0;
            for (history_index = 0; history_index < 14;
                 history_index = history_index + 1) begin
                psg_bar_history[history_index] <= 6'd0;
                scc_bar_history[history_index] <= 6'd0;
                opll_bar_history[history_index] <= 6'd0;
                opm_bar_history[history_index] <= 6'd0;
            end
            for (history_index = 0; history_index < 56;
                 history_index = history_index + 1) begin
                psg_wave_history[history_index] <= 6'sd0;
                scc_wave_history[history_index] <= 6'sd0;
                opll_wave_history[history_index] <= 6'sd0;
                opm_wave_history[history_index] <= 6'sd0;
            end
        end else begin
            envelope_divider <= envelope_divider + 1'b1;
            history_divider <= history_divider + 1'b1;
            if (&envelope_divider) begin
                peak_divider <= peak_divider + 1'b1;
                // JT49 is unipolar and its DC level varies with channel
                // volume and duty activity. Track that level only for the
                // visualizer so its trace shares the signed chips' zero line.
                if (psg_sample > psg_dc_level) begin
                    if (psg_dc_level <= 10'd1021)
                        psg_dc_level <= psg_dc_level + 2'd2;
                    else
                        psg_dc_level <= 10'd1023;
                end else if (psg_sample < psg_dc_level) begin
                    if (psg_dc_level >= 10'd2)
                        psg_dc_level <= psg_dc_level - 2'd2;
                    else
                        psg_dc_level <= 10'd0;
                end
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

            // Keep short histories for the vertical LED bank and for a
            // signed oscilloscope trace. At roughly 3.3 kHz, the trace shows
            // several useful audio cycles while still moving visibly.
            if (&history_divider) begin
                for (history_index = 13; history_index > 0;
                     history_index = history_index - 1) begin
                    psg_bar_history[history_index] <=
                        psg_bar_history[history_index-1];
                    scc_bar_history[history_index] <=
                        scc_bar_history[history_index-1];
                    opll_bar_history[history_index] <=
                        opll_bar_history[history_index-1];
                    opm_bar_history[history_index] <=
                        opm_bar_history[history_index-1];
                end
                psg_bar_history[0] <= psg_level[7:2];
                scc_bar_history[0] <= scc_level[7:2];
                opll_bar_history[0] <= opll_level[7:2];
                opm_bar_history[0] <= opm_level[7:2];

                for (history_index = 55; history_index > 0;
                     history_index = history_index - 1) begin
                    psg_wave_history[history_index] <=
                        psg_wave_history[history_index-1];
                    scc_wave_history[history_index] <=
                        scc_wave_history[history_index-1];
                    opll_wave_history[history_index] <=
                        opll_wave_history[history_index-1];
                    opm_wave_history[history_index] <=
                        opm_wave_history[history_index-1];
                end
                psg_wave_history[0] <= psg_wave_sample;
                scc_wave_history[0] <= scc_wave_sample;
                opll_wave_history[0] <= opll_wave_sample;
                opm_wave_history[0] <= opm_wave_sample;
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
    reg [5:0] accent;
    reg [5:0] background;
    reg [3:0] bar_index;
    reg [5:0] wave_index;
    reg [5:0] bar_level;
    reg [6:0] bar_top;
    reg signed [5:0] wave_sample;
    reg signed [5:0] wave_neighbor;
    reg signed [8:0] wave_y;
    reg signed [8:0] wave_neighbor_y;

    always_comb
    begin
        panel = {y >= 8'd96, x[7]};
        local_x = x[6:0];
        local_y = y >= 8'd96 ? y[6:0] - 7'd96 : y[6:0];

        bar_index = (local_x - 7'd8) >> 3;
        wave_index = 6'd0;
        if (local_x >= 7'd8 && local_x <= 7'd119)
            wave_index = (7'd119 - local_x) >> 1;
        bar_level = 6'd0;
        wave_sample = psg_wave_history[wave_index];
        wave_neighbor = wave_index == 6'd0 ?
                        psg_wave_history[0] :
                        psg_wave_history[wave_index-1'b1];
        accent = COLOR_GREEN;
        background = 6'b000100;
        case (panel)
            2'd1: begin
                if (bar_index < 4'd14)
                    bar_level=scc_bar_history[bar_index];
                wave_sample=scc_wave_history[wave_index];
                wave_neighbor=wave_index == 6'd0 ?
                              scc_wave_history[0] :
                              scc_wave_history[wave_index-1'b1];
                accent=COLOR_CYAN; background=6'b000101;
            end
            2'd2: begin
                if (bar_index < 4'd14)
                    bar_level=opll_bar_history[bar_index];
                wave_sample=opll_wave_history[wave_index];
                wave_neighbor=wave_index == 6'd0 ?
                              opll_wave_history[0] :
                              opll_wave_history[wave_index-1'b1];
                accent=COLOR_AMBER; background=6'b010100;
            end
            2'd3: begin
                if (bar_index < 4'd14)
                    bar_level=opm_bar_history[bar_index];
                wave_sample=opm_wave_history[wave_index];
                wave_neighbor=wave_index == 6'd0 ?
                              opm_wave_history[0] :
                              opm_wave_history[wave_index-1'b1];
                accent=COLOR_MAGENTA; background=6'b010001;
            end
            default: begin
                if (bar_index < 4'd14)
                    bar_level=psg_bar_history[bar_index];
            end
        endcase

        bar_top = 7'd89 - {1'b0, bar_level};
        wave_y = 9'sd57 - wave_sample;
        wave_neighbor_y = 9'sd57 - wave_neighbor;

        // Subtle horizontal scanlines over four differently tinted metal
        // faceplates, with a black title recess at the top of each deck.
        pixel = local_y[1:0] == 2'b00 ? COLOR_BLACK : background;
        if (local_y >= 7'd3 && local_y <= 7'd17)
            pixel = COLOR_BLACK;
        if (local_y == 7'd19 || local_y == 7'd20)
            pixel = accent;

        if (label_pixel(panel, local_x, local_y))
            pixel = accent;

        // Fourteen independent history columns fill nearly the whole panel.
        // Every column is a segmented LED meter that rises bottom-to-top.
        if (local_x >= 7'd8 && local_x <= 7'd119 &&
            local_y >= 7'd24 && local_y <= 7'd89 &&
            bar_index < 4'd14) begin
            if (local_x[2:0] >= 3'd6 || local_y[1:0] == 2'b11)
                pixel = COLOR_BLACK;
            else if (local_y >= bar_top) begin
                if (local_y < 7'd37)
                    pixel = COLOR_RED;
                else if (local_y < 7'd50)
                    pixel = COLOR_YELLOW;
                else
                    pixel = accent;
                if (local_y == bar_top)
                    pixel = COLOR_WHITE;
            end else
                pixel = COLOR_DIM;
        end

        // Conventional oscilloscope orientation: history runs left-to-right,
        // zero is the horizontal centerline and signed amplitude moves above
        // or below it. A one-pixel connector joins each two-pixel sample.
        if (local_y == 7'd57 &&
            local_x >= 7'd8 && local_x <= 7'd119)
            pixel = COLOR_SILVER;
        if (local_x >= 7'd8 && local_x <= 7'd119 &&
            local_y >= 7'd26 && local_y <= 7'd89) begin
            if ($signed({1'b0, local_y}) == wave_y)
                pixel = COLOR_WHITE;
            if (local_x[0] && wave_index != 6'd0 &&
                (($signed({1'b0, local_y}) >= wave_y &&
                  $signed({1'b0, local_y}) <= wave_neighbor_y) ||
                 ($signed({1'b0, local_y}) <= wave_y &&
                  $signed({1'b0, local_y}) >= wave_neighbor_y)))
                pixel = COLOR_WHITE;
        end

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
