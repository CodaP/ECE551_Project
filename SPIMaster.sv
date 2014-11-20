module SPIMaster(clk, rst_n, cmd, wrt, MISO, SCLK, MOSI, SS_n, data, done);

	input clk, rst_n; // Clock and active low asynchronous reset
	input wrt;        // Signal to start a write
	input[15:0] cmd;  // The command to send
	input MISO;       // The incoming signal from the slave (UNSTABLE)

	output logic SCLK;     // The SPI clock signal (1/32 clk speed)
	output logic MOSI;     // The output data
	output logic SS_n;     // Active Low Slave Select - Low iff data is being transmitted
	output logic done;     // Signal that transmission has finished
	output reg[15:0] data; // Returned data from the slave

	logic[15:0] next_data;

	typedef enum reg[1:0] { IDLE, GEN, DONE } SPIMaster_State;
	SPIMaster_State state, next_state;

	logic clock_done; // 1 iff clock has completed a cycle
	logic clock_negedge; // 1 iff clock is at a negedge
	reg[4:0] clock_count, next_clock; // clock_count[4] is the value of SCLK

	logic cycle_done; // 1 iff all cycles have completed
	reg[3:0] cycle_count, next_cycle;

	logic MISO_stabilized; Stabilize MISO_stabilizer(clk, rst_n, MISO, MISO_stabilized);

	always_ff @(posedge clk) clock_count <= next_clock;
	always_ff @(posedge clk) cycle_count <= next_cycle;
	always_ff @(posedge clk) data        <= next_data ;
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n)
			state <= IDLE;
		else // Advance state
			state <= next_state;
	end

	always_comb begin
		// Setup default values
		next_state = IDLE;
		next_clock = 0;
		next_cycle = 0;
		next_data = data;
		SCLK = 0;
		SS_n = 1;
		done = 0;
		clock_done = &clock_count; // Clock has completed a cycle when clock is all ones
		clock_negedge = (clock_count == 5'h10); // When clock is 10000_2, it is a negedge (has just flipped SCLK bit)
		cycle_done = &cycle_count; // Write has completed when cycle is all ones
		MOSI = data[15]; // Output the MSB of data

		unique case (state)
		IDLE: // Waiting for wrt signal to begin sending
			if (wrt) begin
				next_state = GEN;
				next_cycle = 0;
				next_clock = 0;
				next_data = cmd;
			end
		GEN: // Generating the clock signal, sending data
			begin
				next_state = GEN;
				next_clock = clock_count + 1;
				SS_n = 0;
				SCLK = ~clock_count[4];
				if (clock_done) begin
					next_cycle = cycle_count + 1;
					if (cycle_done) begin // Only check cycle_done if clock_done - this will ensure 16 cycles are completed
						next_state = DONE;
						next_clock = 0;
						SS_n = 0;
					end
				end else begin
					next_cycle = cycle_count;
					if (clock_negedge) begin // Shift data on clock negedge
						next_data = {data[14:0], MISO_stabilized};
					end
				end
			end
		DONE: // Signal done for one clock, then IDLE
			begin
                done = 1;
                if(wrt) begin
                    next_state = GEN;
                    next_cycle = 0;
                    next_clock = 0;
                    next_data = cmd;
                end
                else begin
                    next_state = IDLE;
                end
			end
		default:
			next_state = IDLE;
		endcase
	end

endmodule
