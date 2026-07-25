module audio_drive
(
    input        clk_1p536m,
    input        rst_n,
    input [15:0] idata,
    output       req,
    output       HP_BCK,
    output       HP_WS,
    output       HP_DIN
);

    reg [4:0] bit_count;
    reg req_reg;
    reg req_delayed;
    reg [15:0] shift_reg;
    reg hp_ws_reg;
    reg hp_din_reg;

    assign HP_BCK = clk_1p536m;
    assign HP_WS = hp_ws_reg;
    assign HP_DIN = hp_din_reg;
    assign req = req_reg;

    // Match WonderTANG's proven I2S implementation: the serializer is
    // clocked directly by the globally buffered audio bit clock.
    always_ff @(posedge clk_1p536m or negedge rst_n)
    begin
        if (!rst_n)
            bit_count <= 5'd0;
        else
            bit_count <= bit_count + 1'b1;
    end

    always_ff @(posedge clk_1p536m or negedge rst_n)
    begin
        if (!rst_n)
            req_reg <= 1'b0;
        else
            req_reg <= bit_count == 5'd0 || bit_count == 5'd16;
    end

    always_ff @(posedge clk_1p536m or negedge rst_n)
    begin
        if (!rst_n) begin
            req_delayed <= 1'b0;
            shift_reg <= 16'd0;
        end else begin
            req_delayed <= req_reg;
            shift_reg <= req_delayed ? idata : shift_reg << 1;
        end
    end

    always_ff @(posedge clk_1p536m or negedge rst_n)
    begin
        if (!rst_n)
            hp_din_reg <= 1'b0;
        else
            hp_din_reg <= shift_reg[15];
    end

    always_ff @(posedge clk_1p536m or negedge rst_n)
    begin
        if (!rst_n)
            hp_ws_reg <= 1'b0;
        else if (bit_count == 5'd3)
            hp_ws_reg <= 1'b0;
        else if (bit_count == 5'd19)
            hp_ws_reg <= 1'b1;
    end

endmodule
