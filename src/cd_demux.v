module cd_demux
(
    input [7:0] data_out,
    input data_out_en,
    input wait_in_n,
    input rd_n,
    input sltsl_n,
    input mapper_port_read,
    inout [7:0] cd,
    output busdir_n,
    output datadir,
    output wait_n
);

    assign cd = data_out_en ? data_out :
                8'bzzzzzzzz;

    assign busdir_n = mapper_port_read ? 1'b0 : 1'b1;
    assign datadir = ((!rd_n && !sltsl_n) || mapper_port_read) ? 1'b0 : 1'b1;
    assign wait_n =  wait_in_n;

endmodule
