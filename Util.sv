// Utility modules used throughout the homework

module DetectStableEdge(clk, rst_n, _in, stable, delayed, posEdge, negEdge);
	parameter RESET = 0;

	input clk, rst_n;
	input _in;
	output stable;
	output delayed;
	output posEdge;
	output negEdge;

	logic firstFlopped;

	Flop #(RESET) ff1(clk, rst_n, _in, firstFlopped);
	Flop #(RESET) ff2(clk, rst_n, firstFlopped, stable);
	Flop #(RESET) ff3(clk, rst_n, stable, delayed);

	assign posEdge = delayed && !stable;
	assign negEdge = !delayed && stable;

endmodule

module NegEdgeDetect(clk, rst_n, is, neg);
	parameter RESET = 0;

	input clk, rst_n; // Clock and active low asynchronous reset
	input is;         // The current input value

	output logic neg; // 1 iff input is 0 now and was 1 last posedge clk

	reg was;          // The old value of is

	Flop #(RESET) remember_last(clk, rst_n, is, was); // Remember is as was

	always_comb begin
		neg = was && !is; // was 1 and is 0
	end

endmodule

module Stabilize(clk, rst_n, in, out);
	parameter RESET = 0;

	input clk, rst_n;  // Clock and active low asynchronous reset
	input in;          // The unstable input
	logic first_ff;    // The half-stable value
	output logic out;  // A metastable version of in, delayed by two clocks

	Flop #(RESET) sequencer (clk, rst_n, in, first_ff);  // Create metastability by
	Flop #(RESET) stabilizer(clk, rst_n, first_ff, out); // double-flopping in

endmodule

module Bit(clk, rst_n, set, clr, val);
	parameter RESET = 0;

	input clk, rst_n; // Clock and active low asynchronous reset
	input set;        // Forces val to 1 (has precedence over clr)
	input clr;        // Forces val to 0
	output logic val; // Retains its value unless set or clr are 1

	logic next_val;
	assign next_val = set ? 1 :
	                  clr ? 0 :
	                  val;

	Flop #(RESET) the_bit(clk, rst_n, next_val, val);
endmodule

module Flop(clk, rst_n, in, out);
	parameter RESET = 0;

	input clk, rst_n;  // Clock and active low asynchronous reset
	input in;          // The value to flop
	output reg out;    // The value from last clock

	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			out <= RESET;  // Reset to RESET
		end else begin
			out <= in; // Remember in as out
		end
	end

endmodule
