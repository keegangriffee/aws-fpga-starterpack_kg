module cl_dram_perf
(
  `include "cl_ports.vh"
);

`include "cl_common_defines.vh"
`include "cl_id_defines.vh"
`include "cl_dram_perf_defines.vh"

logic rst_main_n_sync;
// Tie off unused signals
//`include "unused_flr_template.inc"
`include "unused_ddr_a_b_d_template.inc"
`include "unused_ddr_c_template.inc"
`include "unused_pcim_template.inc"
//`include "unused_dma_pcis_template.inc"
`include "unused_cl_sda_template.inc"
`include "unused_sh_bar1_template.inc"
`include "unused_apppf_irq_template.inc"
`include "unused_sh_ocl_template.inc"

assign cl_sh_id0[31:0] = `CL_SH_ID0;
assign cl_sh_id1[31:0] = `CL_SH_ID1;
assign cl_sh_status0 = 32'h0000_0FF0;
assign cl_sh_status1 = 32'heeee_ee00;

// reset synchronization
logic pre_sync_rst_n;
(* dont_touch = "true" *) logic pipe_rst_n;
lib_pipe #(.WIDTH(1), .STAGES(4)) PIPE_RST_N (
  .clk(clk_main_a0),
  .rst_n(1'b1),
  .in_bus(rst_main_n),
  .out_bus(pipe_rst_n)
);

always_ff @(negedge pipe_rst_n or posedge clk_main_a0)
  if (!pipe_rst_n) begin
      pre_sync_rst_n  <= 0;
      rst_main_n_sync <= 0;
    end 
  else begin
        pre_sync_rst_n  <= 1;
        rst_main_n_sync <= pre_sync_rst_n;
    end


logic sh_cl_flr_assert_q;
always_ff @ (posedge clk_main_a0) begin
  if (!rst_main_n_sync) begin
    sh_cl_flr_assert_q <= 0;
    cl_sh_flr_done <= 0;
  end
  else begin
    sh_cl_flr_assert_q <= sh_cl_flr_assert;
    cl_sh_flr_done <= sh_cl_flr_assert_q && !cl_sh_flr_done;
  end
end

// DRAM
axi4_bus_t dma_pcis_bus();

assign dma_pcis_bus.awid[5:0] = sh_cl_dma_pcis_awid;
assign dma_pcis_bus.awaddr = sh_cl_dma_pcis_awaddr;
assign dma_pcis_bus.awlen = sh_cl_dma_pcis_awlen;
assign dma_pcis_bus.awsize = sh_cl_dma_pcis_awsize;
assign dma_pcis_bus.awvalid = sh_cl_dma_pcis_awvalid;
assign cl_sh_dma_pcis_awready = dma_pcis_bus.awready;

assign dma_pcis_bus.wdata = sh_cl_dma_pcis_wdata;
assign dma_pcis_bus.wstrb = sh_cl_dma_pcis_wstrb;
assign dma_pcis_bus.wlast = sh_cl_dma_pcis_wlast;
assign dma_pcis_bus.wvalid = sh_cl_dma_pcis_wvalid;
assign cl_sh_dma_pcis_wready = dma_pcis_bus.wready;

assign cl_sh_dma_pcis_bid = dma_pcis_bus.bid[5:0];
assign cl_sh_dma_pcis_bresp = dma_pcis_bus.bresp;
assign cl_sh_dma_pcis_bvalid = dma_pcis_bus.bvalid;
assign dma_pcis_bus.bready = sh_cl_dma_pcis_bready;

assign dma_pcis_bus.arid[5:0] = sh_cl_dma_pcis_arid;
assign dma_pcis_bus.araddr = sh_cl_dma_pcis_araddr;
assign dma_pcis_bus.arlen = sh_cl_dma_pcis_arlen;
assign dma_pcis_bus.arsize = sh_cl_dma_pcis_arsize;
assign dma_pcis_bus.arvalid = sh_cl_dma_pcis_arvalid;
assign cl_sh_dma_pcis_arready = dma_pcis_bus.arready; 

assign cl_sh_dma_pcis_rid = dma_pcis_bus.rid[5:0];
assign cl_sh_dma_pcis_rdata = dma_pcis_bus.rdata;
assign cl_sh_dma_pcis_rresp = dma_pcis_bus.rresp;
assign cl_sh_dma_pcis_rlast = dma_pcis_bus.rlast;
assign cl_sh_dma_pcis_rvalid = dma_pcis_bus.rvalid;
assign dma_pcis_bus.rready = sh_cl_dma_pcis_rready;

mock_dram MOCK_DRAM_A(
  .clk(clk_main_a0),
  .rst_n(rst_main_n_sync),
  .axi(dma_pcis_bus)
);


endmodule





