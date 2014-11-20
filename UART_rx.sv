module UART_rx(clk, rst_n, clr_rdy, RX, rx_data, rdy);

	input clk, rst_n; // Clock and active low asynchronous reset
	input clr_rdy;
	input RX;

	output logic[7:0] rx_data;
	output logic rdy;

	logic[7:0] next_rx_data;

	localparam BAUD_DONE = 6'd42; // Baud rate is 43 clocks
	localparam IDLE_START = BAUD_DONE + 1; // Count wraps around to BAUD_DONE, creating about 1.5 baud

	logic[2:0] data_count, next_data_count; // number of bits received
	logic[5:0] baud_count, next_baud_count; // number of clocks for which this bit has been received
	logic RX_stable; Stabilize #(.RESET(1)) RX_stabilizer(clk, rst_n, RX, RX_stable);

	typedef enum reg[1:0] { IDLE, START, DATA, STOP } UART_rx_State;
	UART_rx_State state, next_state;

	// State advancement
	always_ff @(posedge clk) data_count <= next_data_count;
	always_ff @(posedge clk) baud_count <= next_baud_count;
	always_ff @(posedge clk) rx_data    <= next_rx_data   ;
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n)
			state <= IDLE;
		else
			state <= next_state;
	end

	logic baud_done;
	logic data_done;
	always_comb begin
		next_state = IDLE;
		next_rx_data = rx_data;
		rdy = 0;
		next_data_count = data_count;
		next_baud_count = 6'hxx;
		baud_done = (baud_count == BAUD_DONE);
		data_done = &data_count;

		unique case (state)
		IDLE: begin // Wait for RX to drop, then start read
			next_state = IDLE;
			if (!RX_stable) begin
				next_state = START;
				next_baud_count = IDLE_START;
			end
		end
		START: begin // Wait 1.5 baud and then start reading data
			next_state = START;
			if (baud_done) begin
				next_state = DATA;
				next_data_count = 0;
				next_baud_count = 0;
				next_rx_data = {RX_stable, rx_data[7:1]};
			end else begin
				next_baud_count = baud_count + 1;
			end
		end
		DATA: begin // Receive 7 more bits of data
			next_state = DATA;
			if (baud_done) begin
				if (data_done) begin
					next_state = STOP;
				end else begin
					next_rx_data = {RX_stable, rx_data[7:1]};
					next_data_count = data_count + 1;
					next_baud_count = 0;
				end
			end else begin
				next_baud_count = baud_count + 1;
			end
		end
		STOP: begin // Make sure RX is 1 (hopefully stop bit) before going back to IDLE
			next_state = STOP;
            rdy = 1;
			if (clr_rdy) begin
				next_state = IDLE;
			end
		end
		default:
			next_state = IDLE;
		endcase
	end

endmodule
