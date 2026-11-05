# ModelSim do-file: overall Cache Memory integration verification
# Run this script from the Cache_Memory_Overall_Verification/rtl folder.

transcript on

# Rebuild the work library to avoid stale compiled modules.
if {[file exists work]} {
    vdel -lib work -all
}
vlib work

# Compile dependencies first, then top and testbench.
vlog -2001 cache_tag.v
vlog -2001 cache_data.v
vlog -2001 main_memory.v
vlog -2001 cache_controller.v
vlog -2001 cache_top.v
vlog -2001 tb_cache.v

# +acc keeps internal FSM and datapath signals visible in Wave.
vsim -voptargs=+acc work.tb_cache

# Testbench top-level signals.
add wave -divider "CPU / TESTBENCH"
add wave sim:/tb_cache/clk
add wave sim:/tb_cache/rst_n
add wave sim:/tb_cache/cpu_req
add wave sim:/tb_cache/cpu_we
add wave sim:/tb_cache/cpu_addr
add wave sim:/tb_cache/cpu_wdata
add wave sim:/tb_cache/cpu_rdata
add wave sim:/tb_cache/cpu_ready
add wave sim:/tb_cache/cache_hit
add wave sim:/tb_cache/cache_miss

# Internal integration signals.
add wave -divider "CACHE TOP INTERNAL"
add wave sim:/tb_cache/dut/address_tag
add wave sim:/tb_cache/dut/address_index
add wave sim:/tb_cache/dut/address_offset
add wave sim:/tb_cache/dut/mem_req
add wave sim:/tb_cache/dut/mem_we
add wave sim:/tb_cache/dut/mem_addr
add wave sim:/tb_cache/dut/mem_wdata
add wave sim:/tb_cache/dut/mem_rdata
add wave sim:/tb_cache/dut/mem_ready
add wave sim:/tb_cache/dut/controller_inst/state
add wave sim:/tb_cache/dut/controller_inst/tag_we
add wave sim:/tb_cache/dut/controller_inst/block_we
add wave sim:/tb_cache/dut/controller_inst/word_we

run -all
