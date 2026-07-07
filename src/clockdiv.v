
module clockdiv2
(
    input clk_src,
    input reset_n,
    output clk_div
);

logic clkd;

always_ff@(posedge clk_src or negedge reset_n)
begin
    if(!reset_n)
        clkd = clk_src;
    else
        clkd = ~clkd;
end

assign clk_div = clkd;

endmodule


module clockdiv
#(
parameter real CLK_SRC = 125,
parameter real CLK_DIV = 27
)
(
    input clk_src,
    inout reset_n,
    output clk_div
);

localparam int  CLK_HALF = $floor(CLK_SRC / CLK_DIV / 2.0);
localparam int  CLK_END  = $floor(CLK_SRC / CLK_DIV);

logic [$clog2(CLK_END-1):0] cdiv = 1;
logic clkd;

always_ff@(posedge clk_src or negedge reset_n)
begin
    if(!reset_n) begin
        clkd <= clk_src;
    end else 
    if (cdiv != CLK_HALF-1 && cdiv != CLK_END-1) 
        cdiv++;
    else begin 
        clkd <= ~clkd; 
        if (cdiv == CLK_END-1) begin
            cdiv <= 0;
        end
        else cdiv <= cdiv + 1;
    end
end

assign clk_div = clkd;


endmodule