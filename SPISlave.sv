module SPISlave(clk, rst_n, data, SCLK, MOSI, SS_n, MISO, cmd, cmd_rdy);

	input clk, rst_n; // Clock and active low asynchronous reset
	input[15:0] data;       // The data sent back to the master
	input SCLK;       // SPI Clock from Master (unstable)
	input MOSI;       // Master Out Slave In - incoming data (unstable)
	input SS_n;       // Active Low Slave Select (unstable)

	output logic MISO;     // The outgoing value
	output reg[15:0] cmd;  // The incoming command
	output logic cmd_rdy;  // Whether the cmd is currently valid

	logic[15:0] next_cmd; // The next value for cmd

	// Set up stabilizers, edge detectors, and delays
	logic SCLK_stable ;     Stabilize     SCLK_stabilizer(clk, rst_n, SCLK       , SCLK_stable );
	logic SCLK_negedge;     NegEdgeDetect SCLK_detector  (clk, rst_n, SCLK_stable, SCLK_negedge);
	logic MOSI_stable ;     Stabilize     MOSI_stabilizer(clk, rst_n, MOSI       , MOSI_stable );
	logic MOSI_delayed;     Flop          MOSI_delayer   (clk, rst_n, MOSI_stable, MOSI_delayed);
	logic SS_stable_n ;     Stabilize     SS_n_stabilizer(clk, rst_n, SS_n       , SS_stable_n );
	logic SS_delayed  ;     Flop          SS_n_delayer   (clk, rst_n, SS_stable_n, SS_delayed  );
	logic SS_negedge  ;     assign SS_negedge = !SS_stable_n && SS_delayed;

	always_ff @(posedge clk) begin
		cmd <= next_cmd; // Update cmd
	end

	always_comb begin
		cmd_rdy = SS_stable_n; // Command is ready if master is not sending data
		// If master is sending data, shift left cmd and shift in MOSI_delayed
		MISO = SS_delayed ? 1'bz : cmd[15];
		next_cmd = SS_negedge ? data :
		           (!SS_stable_n && SCLK_negedge) ? {cmd[14:0], MOSI_delayed} : cmd;
	end

endmodule
