module tb_UART;

	logic clk, rst_n;
	// inputs
	logic[7:0] tx_data;
	logic trmt;
	logic clr_rdy;
	logic RX;
	//outputs
	logic TX;
	logic tx_done;
	logic[7:0] rx_data;
	logic rdy;

	logic fail;

	UART iDUT(clk, rst_n, tx_data, trmt, clr_rdy, RX, TX, tx_done, rx_data, rdy);

	always #5 clk = ~clk;

	assign RX = TX; // Hook up transmit to receive directly

	initial begin
		// Initialize variables
		clk = 0;
		rst_n = 0;
		tx_data = 8'h5F;
		trmt = 0;
		clr_rdy = 0;
		fail = 0;
		@(posedge clk);
		@(posedge clk) rst_n = 1;
		//test
		@(posedge clk);
		@(posedge clk) trmt = 1; // start transmitting
		@(posedge clk) trmt = 0;
		while(!tx_done) @(posedge clk); // wait for tx done
		while(!rdy) @(posedge clk); // wait for rx done
		@(posedge clk);
		if (rx_data != tx_data) // check data
			fail = 1;
		@(posedge clk);
		@(posedge clk) clr_rdy = 1; // clear rdy
		@(posedge clk) clr_rdy = 0;
		if (rx_data != tx_data) // check data stability
			fail = 1;
		repeat(10) @(posedge clk); // leave space on waveform
		$stop;
	end

endmodule