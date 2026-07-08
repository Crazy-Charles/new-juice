module mp_debouncer
#(
    parameter int DEBOUNCE_CYCLES = 8
)
(
    input clk,
    input reset_n,
    input [7:0] mp,
    output [2:0] msel_n,
    output [7:0] a_lo,
    output [7:0] a_hi,
    output [15:0] addr,
    output merq_n,
    output iorq_n,
    output cs1_n,
    output cs2_n,
    output reset_in_n,
    output rfsh_n,
    output cs12_n,
    output m1_n,
    output inputs_latched
);

    localparam int DEBOUNCE_BITS = $clog2(DEBOUNCE_CYCLES + 1);
    localparam [DEBOUNCE_BITS-1:0] DEBOUNCE_TARGET = DEBOUNCE_CYCLES;
    localparam [DEBOUNCE_BITS-1:0] DEBOUNCE_LAST_SCAN = DEBOUNCE_CYCLES - 1;
    localparam int MP_A_LO = 0;
    localparam int MP_A_HI = 8;
    localparam int MP_CTRL = 16;
    localparam int MP_MERQ_N = 16;
    localparam int MP_IORQ_N = 17;
    localparam int MP_CS1_N = 18;
    localparam int MP_CS2_N = 19;
    localparam int MP_RESET_IN_N = 20;
    localparam int MP_RFSH_N = 21;
    localparam int MP_CS12_N = 22;
    localparam int MP_M1_N = 23;

    reg [2:0] msel_reg = 3'b011;
    reg [2:0] scan_phase = 3'd0;
    reg [7:0] mp_sync_0 = 8'hff;
    reg [7:0] mp_sync_1 = 8'hff;

    reg [23:0] debounced = 24'hffffff;
    reg [23:0] latched = 24'hffffff;
    reg [23:0] candidate = 24'hffffff;
    reg [DEBOUNCE_BITS-1:0] count [0:23];
    reg [DEBOUNCE_BITS-1:0] scan_count = {DEBOUNCE_BITS{1'b0}};
    reg inputs_latched_reg = 1'b0;

    always_ff @(posedge clk or negedge reset_n)
    begin
        if(!reset_n) begin
            msel_reg <= 3'b011;
            scan_phase <= 3'd0;
            mp_sync_0 <= 8'hff;
            mp_sync_1 <= 8'hff;
            debounced <= 24'hffffff;
            latched <= 24'hffffff;
            candidate <= 24'hffffff;
            scan_count <= {DEBOUNCE_BITS{1'b0}};
            inputs_latched_reg <= 1'b0;
            for (int i = 0; i < 24; i++) begin
                count[i] <= {DEBOUNCE_BITS{1'b0}};
            end
        end else begin
            mp_sync_0 <= mp;
            mp_sync_1 <= mp_sync_0;
            inputs_latched_reg <= 1'b0;

            case (scan_phase)
                3'd0: begin
                    msel_reg <= 3'b011;
                    scan_phase <= 3'd1;
                end
                3'd1: begin
                    scan_phase <= 3'd2;
                end
                3'd2: begin
                    for (int i = 0; i < 8; i++) begin
                        if (mp_sync_1[i] == debounced[MP_A_LO + i]) begin
                            candidate[MP_A_LO + i] <= mp_sync_1[i];
                            count[MP_A_LO + i] <= {DEBOUNCE_BITS{1'b0}};
                        end else if (mp_sync_1[i] != candidate[MP_A_LO + i]) begin
                            candidate[MP_A_LO + i] <= mp_sync_1[i];
                            count[MP_A_LO + i] <= {{(DEBOUNCE_BITS-1){1'b0}}, 1'b1};
                        end else if (count[MP_A_LO + i] == DEBOUNCE_TARGET) begin
                            debounced[MP_A_LO + i] <= candidate[MP_A_LO + i];
                            count[MP_A_LO + i] <= {DEBOUNCE_BITS{1'b0}};
                        end else begin
                            count[MP_A_LO + i] <= count[MP_A_LO + i] + 1'b1;
                        end
                    end

                    msel_reg <= 3'b101;
                    scan_phase <= 3'd3;
                end
                3'd3: begin
                    scan_phase <= 3'd4;
                end
                3'd4: begin
                    for (int i = 0; i < 8; i++) begin
                        if (mp_sync_1[i] == debounced[MP_A_HI + i]) begin
                            candidate[MP_A_HI + i] <= mp_sync_1[i];
                            count[MP_A_HI + i] <= {DEBOUNCE_BITS{1'b0}};
                        end else if (mp_sync_1[i] != candidate[MP_A_HI + i]) begin
                            candidate[MP_A_HI + i] <= mp_sync_1[i];
                            count[MP_A_HI + i] <= {{(DEBOUNCE_BITS-1){1'b0}}, 1'b1};
                        end else if (count[MP_A_HI + i] == DEBOUNCE_TARGET) begin
                            debounced[MP_A_HI + i] <= candidate[MP_A_HI + i];
                            count[MP_A_HI + i] <= {DEBOUNCE_BITS{1'b0}};
                        end else begin
                            count[MP_A_HI + i] <= count[MP_A_HI + i] + 1'b1;
                        end
                    end

                    msel_reg <= 3'b110;
                    scan_phase <= 3'd5;
                end
                3'd5: begin
                    scan_phase <= 3'd6;
                end
                default: begin
                    for (int i = 0; i < 8; i++) begin
                        if (mp_sync_1[i] == debounced[MP_CTRL + i]) begin
                            candidate[MP_CTRL + i] <= mp_sync_1[i];
                            count[MP_CTRL + i] <= {DEBOUNCE_BITS{1'b0}};
                        end else if (mp_sync_1[i] != candidate[MP_CTRL + i]) begin
                            candidate[MP_CTRL + i] <= mp_sync_1[i];
                            count[MP_CTRL + i] <= {{(DEBOUNCE_BITS-1){1'b0}}, 1'b1};
                        end else if (count[MP_CTRL + i] == DEBOUNCE_TARGET) begin
                            debounced[MP_CTRL + i] <= candidate[MP_CTRL + i];
                            count[MP_CTRL + i] <= {DEBOUNCE_BITS{1'b0}};
                        end else begin
                            count[MP_CTRL + i] <= count[MP_CTRL + i] + 1'b1;
                        end
                    end

                    msel_reg <= 3'b011;
                    scan_phase <= 3'd1;
                    if (scan_count == DEBOUNCE_LAST_SCAN) begin
                        scan_count <= {DEBOUNCE_BITS{1'b0}};
                        latched <= debounced;
                        inputs_latched_reg <= 1'b1;
                    end else begin
                        scan_count <= scan_count + 1'b1;
                    end
                end
            endcase
        end
    end

    assign msel_n = msel_reg;
    assign a_lo = latched[MP_A_LO +: 8];
    assign a_hi = latched[MP_A_HI +: 8];
    assign addr = {a_hi, a_lo};
    assign merq_n = latched[MP_MERQ_N];
    assign iorq_n = latched[MP_IORQ_N];
    assign cs1_n = latched[MP_CS1_N];
    assign cs2_n = latched[MP_CS2_N];
    assign reset_in_n = latched[MP_RESET_IN_N];
    assign rfsh_n = latched[MP_RFSH_N];
    assign cs12_n = latched[MP_CS12_N];
    assign m1_n = latched[MP_M1_N];
    assign inputs_latched = inputs_latched_reg;

endmodule
