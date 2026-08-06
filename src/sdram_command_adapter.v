module sdram_command_adapter
(
    input clk,
    input reset_n,
    input rfsh_n,
    input m1_n,
    input merq_n,
    input iorq_n,
    input rd_n,
    input wr_n,

    input cmd_en,
    input [2:0] cmd,
    input [20:0] cmd_addr,
    input [3:0] cmd_dqm,
    input [31:0] cmd_data,
    output [31:0] read_data,
    output init_done,
    output cmd_ack,

    output rd,
    output wr,
    output refresh,
    output [22:0] addr,
    output [15:0] din,
    output [1:0] wdm,
    input [31:0] dout32,
    input data_ready,
    input busy,
    input enabled
);

    localparam [2:0] CMD_READ = 3'b101;
    localparam [2:0] CMD_WRITE = 3'b100;
    reg rd_reg = 1'b0;
    reg wr_reg = 1'b0;
    reg refresh_reg = 1'b0;
    reg [22:0] addr_reg = 23'd0;
    reg [15:0] din_reg = 16'd0;
    reg [1:0] wdm_reg = 2'b11;
    reg [31:0] read_data_reg = 32'd0;
    reg cmd_ack_reg = 1'b0;
    reg command_pending = 1'b0;
    reg pending_read = 1'b0;
    reg command_saw_busy = 1'b0;
    reg refresh_pending = 1'b0;
    reg refresh_saw_busy = 1'b0;
    reg refresh_request = 1'b0;
    reg refresh_seen = 1'b0;
    reg request_queued = 1'b0;
    reg [2:0] request_cmd = CMD_READ;
    reg [20:0] request_addr = 21'd0;
    reg [31:0] request_data = 32'd0;
    reg [1:0] request_lane = 2'd0;

    reg [1:0] lane;

    // A Z80 refresh request is remembered when RFSH is observed, but the
    // physical SDRAM refresh is launched only between complete CPU bus cycles.
    wire cpu_bus_idle = rfsh_n && m1_n && merq_n && iorq_n &&
                        rd_n && wr_n;

    always @(*) begin
        case (cmd_dqm)
            4'b1110: lane = 2'd0;
            4'b1101: lane = 2'd1;
            4'b1011: lane = 2'd2;
            default: lane = 2'd3;
        endcase
    end

    always_ff @(posedge clk or negedge reset_n)
    begin
        if (!reset_n) begin
            rd_reg <= 1'b0;
            wr_reg <= 1'b0;
            refresh_reg <= 1'b0;
            addr_reg <= 23'd0;
            din_reg <= 16'd0;
            wdm_reg <= 2'b11;
            read_data_reg <= 32'd0;
            cmd_ack_reg <= 1'b0;
            command_pending <= 1'b0;
            pending_read <= 1'b0;
            command_saw_busy <= 1'b0;
            refresh_pending <= 1'b0;
            refresh_saw_busy <= 1'b0;
            refresh_request <= 1'b0;
            refresh_seen <= 1'b0;
            request_queued <= 1'b0;
            request_cmd <= CMD_READ;
            request_addr <= 21'd0;
            request_data <= 32'd0;
            request_lane <= 2'd0;
        end else begin
            rd_reg <= 1'b0;
            wr_reg <= 1'b0;
            refresh_reg <= 1'b0;
            cmd_ack_reg <= 1'b0;

            if (cmd_en && !request_queued && !command_pending) begin
                request_queued <= 1'b1;
                request_cmd <= cmd;
                request_addr <= cmd_addr;
                request_data <= cmd_data;
                request_lane <= lane;
            end

            if (rfsh_n) begin
                refresh_seen <= 1'b0;
            end else if (!refresh_seen) begin
                refresh_request <= 1'b1;
                refresh_seen <= 1'b1;
            end

            if (command_pending) begin
                if (busy)
                    command_saw_busy <= 1'b1;

                if (pending_read && data_ready) begin
                    read_data_reg <= dout32;
                    command_pending <= 1'b0;
                    cmd_ack_reg <= 1'b1;
                end else if (!pending_read && command_saw_busy && !busy) begin
                    command_pending <= 1'b0;
                    cmd_ack_reg <= 1'b1;
                end
            end else if (refresh_pending) begin
                if (busy)
                    refresh_saw_busy <= 1'b1;

                if (refresh_saw_busy && !busy) begin
                    refresh_pending <= 1'b0;
                    refresh_saw_busy <= 1'b0;
                end
            end else if (request_queued && !busy) begin
                // The legacy address is a 32-bit word address. The new
                // controller takes a 16-bit-halfword address; lane[1]
                // selects the low or high half of the 32-bit SDRAM word.
                addr_reg <= {1'b0, request_addr, request_lane[1]};
                din_reg <= request_lane[1] ? request_data[31:16] : request_data[15:0];
                wdm_reg <= request_lane[0] ? 2'b01 : 2'b10;
                pending_read <= (request_cmd == CMD_READ);
                command_pending <= 1'b1;
                command_saw_busy <= 1'b0;
                rd_reg <= (request_cmd == CMD_READ);
                wr_reg <= (request_cmd == CMD_WRITE);
                request_queued <= 1'b0;
            end else if (refresh_request && enabled && !busy &&
                         cpu_bus_idle && !cmd_en) begin
                // CPU reads/writes have priority. In particular, do not start
                // refresh on the same edge that captures a new command.
                refresh_reg <= 1'b1;
                refresh_pending <= 1'b1;
                refresh_saw_busy <= 1'b0;
                refresh_request <= 1'b0;
            end
        end
    end

    assign rd = rd_reg;
    assign wr = wr_reg;
    assign refresh = refresh_reg;
    assign addr = addr_reg;
    assign din = din_reg;
    assign wdm = wdm_reg;
    assign read_data = read_data_reg;
    assign init_done = enabled;
    assign cmd_ack = cmd_ack_reg;

endmodule
