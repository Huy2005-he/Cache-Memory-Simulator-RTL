
module cache_top (
    // Clock and Reset
    input wire clk,
    input wire rst_n,

    // CPU Interface
    input wire cpu_req,
    input wire cpu_we,
    input wire [7:0] cpu_addr,
    input wire [7:0] cpu_wdata,

    output wire [7:0] cpu_rdata,
    output wire cpu_ready,

    // Cache Status
    output wire cache_hit,
    output wire cache_miss
);

    // =====================================
    // 1. ADDRESS DECODING
    // =====================================

    wire [4:0] address_tag;
    wire [1:0] address_index;
    wire address_offset;

    assign address_tag = cpu_addr[7:3];
    assign address_index = cpu_addr[2:1];
    assign address_offset = cpu_addr[0];


    // =====================================
    // 2. INTERNAL SIGNALS
    // =====================================

    // Tag Array
    wire tag_we;
    wire [4:0] tag_in;
    wire [4:0] tag_out;
    wire valid_in;
    wire valid_out;

    // Data Array
    wire word_we;
    wire block_we;
    wire [7:0] word_wdata;
    wire [7:0] word_rdata;
    wire [15:0] block_wdata;

    // Main Memory
    wire mem_req;
    wire mem_we;
    wire [7:0] mem_addr;
    wire [7:0] mem_wdata;
    wire [15:0] mem_rdata;
    wire mem_ready;


    // =====================================
    // 3. CACHE CONTROLLER
    // =====================================

    cache_controller controller_inst (

        .clk(clk),
        .rst_n(rst_n),

        .cpu_req(cpu_req),
        .cpu_we(cpu_we),
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),

        .cpu_rdata(cpu_rdata),
        .cpu_ready(cpu_ready),
        .cache_hit(cache_hit),
        .cache_miss(cache_miss),

        .address_tag(address_tag),
        .address_index(address_index),
        .address_offset(address_offset),

        .tag_out(tag_out),
        .valid_out(valid_out),

        .tag_we(tag_we),
        .tag_in(tag_in),
        .valid_in(valid_in),

        .word_rdata(word_rdata),
        .word_we(word_we),
        .block_we(block_we),
        .word_wdata(word_wdata),
        .block_wdata(block_wdata),

        .mem_req(mem_req),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .mem_ready(mem_ready)
    );


    // =====================================
    // 4. CACHE TAG ARRAY
    // =====================================

    cache_tag tag_inst (

        .clk(clk),
        .rst_n(rst_n),

        .tag_index(address_index),

        .tag_we(tag_we),
        .tag_in(tag_in),
        .valid_in(valid_in),

        .tag_out(tag_out),
        .valid_out(valid_out)
    );


    // =====================================
    // 5. CACHE DATA ARRAY
    // =====================================

    cache_data data_inst (

        .clk(clk),
        .rst_n(rst_n),

        .data_index(address_index),
        .data_offset(address_offset),

        .word_we(word_we),
        .word_wdata(word_wdata),

        .block_we(block_we),
        .block_wdata(block_wdata),

        .word_rdata(word_rdata)
    );


    // =====================================
    // 6. MAIN MEMORY
    // =====================================

    main_memory memory_inst (

        .clk(clk),
        .rst_n(rst_n),

        .mem_req(mem_req),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),

        .mem_rdata(mem_rdata),
        .mem_ready(mem_ready)
    );

endmodule
