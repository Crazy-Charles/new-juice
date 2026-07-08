module input_debouncer
#(
    parameter int WIDTH = 1,
    parameter int DEBOUNCE_CYCLES = 8
)
(
    input clk,
    input reset_n,
    input [WIDTH-1:0] in,
    output [WIDTH-1:0] out
);

    localparam int DEBOUNCE_BITS = $clog2(DEBOUNCE_CYCLES + 1);
    localparam [DEBOUNCE_BITS-1:0] DEBOUNCE_TARGET = DEBOUNCE_CYCLES;

    reg [WIDTH-1:0] sync_0 = {WIDTH{1'b1}};
    reg [WIDTH-1:0] sync_1 = {WIDTH{1'b1}};
    reg [WIDTH-1:0] debounced = {WIDTH{1'b1}};
    reg [WIDTH-1:0] candidate = {WIDTH{1'b1}};
    reg [DEBOUNCE_BITS-1:0] count [0:WIDTH-1];

    always_ff @(posedge clk or negedge reset_n)
    begin
        if(!reset_n) begin
            sync_0 <= {WIDTH{1'b1}};
            sync_1 <= {WIDTH{1'b1}};
            debounced <= {WIDTH{1'b1}};
            candidate <= {WIDTH{1'b1}};
            for (int i = 0; i < WIDTH; i++) begin
                count[i] <= {DEBOUNCE_BITS{1'b0}};
            end
        end else begin
            sync_0 <= in;
            sync_1 <= sync_0;

            for (int i = 0; i < WIDTH; i++) begin
                if (sync_1[i] == debounced[i]) begin
                    candidate[i] <= sync_1[i];
                    count[i] <= {DEBOUNCE_BITS{1'b0}};
                end else if (sync_1[i] != candidate[i]) begin
                    candidate[i] <= sync_1[i];
                    count[i] <= {{(DEBOUNCE_BITS-1){1'b0}}, 1'b1};
                end else if (count[i] == DEBOUNCE_TARGET) begin
                    debounced[i] <= candidate[i];
                    count[i] <= {DEBOUNCE_BITS{1'b0}};
                end else begin
                    count[i] <= count[i] + 1'b1;
                end
            end
        end
    end

    assign out = debounced;

endmodule
