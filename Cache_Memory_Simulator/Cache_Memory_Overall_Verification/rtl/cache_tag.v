
module cache_tag (
    input wire clk,
    input wire rst_n,

    // Address Index
    input wire [1:0] tag_index,

    // Write Interface
    input wire tag_we,
    input wire [4:0] tag_in,
    input wire valid_in,

    // Read Interface
    output wire [4:0] tag_out,
    output wire valid_out
);

    // 4 Cache Lines
    reg [4:0] tag_array [0:3];
    reg valid_array [0:3];

    // Write Tag and Valid
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 4; i = i + 1) begin
                tag_array[i] <= 5'b00000;
                valid_array[i] <= 1'b0;
            end
        end
        else if (tag_we) begin
            tag_array[tag_index] <= tag_in;
            valid_array[tag_index] <= valid_in;
        end
    end

    // Read Selected Cache Line
    assign tag_out = tag_array[tag_index];
    assign valid_out = valid_array[tag_index];

endmodule
