module UART(clk, rst_n, tx_data, trmt, clr_rdy, RX, TX, tx_done, rx_data, rdy);

	input clk, rst_n;
	input trmt;
	input[7:0] tx_data;
	input clr_rdy;
	input RX;

	output TX;
	output tx_done;
	output[7:0] rx_data;
	output rdy;

	UART_tx transmitter(clk, rst_n, tx_data, trmt, TX, tx_done);
	UART_rx receiver   (clk, rst_n, clr_rdy, RX, rx_data, rdy);

endmodule
