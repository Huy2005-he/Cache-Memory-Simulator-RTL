
module cache_controller (
    // Clock and Reset
    input wire clk,
    input wire rst_n,

    // CPU Interface
    input wire cpu_req,
    input wire cpu_we,
    input wire [7:0] cpu_addr,
    input wire [7:0] cpu_wdata,

    output reg [7:0] cpu_rdata,
    output reg cpu_ready,
    output reg cache_hit,
    output reg cache_miss,

    // Address Fields
    input wire [4:0] address_tag,
    input wire [1:0] address_index,
    input wire address_offset,

    // Tag Array Interface
    input wire [4:0] tag_out,
    input wire valid_out,
    output reg tag_we,
    output reg [4:0] tag_in,
    output reg valid_in,

    // Data Array Interface
    input wire [7:0] word_rdata,
    output reg word_we,
    output reg block_we,
    output reg [7:0] word_wdata,
    output reg [15:0] block_wdata,

    // Main Memory Interface
    output reg mem_req,
    output reg mem_we,
    output reg [7:0] mem_addr,
    output reg [7:0] mem_wdata,
    input wire [15:0] mem_rdata,
    input wire mem_ready
);

    // =================================
    // 1. FSM STATE DEFINITION
    // =================================

    localparam IDLE      = 3'b000;
    localparam CHECK     = 3'b001;
    localparam MISS      = 3'b010;
    localparam REFILL    = 3'b011;
    localparam WRITE_WAIT = 3'b100;
    localparam DONE      = 3'b101;

    reg [2:0] state;

    // =================================
    // 2. MAIN CONTROLLER
    // =================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state <= IDLE;

            cpu_rdata <= 8'b0;
            cpu_ready <= 1'b0;
            cache_hit <= 1'b0;
            cache_miss <= 1'b0;

            tag_we <= 1'b0;
            tag_in <= 5'b0;
            valid_in <= 1'b0;

            word_we <= 1'b0;
            block_we <= 1'b0;
            word_wdata <= 8'b0;
            block_wdata <= 16'b0;

            mem_req <= 1'b0;
            mem_we <= 1'b0;
            mem_addr <= 8'b0;
            mem_wdata <= 8'b0;

        end

        else begin

            // Default outputs
            cpu_ready <= 1'b0;
            cache_hit <= 1'b0;
            cache_miss <= 1'b0;

            tag_we <= 1'b0;
            valid_in <= 1'b0;

            word_we <= 1'b0;
            block_we <= 1'b0;

            mem_req <= 1'b0;

            case (state)

                // =====================
                // IDLE
                // =====================

                IDLE: begin

                    if (cpu_req)
                        state <= CHECK;

                end

                // =====================
                // CHECK CACHE
                // =====================

                CHECK: begin

                    if (valid_out && (tag_out == address_tag)) begin

                        // CACHE HIT
                        cache_hit <= 1'b1;

                        if (cpu_we) begin

                            // Write hit: update Cache
                            word_we <= 1'b1;
                            word_wdata <= cpu_wdata;

                            state <= WRITE_WAIT;

                        end

                        else begin

                            // Read hit
                            cpu_rdata <= word_rdata;
                            cpu_ready <= 1'b1;

                            state <= DONE;

                        end

                    end

                    else begin

                        // CACHE MISS
                        cache_miss <= 1'b1;

                        if (cpu_we) begin

                            // Write miss: write Main Memory
                            state <= WRITE_WAIT;

                        end

                        else begin

                            // Read miss
                            state <= MISS;

                        end

                    end

                end

                // =====================
                // MEMORY READ REQUEST
                // =====================

                MISS: begin

                    mem_req <= 1'b1;
                    mem_we <= 1'b0;

                    // Align address to block boundary
                    mem_addr <= {cpu_addr[7:1], 1'b0};

                    if (mem_ready) begin

                        mem_req <= 1'b0;
                        state <= REFILL;

                    end

                end

                // =====================
                // CACHE REFILL
                // =====================

                REFILL: begin

                    // Write memory block into Cache
                    block_we <= 1'b1;
                    block_wdata <= mem_rdata;

                    // Update Tag and Valid
                    tag_we <= 1'b1;
                    tag_in <= address_tag;
                    valid_in <= 1'b1;

                    // Return selected word to CPU
                    if (address_offset)
                        cpu_rdata <= mem_rdata[15:8];
                    else
                        cpu_rdata <= mem_rdata[7:0];

                    cpu_ready <= 1'b1;

                    state <= DONE;

                end

                // =====================
                // MEMORY WRITE
                // =====================

                WRITE_WAIT: begin

                    mem_req <= 1'b1;
                    mem_we <= 1'b1;

                    mem_addr <= cpu_addr;
                    mem_wdata <= cpu_wdata;

                    if (mem_ready) begin

                        mem_req <= 1'b0;
                        cpu_ready <= 1'b1;

                        state <= DONE;

                    end

                end

                // =====================
                // TRANSACTION COMPLETE
                // =====================

                DONE: begin

                    if (!cpu_req)
                        state <= IDLE;

                end

                // =====================
                // DEFAULT
                // =====================

                default: begin

                    state <= IDLE;

                end

            endcase

        end

    end

endmodule
