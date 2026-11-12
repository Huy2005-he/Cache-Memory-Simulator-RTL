
`timescale 1ns/1ps

module cache_storage (
    input wire clk,
    input wire reset,

    // Write interface
    input wire write_en,
    input wire [1:0] write_index,
    input wire [4:0] write_tag,
    input wire [7:0] write_data0,
    input wire [7:0] write_data1,

    // Read interface
    input wire [1:0] read_index,
    output reg [4:0] read_tag,
    output reg [7:0] read_data0,
    output reg [7:0] read_data1,
    output reg read_valid
);

    // 4 Cache Lines
    reg valid [0:3];
    reg [4:0] tag [0:3];
    reg [7:0] data0 [0:3];
    reg [7:0] data1 [0:3];

    integer i;

    // Reset and Write
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 4; i = i + 1)
                valid[i] <= 1'b0;
        end
        else if (write_en) begin
            valid[write_index] <= 1'b1;
            tag[write_index] <= write_tag;
            data0[write_index] <= write_data0;
            data1[write_index] <= write_data1;
        end
    end

    // Read Cache Line
    always @(*) begin
        read_valid = valid[read_index];
        read_tag = tag[read_index];
        read_data0 = data0[read_index];
        read_data1 = data1[read_index];
    end

endmodule

