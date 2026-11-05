
module cache_data (
    input wire clk,
    input wire rst_n,

    // Address Interface
    input wire [1:0] data_index,
    input wire data_offset,

    // Single Word Write
    input wire word_we,
    input wire [7:0] word_wdata,

    // Full Block Write
    input wire block_we,
    input wire [15:0] block_wdata,

    // Read Output
    output wire [7:0] word_rdata
);

    // 4 Cache Lines, 2 Words per Line
    reg [7:0] data_array [0:7];

    integer i;

    // Write Operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                data_array[i] <= 8'b0;
            end
        end
        else if (block_we) begin
            data_array[{data_index, 1'b0}] <= block_wdata[7:0];
            data_array[{data_index, 1'b1}] <= block_wdata[15:8];
        end
        else if (word_we) begin
            data_array[{data_index, data_offset}] <= word_wdata;
        end
    end

    // Read Selected Word
    assign word_rdata =
        data_array[{data_index, data_offset}];

endmodule
