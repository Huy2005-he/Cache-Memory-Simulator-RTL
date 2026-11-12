module cache_data_array (
    input  wire       clk,
    input  wire       rst,

    input  wire [1:0] data_index,      
    input  wire [7:0] cache_data_in,   
    input  wire       data_we,        

    output wire [7:0] cache_data_out
);

    reg [7:0] data_mem [0:3];
    integer i;

    
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 4; i = i + 1)
                data_mem[i] <= 8'd0;
        end
        else if (data_we) begin
            data_mem[data_index] <= cache_data_in;
        end
    end

    assign cache_data_out = data_mem[data_index];

endmodule

