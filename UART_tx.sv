module UART_tx(clk, rst_n, tx_data, trmt, TX, tx_done);

	input clk, rst_n;   // Clock and active low asynchronous reset
	input[7:0] tx_data; // Data to transmit
	input trmt;         // Signal to begin transmission

	output logic TX;      // Transmitted value
	output logic tx_done; // Signal that transmission is finished

	localparam BAUD_DONE = 6'd42; // Baud rate is 43 clocks

	logic[2:0] data_count, next_data_count; // number of bits sent
	logic[5:0] baud_count, next_baud_count; // number of clocks for which this bit has been sent
	logic[7:0] data      , next_data      ; // data to send (TX = LSB)

	typedef enum reg[1:0] { IDLE, START, DATA, STOP } UART_tx_State;
	UART_tx_State state, next_state;

	// State advancement
	always_ff @(posedge clk) data_count <= next_data_count;
	always_ff @(posedge clk) baud_count <= next_baud_count;
	always_ff @(posedge clk) data       <= next_data      ;
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n)
			state <= IDLE;
		else
			state <= next_state;
	end

	// State logic
	logic baud_done;
	logic data_done;
	always_comb begin
		next_state = IDLE;
		TX = data[0];
		tx_done = 0;
		next_data = data;
		next_baud_count = 6'hxx;
		next_data_count = data_count;
		baud_done = (baud_count == BAUD_DONE);
		data_done = &data_count;

		unique case (state)
		IDLE: begin // Waiting for transmit signal
			next_state = IDLE;
			if (trmt) begin
				next_state = START;
				next_data = tx_data;
				next_baud_count = 0;
				TX = 0;
			end else begin
				TX = 1;
				tx_done = 1;
			end
		end
		START: begin // Send 0 for one baud
			next_state = START;
			if (baud_done) begin
				next_state = DATA;
				next_baud_count = 0;
				next_data_count = 0;
			end else begin
				next_baud_count = baud_count + 1;
				TX = 0;
			end
		end
		DATA: begin // Send data until data_done
			next_state = DATA;
			if (baud_done) begin
				next_baud_count = 0;
				if (data_done) begin
					next_state = STOP;
				end else begin
					next_data_count = data_count + 1;
					next_data = {1'bx, data[7:1]};
				end
			end else begin
				next_baud_count = baud_count + 1;
			end
		end
		STOP: begin // send 1 for one baud
			next_state = STOP;
			if (baud_done) begin
				tx_done = 1;
				if (trmt) begin // check for immediate next data, cut directly to START if exists.
					next_state = START;
					next_data = tx_data;
					next_baud_count = 0;
					TX = 0;
				end else begin // else idle
					next_state = IDLE;
					TX = 1;
				end
			end else begin
				next_baud_count = baud_count + 1;
				TX = 1;
			end
		end
		default:
			next_state = IDLE;
		endcase
	end

endmodule