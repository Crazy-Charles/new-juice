module cd_demux
(
    input startup_done,
    input ws2812_out,
    input [7:0] data_out,
    input data_out_en,
    inout [7:0] cd,
    output busdir_n,
    output datadir,
    output wait_n
);

    wire startup_active = !startup_done;

    assign cd = startup_active ? {8{ws2812_out}} :
                data_out_en ? data_out :
                8'bzzzzzzzz;

    assign busdir_n = data_out_en ? 1'b0 : 1'b1;
    assign datadir = data_out_en ? 1'b0 : 1'b1;
    assign wait_n = startup_done;

endmodule
