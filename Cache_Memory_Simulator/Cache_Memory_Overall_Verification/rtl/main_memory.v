
module main_memory (
    input wire clk,
    input wire rst_n,

    // Memory Control Interface
    input wire mem_req,
    input wire mem_we,
    input wire [7:0] mem_addr,
    input wire [7:0] mem_wdata,

    // Memory Output
    output reg [15:0] mem_rdata,
    output reg mem_ready
);

    // Main Memory: 256 bytes
    reg [7:0] memory [0:255];

    // FSM States
    localparam IDLE = 2'b00;
    localparam WAIT = 2'b01;
    localparam HOLD = 2'b10;

    reg [1:0] state;

    // Internal Registers
    reg [7:0] saved_addr;
    reg [7:0] saved_wdata;
    reg saved_we;
    reg [1:0] delay_count;

    integer i;

    // Initialize memory with test data
    initial begin
        for (i = 0; i < 256; i = i + 1)
            memory[i] = i;
    end

    // Main Memory Controller
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mem_rdata <= 16'b0;
            mem_ready <= 1'b0;
            saved_addr <= 8'b0;
            saved_wdata <= 8'b0;
            saved_we <= 1'b0;
            delay_count <= 2'b0;
        end
        else begin
            case (state)

                IDLE: begin
                    mem_ready <= 1'b0;

                    if (mem_req) begin
                        saved_addr <= mem_addr;
                        saved_wdata <= mem_wdata;
                        saved_we <= mem_we;
                        delay_count <= 2'd2;
                        state <= WAIT;
                    end
                end

                WAIT: begin
                    if (delay_count > 0) begin
                        delay_count <= delay_count - 1'b1;
                    end
                    else begin

                        if (saved_we) begin
                            // Write one byte
                            memory[saved_addr] <= saved_wdata;
                        end
                        else begin
                            // Read two consecutive bytes
                            mem_rdata[7:0] <=
                                memory[{saved_addr[7:1], 1'b0}];

                            mem_rdata[15:8] <=
                                memory[{saved_addr[7:1], 1'b0} + 8'd1];
                        end

                        mem_ready <= 1'b1;
                        state <= HOLD;
                    end
                end

                HOLD: begin
                    mem_ready <= 1'b0;

                    if (!mem_req)
                        state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    mem_ready <= 1'b0;
                end

            endcase
        end
    end

endmodule
