module mock_dram #(parameter ID_WIDTH = 7, parameter WORD_WIDTH = 512, parameter NUM_WORD = 64) (
	input clk,
	input rst_n,
	axi4_bus_t.master axi
);

logic[WORD_WIDTH-1:0] ram[0:NUM_WORD-1];

// write channel
typedef enum logic[1:0] {
	WR_RST = 2'd0,
	WR_ADDR_WAIT = 2'd1,
	WR_DATA_WAIT = 2'd2,
	WR_RESP = 2'd3
} wr_states;

logic[1:0] wr_curr_state;
logic[1:0] wr_next_state;
logic[15:0] awid_q;
logic[63:0] awaddr_q;

always_comb begin 
	if (rst_n) begin		
		case (wr_curr_state)
			WR_RST:
				wr_next_state = WR_ADDR_WAIT;
			WR_ADDR_WAIT:
				wr_next_state = axi.awvalid ? WR_DATA_WAIT : WR_ADDR_WAIT;
			WR_DATA_WAIT:
				wr_next_state = (axi.wvalid && axi.wlast) ? WR_RESP : WR_DATA_WAIT;
			WR_RESP:
				wr_next_state = axi.bready ? WR_ADDR_WAIT : WR_RESP;
		endcase
	end
	else begin
		wr_next_state = WR_RST;
	end
end

assign axi.awready = (wr_curr_state == WR_ADDR_WAIT);
assign axi.wready = (wr_curr_state == WR_DATA_WAIT);
assign axi.bvalid = (wr_curr_state == WR_RESP);

always_ff @ (posedge clk) begin
	wr_curr_state <= wr_next_state;

	if (rst_n) begin
		if ((wr_curr_state == WR_ADDR_WAIT) && axi.awvalid) begin
			awid_q[ID_WIDTH-1:0] <= axi.awid[ID_WIDTH-1:0];
			awaddr_q <= axi.awaddr;
		end	
		else if ((wr_curr_state == WR_DATA_WAIT) && axi.wvalid) begin
			integer i;
			for (i = 0; i < WORD_WIDTH/8; i=i+1) begin
				if (axi.wstrb[i] == 1'b1) begin
					ram[awaddr_q[$clog2(WORD_WIDTH/8) +: ($clog2(NUM_WORD) - 1)]][8*i +: 8] <= axi.wdata[8*i +: 8];
				end
			end
			
			awaddr_q <= awaddr_q + (1<<($clog2(WORD_WIDTH/8)));
				
			if (axi.wlast) begin
				axi.bid[6:0] <= awid_q[6:0];
				axi.bresp <= 2'b0;
			end
		end
	
	end
	else begin
		integer j;
		for (j = 0; j < NUM_WORD; j=j+1) begin
			ram[j] <= 0;
		end
		awid_q <= 0;
		awaddr_q <= 0;
	end
end


// read channel
typedef enum logic[1:0]
{
	RD_RST = 2'd0,
	RD_ADDR_WAIT = 2'd1,
	RD_READ = 2'd2
} rd_states;


logic[1:0] rd_curr_state;
logic[1:0] rd_next_state;
logic[15:0] arid_q;
logic[63:0] araddr_q;
logic[7:0] arlen_q;

always_comb begin
	if (rst_n) begin
		case (rd_curr_state)
			RD_RST: 
				rd_next_state = RD_ADDR_WAIT;
			RD_ADDR_WAIT:
				rd_next_state = axi.arvalid ? RD_READ : RD_ADDR_WAIT;
			RD_READ: begin
				rd_next_state = (axi.rready && arlen_q == 0) ? RD_ADDR_WAIT : RD_READ;
			end
		endcase
	end 
	else begin
		rd_next_state = RD_RST;	
	end	
end


always_ff @ (posedge clk) begin
	rd_curr_state <= rd_next_state;
	if (rst_n) begin
		if ((rd_curr_state == RD_ADDR_WAIT) && axi.arvalid) begin
			araddr_q <= axi.araddr;
			arid_q[ID_WIDTH-1:0] <= axi.arid[ID_WIDTH-1:0];
			arlen_q <= axi.arlen;
			
		end
		else if (rd_curr_state == RD_READ) begin
			if (axi.rready) begin
				araddr_q <= araddr_q + (1<<($clog2(WORD_WIDTH/8)));
				arlen_q <= arlen_q - 1;
			end
		end
	end
 	else begin
		axi.rid <= 0;
		arid_q <= 0;
		araddr_q <= 0;
		arlen_q <= 0;
	end
end

assign axi.rresp = 0;
assign axi.arready = (rd_curr_state == RD_ADDR_WAIT);
assign axi.rid = arid_q;
assign axi.rvalid = (rd_curr_state == RD_READ);
assign axi.rdata = ram[araddr_q[$clog2(WORD_WIDTH/8) +: $clog2(NUM_WORD) - 1]];
assign axi.rlast = (rd_curr_state == RD_READ) && (arlen_q == 0); 



endmodule
