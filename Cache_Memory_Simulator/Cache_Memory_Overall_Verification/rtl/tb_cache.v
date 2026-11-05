`timescale 1ns/1ps

// ============================================================
// CACHE MEMORY SIMULATOR RTL - OVERALL INTEGRATION TESTBENCH
//
// Targets the latest top-level interface:
//   rst_n, cpu_req, cpu_we, cpu_addr[7:0], cpu_wdata[7:0]
//   cpu_rdata[7:0], cpu_ready, cache_hit, cache_miss
//
// Address mapping in the supplied RTL:
//   TAG    = cpu_addr[7:3]  (5 bits)
//   INDEX  = cpu_addr[2:1]  (2 bits: 4 sets)
//   OFFSET = cpu_addr[0]    (1 bit: 2 bytes per block)
//
// Main memory model:
//   memory[i] = i at initialization
//   read miss refills 2 consecutive bytes
//
// Write policy implemented by supplied cache_controller.v:
//   Write-through + No-write-allocate
//
// IMPORTANT:
//   Hold cpu_req high and keep address/data stable until cpu_ready.
//   cache_hit/cache_miss are short status pulses during CHECK;
//   this testbench latches them until cpu_ready is seen.
// ============================================================

module tb_cache;

    parameter integer MAX_WAIT_CYCLES = 100;

    // --------------------------------------------------------
    // 1. CPU-side stimulus
    // --------------------------------------------------------
    reg         clk;
    reg         rst_n;
    reg         cpu_req;
    reg         cpu_we;
    reg  [7:0]  cpu_addr;
    reg  [7:0]  cpu_wdata;

    // --------------------------------------------------------
    // 2. DUT outputs
    // --------------------------------------------------------
    wire [7:0]  cpu_rdata;
    wire        cpu_ready;
    wire        cache_hit;
    wire        cache_miss;

    // --------------------------------------------------------
    // 3. Counters and reference memory model
    // --------------------------------------------------------
    integer errors;
    integer total_accesses;
    integer hit_count;
    integer miss_count;
    integer i;
    real hit_rate;

    reg [7:0] expected_mem [0:255];

    // FSM coverage:
    // state 000 IDLE, 001 CHECK, 010 MISS,
    //       011 REFILL, 100 WRITE_WAIT, 101 DONE
    reg [5:0] fsm_seen;

    // --------------------------------------------------------
    // 4. Design Under Test
    // --------------------------------------------------------
    cache_top dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .cpu_req   (cpu_req),
        .cpu_we    (cpu_we),
        .cpu_addr  (cpu_addr),
        .cpu_wdata (cpu_wdata),
        .cpu_rdata (cpu_rdata),
        .cpu_ready (cpu_ready),
        .cache_hit (cache_hit),
        .cache_miss(cache_miss)
    );

    // --------------------------------------------------------
    // 5. Clock: 10 ns period
    // --------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // --------------------------------------------------------
    // 6. Observe FSM states in the supplied controller
    // --------------------------------------------------------
    always @(posedge clk) begin
        #1;
        if (rst_n === 1'b1) begin
            case (dut.controller_inst.state)
                3'b000: fsm_seen[0] = 1'b1; // IDLE
                3'b001: fsm_seen[1] = 1'b1; // CHECK
                3'b010: fsm_seen[2] = 1'b1; // MISS
                3'b011: fsm_seen[3] = 1'b1; // REFILL
                3'b100: fsm_seen[4] = 1'b1; // WRITE_WAIT
                3'b101: fsm_seen[5] = 1'b1; // DONE
                default: ;
            endcase
        end
    end

    // --------------------------------------------------------
    // 7. Reset task
    // rst_n is active-low in the supplied RTL.
    // --------------------------------------------------------
    task apply_reset;
    begin
        @(negedge clk);
        rst_n    = 1'b0;
        cpu_req  = 1'b0;
        cpu_we   = 1'b0;
        cpu_addr = 8'h00;
        cpu_wdata= 8'h00;

        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        if ((cpu_ready !== 1'b0) ||
            (cache_hit !== 1'b0) ||
            (cache_miss !== 1'b0)) begin
            errors = errors + 1;
            $display("[%0t] FAIL RESET: output status not cleared", $time);
        end
        else begin
            $display("[%0t] PASS RESET: controller outputs cleared", $time);
        end
    end
    endtask

    // --------------------------------------------------------
    // 8. Common read/write transaction task
    //
    // do_write = 0: READ
    // do_write = 1: WRITE
    //
    // expected_hit = 1 means Hit; 0 means Miss.
    // check_read_data = 1 enables cpu_rdata comparison.
    //
    // The status flags are latched because cache_miss is asserted
    // in CHECK and is normally low again before cpu_ready.
    // --------------------------------------------------------
    task check_transaction;
        input        do_write;
        input [7:0]  address;
        input [7:0]  write_data;
        input        expected_hit;
        input        check_read_data;
        input [7:0]  expected_read_data;

        integer wait_cycles;
        reg observed_hit;
        reg observed_miss;
        reg completed;
    begin
        total_accesses = total_accesses + 1;
        wait_cycles    = 0;
        observed_hit   = 1'b0;
        observed_miss  = 1'b0;
        completed      = 1'b0;

        // Drive request on the falling edge.
        @(negedge clk);
        cpu_addr  = address;
        cpu_wdata = write_data;
        cpu_we    = do_write;
        cpu_req   = 1'b1;

        // Hold request until cpu_ready or timeout.
        while ((wait_cycles < MAX_WAIT_CYCLES) &&
               (completed == 1'b0)) begin
            @(posedge clk);
            #1;
            wait_cycles = wait_cycles + 1;

            if (cache_hit === 1'b1)
                observed_hit = 1'b1;

            if (cache_miss === 1'b1)
                observed_miss = 1'b1;

            if ((cache_hit === 1'b1) &&
                (cache_miss === 1'b1)) begin
                errors = errors + 1;
                $display("[%0t] FAIL: Hit and Miss asserted together", $time);
            end

            if (cpu_ready === 1'b1)
                completed = 1'b1;
        end

        if (completed == 1'b0) begin
            errors = errors + 1;
            $display("[%0t] FAIL TIMEOUT: %s address=0x%02h",
                     $time, do_write ? "WRITE" : "READ", address);
        end
        else begin
            // Count observed status, then compare with expectation.
            if ((observed_hit == 1'b1) && (observed_miss == 1'b0))
                hit_count = hit_count + 1;
            else if ((observed_hit == 1'b0) && (observed_miss == 1'b1))
                miss_count = miss_count + 1;

            if ((observed_hit !== expected_hit) ||
                (observed_miss !== ~expected_hit)) begin
                errors = errors + 1;
                $display(
                    "[%0t] FAIL STATUS: %s addr=0x%02h expected hit=%b miss=%b got hit=%b miss=%b",
                    $time, do_write ? "WRITE" : "READ",
                    address, expected_hit, ~expected_hit,
                    observed_hit, observed_miss
                );
            end
            else begin
                $display(
                    "[%0t] PASS STATUS: %s addr=0x%02h hit=%b miss=%b",
                    $time, do_write ? "WRITE" : "READ",
                    address, observed_hit, observed_miss
                );
            end

            if ((do_write == 1'b0) && (check_read_data == 1'b1)) begin
                if (cpu_rdata !== expected_read_data) begin
                    errors = errors + 1;
                    $display(
                        "[%0t] FAIL DATA: addr=0x%02h expected=0x%02h actual=0x%02h",
                        $time, address, expected_read_data, cpu_rdata
                    );
                end
                else begin
                    $display(
                        "[%0t] PASS DATA: addr=0x%02h data=0x%02h",
                        $time, address, cpu_rdata
                    );
                end
            end

            // The supplied controller implements write-through:
            // a completed write updates Main Memory on both hit/miss.
            if (do_write == 1'b1)
                expected_mem[address] = write_data;
        end

        // Release request; controller leaves DONE when cpu_req is low.
        @(negedge clk);
        cpu_req = 1'b0;
        cpu_we  = 1'b0;

        @(posedge clk);
        #1;
    end
    endtask

    // --------------------------------------------------------
    // 9. Main integration test sequence
    // --------------------------------------------------------
    initial begin
        // Initial signal values
        rst_n     = 1'b0;
        cpu_req   = 1'b0;
        cpu_we    = 1'b0;
        cpu_addr  = 8'h00;
        cpu_wdata = 8'h00;

        errors         = 0;
        total_accesses = 0;
        hit_count      = 0;
        miss_count     = 0;
        fsm_seen       = 6'b000000;

        // Match the supplied Main Memory initialization: memory[i] = i.
        for (i = 0; i < 256; i = i + 1)
            expected_mem[i] = i[7:0];

        $display("==================================================");
        $display("CACHE MEMORY SIMULATOR - OVERALL INTEGRATION TEST");
        $display("Mapping: Direct-mapped");
        $display("Geometry: 4 sets x 2 bytes/block");
        $display("Address: TAG[7:3], INDEX[2:1], OFFSET[0]");
        $display("Write policy: Write-through + No-write-allocate");
        $display("==================================================");

        apply_reset();

        // TC01: Cold miss, then repeated read hit.
        check_transaction(1'b0, 8'h00, 8'h00, 1'b0, 1'b1,
                          expected_mem[8'h00]);
        check_transaction(1'b0, 8'h00, 8'h00, 1'b1, 1'b1,
                          expected_mem[8'h00]);

        // TC02: Other byte in the same 2-byte block must hit.
        check_transaction(1'b0, 8'h01, 8'h00, 1'b1, 1'b1,
                          expected_mem[8'h01]);

        // TC03: Conflict miss in the same set (0x00 and 0x08).
        check_transaction(1'b0, 8'h08, 8'h00, 1'b0, 1'b1,
                          expected_mem[8'h08]);
        check_transaction(1'b0, 8'h00, 8'h00, 1'b0, 1'b1,
                          expected_mem[8'h00]);

        // TC04: Fill the remaining sets and check each block's second byte.
        check_transaction(1'b0, 8'h02, 8'h00, 1'b0, 1'b1,
                          expected_mem[8'h02]);
        check_transaction(1'b0, 8'h03, 8'h00, 1'b1, 1'b1,
                          expected_mem[8'h03]);

        check_transaction(1'b0, 8'h04, 8'h00, 1'b0, 1'b1,
                          expected_mem[8'h04]);
        check_transaction(1'b0, 8'h05, 8'h00, 1'b1, 1'b1,
                          expected_mem[8'h05]);

        check_transaction(1'b0, 8'h06, 8'h00, 1'b0, 1'b1,
                          expected_mem[8'h06]);
        check_transaction(1'b0, 8'h07, 8'h00, 1'b1, 1'b1,
                          expected_mem[8'h07]);

        // TC05: Verify independent set remains resident.
        check_transaction(1'b0, 8'h02, 8'h00, 1'b1, 1'b1,
                          expected_mem[8'h02]);

        // TC06: Write hit (write-through updates Cache and Main Memory).
        check_transaction(1'b1, 8'h02, 8'hA6, 1'b1, 1'b0, 8'h00);
        check_transaction(1'b0, 8'h02, 8'h00, 1'b1, 1'b1,
                          expected_mem[8'h02]);
        check_transaction(1'b0, 8'h03, 8'h00, 1'b1, 1'b1,
                          expected_mem[8'h03]);

        // TC07: Replace set 1, then ensure write-through value survives refill.
        check_transaction(1'b0, 8'h0A, 8'h00, 1'b0, 1'b1,
                          expected_mem[8'h0A]);
        check_transaction(1'b0, 8'h02, 8'h00, 1'b0, 1'b1,
                          expected_mem[8'h02]);

        // TC08: Write miss is no-write-allocate; next read should still Miss.
        check_transaction(1'b1, 8'h12, 8'h5C, 1'b0, 1'b0, 8'h00);
        check_transaction(1'b0, 8'h12, 8'h00, 1'b0, 1'b1,
                          expected_mem[8'h12]);
        check_transaction(1'b0, 8'h12, 8'h00, 1'b1, 1'b1,
                          expected_mem[8'h12]);

        // TC09: Other sets were not disturbed by set-1 replacements.
        check_transaction(1'b0, 8'h00, 8'h00, 1'b1, 1'b1,
                          expected_mem[8'h00]);
        check_transaction(1'b0, 8'h04, 8'h00, 1'b1, 1'b1,
                          expected_mem[8'h04]);
        check_transaction(1'b0, 8'h06, 8'h00, 1'b1, 1'b1,
                          expected_mem[8'h06]);

        // ----------------------------------------------------
        // 10. Final summary and FSM coverage
        // ----------------------------------------------------
        if (fsm_seen !== 6'b111111) begin
            errors = errors + 1;
            $display("FAIL FSM COVERAGE: seen=%b expected=111111", fsm_seen);
        end
        else begin
            $display("PASS FSM COVERAGE: IDLE/CHECK/MISS/REFILL/WRITE_WAIT/DONE");
        end

        $display("==================================================");
        $display("TOTAL ACCESSES = %0d", total_accesses);
        $display("HITS           = %0d", hit_count);
        $display("MISSES         = %0d", miss_count);

        if (total_accesses > 0) begin
            hit_rate = (100.0 * hit_count) / total_accesses;
            $display("HIT RATE       = %0.2f%%", hit_rate);
        end
        else begin
            $display("HIT RATE       = N/A");
        end

        $display("TOTAL ERRORS   = %0d", errors);

        if (errors == 0)
            $display("OVERALL RESULT = ALL TESTS PASSED");
        else
            $display("OVERALL RESULT = TESTS FAILED");

        $display("==================================================");

        #20;
        $finish;
    end

endmodule
