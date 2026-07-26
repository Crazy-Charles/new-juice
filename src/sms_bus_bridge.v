module sms_bus_bridge
(
    input clk_main,
    input reset_main_n,
    input cpu_clk_high,
    input vdp_selected,
    input psg_selected,
    input rd_n,
    input wr_n,
    input [7:0] addr,
    input [7:0] data_in,

    input clk_sms,
    input reset_sms_n,
    input ce_vdp,
    output reg vdp_rd_n,
    output reg vdp_wr_n,
    output reg psg_wr_n,
    output reg [7:0] peripheral_addr,
    output reg [7:0] peripheral_data,
    input [7:0] vdp_data_in,

    output [7:0] read_data,
    output read_data_en,
    output wait_n,
    output reg vdp_activated
);

    localparam [1:0] REQ_VDP_READ  = 2'd0;
    localparam [1:0] REQ_VDP_WRITE = 2'd1;
    localparam [1:0] REQ_PSG_WRITE = 2'd2;

    // Main-domain request mailbox. Its payload remains unchanged until the
    // synchronized response toggle returns from the SMS domain.
    reg request_toggle = 1'b0;
    reg request_pending = 1'b0;
    reg access_seen = 1'b0;
    reg [1:0] request_kind = REQ_VDP_READ;
    reg [7:0] request_addr = 8'd0;
    reg [7:0] request_data = 8'd0;

    reg response_toggle = 1'b0;
    reg [7:0] response_mailbox = 8'd0;
    (* syn_preserve = 1, ASYNC_REG = "TRUE" *)
    reg [1:0] response_sync = 2'b00;
    reg response_seen = 1'b0;
    reg [7:0] read_data_reg = 8'd0;
    reg read_ready = 1'b0;

    wire vdp_read_cycle = vdp_selected && !rd_n;
    wire bus_cycle_active =
        vdp_read_cycle ||
        (vdp_selected && !wr_n) ||
        (psg_selected && !wr_n);

    always_ff @(posedge clk_main or negedge reset_main_n)
    begin
        if (!reset_main_n) begin
            request_toggle <= 1'b0;
            request_pending <= 1'b0;
            access_seen <= 1'b0;
            request_kind <= REQ_VDP_READ;
            request_addr <= 8'd0;
            request_data <= 8'd0;
            response_sync <= 2'b00;
            response_seen <= 1'b0;
            read_data_reg <= 8'd0;
            read_ready <= 1'b0;
            vdp_activated <= 1'b0;
        end else begin
            response_sync <= {response_sync[0], response_toggle};

            if (!bus_cycle_active) begin
                access_seen <= 1'b0;
                read_ready <= 1'b0;
            end

            if (response_sync[1] != response_seen) begin
                response_seen <= response_sync[1];
                request_pending <= 1'b0;
                if (request_kind == REQ_VDP_READ) begin
                    read_data_reg <= response_mailbox;
                    read_ready <= 1'b1;
                end
            end

            if (!access_seen && !request_pending) begin
                if (vdp_read_cycle) begin
                    request_kind <= REQ_VDP_READ;
                    request_addr <= addr;
                    request_data <= data_in;
                    request_toggle <= ~request_toggle;
                    request_pending <= 1'b1;
                    access_seen <= 1'b1;
                    read_ready <= 1'b0;
                end else if (cpu_clk_high && vdp_selected && !wr_n) begin
                    request_kind <= REQ_VDP_WRITE;
                    request_addr <= addr;
                    request_data <= data_in;
                    request_toggle <= ~request_toggle;
                    request_pending <= 1'b1;
                    access_seen <= 1'b1;
                    vdp_activated <= 1'b1;
                end else if (cpu_clk_high && psg_selected && !wr_n) begin
                    request_kind <= REQ_PSG_WRITE;
                    request_addr <= addr;
                    request_data <= data_in;
                    request_toggle <= ~request_toggle;
                    request_pending <= 1'b1;
                    access_seen <= 1'b1;
                end
            end
        end
    end

    assign read_data = read_data_reg;
    assign read_data_en = vdp_read_cycle && read_ready;
    // Franky never owns the system WAIT line. Read data is enabled as soon as
    // the synchronized response arrives within the unextended MSX I/O cycle.
    assign wait_n = 1'b1;

    // SMS-domain request synchronizer and peripheral-cycle sequencer.
    (* syn_preserve = 1, ASYNC_REG = "TRUE" *)
    reg [1:0] request_sync = 2'b00;
    reg request_seen = 1'b0;
    reg [1:0] sms_request_kind = REQ_VDP_READ;
    reg [1:0] sms_state = 2'd0;

    always_ff @(posedge clk_sms or negedge reset_sms_n)
    begin
        if (!reset_sms_n) begin
            request_sync <= 2'b00;
            request_seen <= 1'b0;
            sms_request_kind <= REQ_VDP_READ;
            sms_state <= 2'd0;
            vdp_rd_n <= 1'b1;
            vdp_wr_n <= 1'b1;
            psg_wr_n <= 1'b1;
            peripheral_addr <= 8'd0;
            peripheral_data <= 8'd0;
            response_toggle <= 1'b0;
            response_mailbox <= 8'd0;
        end else begin
            request_sync <= {request_sync[0], request_toggle};

            case (sms_state)
                2'd0: begin
                    vdp_rd_n <= 1'b1;
                    vdp_wr_n <= 1'b1;
                    psg_wr_n <= 1'b1;
                    if (request_sync[1] != request_seen) begin
                        request_seen <= request_sync[1];
                        sms_request_kind <= request_kind;
                        peripheral_addr <= request_addr;
                        peripheral_data <= request_data;
                        case (request_kind)
                            REQ_VDP_READ:  vdp_rd_n <= 1'b0;
                            REQ_VDP_WRITE: vdp_wr_n <= 1'b0;
                            REQ_PSG_WRITE: psg_wr_n <= 1'b0;
                            default: begin
                            end
                        endcase
                        sms_state <= 2'd1;
                    end
                end

                2'd1: begin
                    if (sms_request_kind == REQ_PSG_WRITE || ce_vdp) begin
                        vdp_rd_n <= 1'b1;
                        vdp_wr_n <= 1'b1;
                        psg_wr_n <= 1'b1;
                        sms_state <= 2'd2;
                    end
                end

                default: begin
                    if (sms_request_kind == REQ_VDP_READ)
                        response_mailbox <= vdp_data_in;
                    response_toggle <= ~response_toggle;
                    sms_state <= 2'd0;
                end
            endcase
        end
    end

endmodule
