/**
 *	reg_file.sv
 * 	A register file controlled by AXI-LITE interface.
 *		
 *	@author: Tommy Jung
 */

module reg_file
(
	input clk,
	input rst_n,
	axi_lite_bus_t.master axi_bus,
	output[31:0] start_addr,
	output[31:0] burst_len,
	output[31:0] write_val,
	output[1:0] rw_en,
	input[1:0] rw_done,
	input[31:0] rhash,
	input[31:0] rd_clk_count,
	input[31:0] wr_clk_count
);

logic[31:0] start_addr_reg;
logic[31:0] burst_len_reg;
logic[31:0] write_val_reg;
logic[1:0] rw_en_reg;

assign start_addr = start_addr_reg;
assign burst_len = burst_len_reg;
assign write_val = write_val_reg;
assign rw_en = rw_en_reg;

logic[31:0] awaddr;
logic awvalid;
logic awready;

logic[31:0] wdata;
logic[3:0] wstrb;
logic wvalid;
logic wready;

logic bvalid;
logic[1:0] bresp;
logic bready;

logic arvalid;
logic[31:0] araddr;
logic arready;

logic rvalid;
logic[31:0] rdata;
logic[1:0] rresp;
logic rready;


axi_register_slice_light AXI_BUS_REG_SLICE
(
	.aclk (clk),
	.aresetn(rst_n),
	// s
	.s_axi_awaddr (axi_bus.awaddr),
  	.s_axi_awprot (3'b0),
   	.s_axi_awvalid (axi_bus.awvalid),
   	.s_axi_awready (axi_bus.awready),

   	.s_axi_wdata (axi_bus.wdata),
   	.s_axi_wstrb (axi_bus.wstrb),
   	.s_axi_wvalid (axi_bus.wvalid),
   	.s_axi_wready (axi_bus.wready),

   	.s_axi_bresp (axi_bus.bresp),
   	.s_axi_bvalid (axi_bus.bvalid),
   	.s_axi_bready (axi_bus.bready),

   	.s_axi_araddr (axi_bus.araddr),
   	.s_axi_arvalid (axi_bus.arvalid),
   	.s_axi_arready (axi_bus.arready),

   	.s_axi_rdata (axi_bus.rdata),
   	.s_axi_rresp (axi_bus.rresp),
   	.s_axi_rvalid (axi_bus.rvalid),
   	.s_axi_rready (axi_bus.rready),
   	// m
	.m_axi_awaddr (awaddr),
   	.m_axi_awprot (),
   	.m_axi_awvalid (awvalid),
   	.m_axi_awready (awready),
   	
	.m_axi_wdata (wdata),
   	.m_axi_wstrb (wstrb),
   	.m_axi_wvalid (wvalid),
   	.m_axi_wready (wready),
   	
	.m_axi_bresp (bresp),
   	.m_axi_bvalid (bvalid),
   	.m_axi_bready (bready),
   	
	.m_axi_araddr (araddr),
   	.m_axi_arvalid (arvalid),
   	.m_axi_arready (arready),
   	
	.m_axi_rdata (rdata),
   	.m_axi_rresp (rresp),
   	.m_axi_rvalid (rvalid),
	.m_axi_rready (rready)
);

logic wr_active;
logic[31:0] wr_addr;


// write operation
always_ff @ (posedge clk) begin
	if (!rst_n) begin
		wr_active <= 0;
		wr_addr <= 0;	
	end
	else begin
		if (wr_active) begin
			if (bvalid && bvalid && bready) begin
				wr_active <= 0;
			end				
		end
		else begin
			if (awvalid) begin
				wr_active <= 1;
				wr_addr <= awaddr;
			end
		end		
	end
end

assign awready = ~wr_active;
assign wready = wr_active && wvalid;

always_ff @ (posedge clk) begin
	if (!rst_n) begin
		start_addr_reg <= 0;
		burst_len_reg <= 0;
		write_val_reg <= 0;
		rw_en_reg <= 0;
	end
	else begin
		if (wready) begin
			case (wr_addr)
				`START_ADDR_REG_ADDR: start_addr_reg <= wdata;
				`BURST_LEN_REG_ADDR: burst_len_reg <= wdata;
				`WRITE_VAL_REG_ADDR: write_val_reg <= wdata;
				`RW_EN_REG_ADDR: rw_en_reg <= wdata[1:0];
			endcase
		end	
	end
end

always_ff @ (posedge clk) begin
	if (!rst_n) begin
		bvalid <= 0;
	end
	else begin
		if (bvalid) begin
			if (bready) begin
				bvalid <= 0;
			end	
		end
		else begin
			if (wready) begin
				bvalid <= 1;
			end
		end
	end
end

assign bresp = 0;

// read operation
logic rd_active;
logic[31:0] rd_addr;

always_ff @ (posedge clk) begin
	if (!rst_n) begin
		rd_active <= 0;
		rd_addr <= 0;	
	end
	else begin
		rd_active <= arvalid;
		if (arvalid) begin
			rd_addr <= araddr;
		end
	end
end

assign arready = !rd_active && !rvalid;

always_ff @ (posedge clk) begin
	if (!rst_n) begin
		rvalid <= 0;
		rdata <= 0;
		rresp <= 0;
	end
	else begin
		if (rd_active) begin
			rvalid <= 1;
			rresp <= 0;
			case(rd_addr)
				`START_ADDR_REG_ADDR: rdata <= start_addr_reg; 
				`BURST_LEN_REG_ADDR: rdata <= burst_len_reg;
				`WRITE_VAL_REG_ADDR: rdata <= write_val_reg;
				`RHASH_REG_ADDR: rdata <= rhash;
				`RW_DONE_REG_ADDR: rdata <= {30'b0, rw_done};
				`RD_CLK_COUNT_REG_ADDR: rdata <= rd_clk_count;	
				`WR_CLK_COUNT_REG_ADDR: rdata <= wr_clk_count;
				default: rdata <= 32'hdead_beef;
			endcase
		end

		if (rvalid && rready) begin
			rvalid <= 0;
			rdata <= 0;
			rresp <= 0;
		end
	end
end

endmodule

