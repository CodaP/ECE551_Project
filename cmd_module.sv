module cmd_module(clk, rst_n, cmd, cmd_rdy, clr_cmd_rdy, resp_data, send_resp, resp_sent, ss, wrt_SPI, SPI_data, EEP_data, SPI_done);
	
	localparam CONFIG_GAIN = 8'h02;
	localparam SET_TRIGGER = 8'h03;
	localparam WRITE_EEPROM = 8'h08;
	localparam READ_EEPROM = 8'h09;

	input clk, rst_n;
	//Connections to the UART command aggregator
	input[23:0] cmd;
	input cmd_rdy;
	output logic clr_cmd_rdy;
	output logic[7:0] rsp_data;
	output logic send_resp;
	input resp_sent;
	//Connections to the SPI module and related logic
	output logic[2:0] ss;
	output logic wrt_SPI;
	output logic[15:0] SPI_data;
	output logic[7:0] EEP_data;
	input SPI_done;

