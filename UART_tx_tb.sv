module tb_UART_tx;

	logic clk, rst_n;
	// inputs
	logic[7:0] tx_data;
	logic trmt;
	//outputs
	logic TX;
	logic tx_done;

	UART_tx iDUT(clk, rst_n, tx_data, trmt, TX, tx_done);

	always #5 clk = ~clk;

	initial begin
		// Initialize variables
		clk = 0;
		rst_n = 0;
		tx_data = 8'h59;
		trmt = 0;
		@(posedge clk);
		@(posedge clk) rst_n = 1;
		@(posedge clk) trmt = 1; // start transmit
		@(posedge clk) trmt = 0;
		while(!tx_done) @(posedge clk); // wait for tx_done
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
		$stop;
	end

endmodule
