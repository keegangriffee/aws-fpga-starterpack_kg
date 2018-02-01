// Test dram

module test_mock_dram();
	import tb_type_defines_pkg::*;
	logic[63:0] cl_addr;
	logic[63:0] src_addr;
	logic[63:0] dst_addr;
	int timeout_count;
	logic[3:0] status;
	int len0 = 128;
	logic[7:0] rdata;
	logic[7:0] wdata;
	initial begin

		tb.power_up(
			.clk_recipe_a(ClockRecipe::A1),
			.clk_recipe_b(ClockRecipe::B0),
			.clk_recipe_c(ClockRecipe::C0)
		);
	
		tb.nsec_delay(1000);
		tb.poke_stat(.addr(8'h0c), .ddr_idx(0), .data(32'h0000_0000));
       	tb.poke_stat(.addr(8'h0c), .ddr_idx(1), .data(32'h0000_0000));
		tb.poke_stat(.addr(8'h0c), .ddr_idx(2), .data(32'h0000_0000));
		tb.nsec_delay(27000);	

		tb.issue_flr();

	
		// set up buffer and queue transfer
		src_addr = 64'h0;
		wdata = 0;
		tb.que_buffer_to_cl(.chan(0), .src_addr(src_addr), .cl_addr(0), .len(len0));

		for (int i = 0; i < len0; i++) begin
			tb.hm_put_byte(.addr(src_addr), .d(wdata));
			wdata += 1;
			src_addr++;
		end
		#40ns;
		
		// start transfer from buffer to cl
		tb.start_que_to_cl(.chan(0));
		timeout_count = 0;
		do begin
			status[0] = tb.is_dma_to_cl_done(.chan(0));
			#10ns;
			timeout_count++;
		end while ((status[0] != 1) && timeout_count < 100);

		if (timeout_count >= 100) begin
			$display("[%t] transfer from buffer to cl timed out.", $realtime);
		end
		
		// queue transfer from cl to buffer
		dst_addr = (1 << 12);
		tb.que_cl_to_buffer(.chan(0), .dst_addr(dst_addr), .cl_addr(0), .len(len0));
		#10ns;

		tb.start_que_to_buffer(.chan(0));

		timeout_count = 0;
		do begin
			status[0] = tb.is_dma_to_buffer_done(.chan(0));
			#10ns;
			timeout_count++;
		end while ((status[0] != 1) && timeout_count < 100);

	 	if (timeout_count >= 100) begin
			$display("[%t] transfer from cl to buffer timed out.", $realtime);
		end
		
		// compare buffer
		src_addr = 0;
		for (int i = 0; i <len0; i++) begin
			wdata = tb.hm_get_byte(.addr(src_addr + i));
			rdata = tb.hm_get_byte(.addr(dst_addr + i));
			if (rdata !== wdata) begin
				$display("data mismatch. addr: %0x, rdata: %0x, wdata: %0x", dst_addr+i, rdata, wdata);
			end
			else begin
				$display("data matched. addr: %0x, rdata: %0x, wdata: %0x", dst_addr+i, rdata, wdata);
			end

		end
	
		#500ns;	
     	tb.power_down();
     	$finish;
   end
endmodule
