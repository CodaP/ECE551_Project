module tb_SPISlave;

	logic clk, rst_n;
	// inputs
	logic[15:0] mcmd, scmd, mdata, sdata;
	logic wrt;
	//intermediates
	logic SCLK;
	logic MOSI;
	logic MISO;
	logic SS_n;
	logic done;
	//outputs
	logic cmd_rdy;

	logic fail;

	SPIMaster iMASTER(clk, rst_n, mcmd, wrt, MISO, SCLK, MOSI, SS_n, mdata, done);
	SPISlave iDUT(clk, rst_n, scmd, SCLK, MOSI, SS_n, MISO, sdata, cmd_rdy);

	always #5 clk = ~clk;

	initial begin
		// Initialize variables
		clk = 0;
		rst_n = 0;
		fail = 0;
		mcmd = 16'b1001_0110_1110_1001;
		scmd = ~mcmd;
		wrt = 0;
		// end reset signal
		@(posedge clk) rst_n = 1;
		//test
		@(posedge clk);
		@(posedge clk) wrt = 1; // kick off write
		@(posedge clk) wrt = 0;
		while(!done) @(posedge clk);
		if (mcmd != sdata) // check that commands switched
			fail = 1;
		if (scmd != mdata)
			fail = 1;
		repeat (10) @(posedge clk);
		mcmd = 16'b0011_0111_1111_1010;
		scmd = 16'b1001_0110_1011_0111;
		@(posedge clk) wrt = 1; // do another write
		@(posedge clk) wrt = 0;
		while(!done) @(posedge clk);
		if (mcmd != sdata) // check that commands switched
			fail = 1;
		if (scmd != mdata)
			fail = 1;
		repeat (30) @(posedge clk);
		if (mcmd != sdata) // check that commands are stable
			fail = 1;
		if (scmd != mdata)
			fail = 1;
		@(posedge clk);
		$stop;
	end

endmodule
