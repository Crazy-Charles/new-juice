module cpu_step_debugger
#(
    parameter integer CLK_HZ = 108_000_000,
    parameter integer DEBOUNCE_MS = 10,
    parameter integer LONG_PRESS_MS = 1000
)
(
    input clk,
    input reset_n,
    input s2,
    input m1_n,
    input software_toggle,
    output wait_n,
    output enabled
);

    localparam integer DEBOUNCE_CYCLES =
        (CLK_HZ / 1000) * DEBOUNCE_MS;
    localparam integer LONG_PRESS_CYCLES =
        (CLK_HZ / 1000) * LONG_PRESS_MS;

    (* ASYNC_REG = "TRUE" *) reg [1:0] s2_sync = 2'b00;
    reg s2_debounced = 1'b0;
    reg [20:0] debounce_count = 21'd0;
    reg [26:0] press_count = 27'd0;
    reg long_press_handled = 1'b0;
    reg short_press_pulse = 1'b0;
    reg long_press_pulse = 1'b0;

    reg step_enabled = 1'b0;
    reg wait_hold = 1'b0;
    reg arm_next_fetch = 1'b0;
    reg skip_next_fetch = 1'b0;
    reg previous_m1_n = 1'b1;

    // M1 alone identifies the start of an instruction fetch. The multiplexed
    // bus sampler can publish MERQ/RFSH at a slightly different point in the
    // same M1 cycle, so qualifying this edge with either signal can miss it.
    wire fetch_start = previous_m1_n && !m1_n;

    // S2 is active high on the Tang Nano board. Require 10 ms of stability
    // before accepting either edge, then distinguish release-before-one-second
    // (step) from a one-second hold (toggle stepping mode).
    always_ff @(posedge clk or negedge reset_n)
    begin
        if (!reset_n) begin
            s2_sync <= 2'b00;
            s2_debounced <= 1'b0;
            debounce_count <= 21'd0;
            press_count <= 27'd0;
            long_press_handled <= 1'b0;
            short_press_pulse <= 1'b0;
            long_press_pulse <= 1'b0;
        end else begin
            s2_sync <= {s2_sync[0], s2};
            short_press_pulse <= 1'b0;
            long_press_pulse <= 1'b0;

            if (s2_sync[1] == s2_debounced) begin
                debounce_count <= 21'd0;
            end else if (debounce_count == DEBOUNCE_CYCLES - 1) begin
                debounce_count <= 21'd0;
                s2_debounced <= s2_sync[1];
                if (!s2_sync[1]) begin
                    if (!long_press_handled)
                        short_press_pulse <= 1'b1;
                    press_count <= 27'd0;
                    long_press_handled <= 1'b0;
                end
            end else begin
                debounce_count <= debounce_count + 1'b1;
            end

            // Include the synchronized raw level so that, on an accepted
            // release, this block cannot overwrite press_count's reset using
            // the previous cycle's still-high debounced state.
            if (s2_debounced && s2_sync[1] && !long_press_handled) begin
                if (press_count == LONG_PRESS_CYCLES - 1) begin
                    press_count <= press_count;
                    long_press_handled <= 1'b1;
                    long_press_pulse <= 1'b1;
                end else begin
                    press_count <= press_count + 1'b1;
                end
            end
        end
    end

    // WAIT is asserted during the fetch of the instruction that is about to
    // execute. Releasing it lets that complete instruction run; the following
    // M1 fetch is then held. A software toggle skips one fetch so the launcher's
    // final JP/CALL can transfer control before the first halt.
    always_ff @(posedge clk or negedge reset_n)
    begin
        if (!reset_n) begin
            step_enabled <= 1'b0;
            wait_hold <= 1'b0;
            arm_next_fetch <= 1'b0;
            skip_next_fetch <= 1'b0;
            previous_m1_n <= 1'b1;
        end else begin
            previous_m1_n <= m1_n;

            if (long_press_pulse || software_toggle) begin
                if (step_enabled) begin
                    step_enabled <= 1'b0;
                    wait_hold <= 1'b0;
                    arm_next_fetch <= 1'b0;
                    skip_next_fetch <= 1'b0;
                end else begin
                    step_enabled <= 1'b1;
                    wait_hold <= 1'b0;
                    arm_next_fetch <= 1'b1;
                    skip_next_fetch <= software_toggle;
                end
            end else if (step_enabled && short_press_pulse) begin
                wait_hold <= 1'b0;
                arm_next_fetch <= 1'b1;
            end else if (step_enabled && arm_next_fetch && fetch_start) begin
                if (skip_next_fetch) begin
                    skip_next_fetch <= 1'b0;
                end else begin
                    wait_hold <= 1'b1;
                    arm_next_fetch <= 1'b0;
                end
            end
        end
    end

    assign wait_n = !wait_hold;
    assign enabled = step_enabled;

endmodule
