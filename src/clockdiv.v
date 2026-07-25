module clockdiv2
(
    input clk_src,
    input reset_n,
    output clk_div,
    output clk_rise
);

    reg clkd = 1'b0;
    reg rise_reg = 1'b0;

    always_ff @(posedge clk_src or negedge reset_n)
    begin
        if (!reset_n) begin
            clkd <= 1'b0;
            rise_reg <= 1'b0;
        end else begin
            clkd <= ~clkd;
            rise_reg <= !clkd;
        end
    end

    assign clk_div = clkd;
    assign clk_rise = rise_reg;

endmodule


// Fixed-period clock divider. The divisor is rounded to the nearest even
// integer so both halves of the output clock have the same duration. Unlike a
// fractional accumulator, this output is safe to route through a BUFG and use
// as a real clock.
module clockdiv
#(
    parameter integer CLK_HZ = 27_000_000,
    parameter integer OUT_HZ = 705_600
)
(
    input clk_src,
    input reset_n,
    output clk_div,
    output clk_rise
);

    localparam integer HALF_DIVIDE = (CLK_HZ + OUT_HZ) / (2 * OUT_HZ);
    localparam integer COUNT_WIDTH = (HALF_DIVIDE <= 1) ? 1 : $clog2(HALF_DIVIDE);

    reg [COUNT_WIDTH-1:0] count = {COUNT_WIDTH{1'b0}};
    reg clk_div_reg = 1'b0;
    reg clk_rise_reg = 1'b0;

    always_ff @(posedge clk_src or negedge reset_n)
    begin
        if (!reset_n) begin
            count <= {COUNT_WIDTH{1'b0}};
            clk_div_reg <= 1'b0;
            clk_rise_reg <= 1'b0;
        end else begin
            clk_rise_reg <= 1'b0;

            if (count == HALF_DIVIDE - 1) begin
                count <= {COUNT_WIDTH{1'b0}};
                clk_div_reg <= ~clk_div_reg;
                if (!clk_div_reg)
                    clk_rise_reg <= 1'b1;
            end else begin
                count <= count + 1'b1;
            end
        end
    end

    assign clk_div = clk_div_reg;
    assign clk_rise = clk_rise_reg;

endmodule
