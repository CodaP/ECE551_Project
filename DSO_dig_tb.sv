`timescale 1ns/10ps
module DSO_dig_tb();
	
reg clk,rst_n;							// clock and reset are generated in TB

reg [7:0] cmd_snd;						// command Host is sending to DUT
reg send_cmd;
reg clr_resp_rdy;

reg fail;

wire adc_clk,MOSI,SCLK,trig_ss_n,ch1_ss_n,ch2_ss_n,ch3_ss_n,EEP_ss_n;
wire TX,RX;

wire [15:0] cmd_ch1,cmd_ch2,cmd_ch3;			// received commands to digital Pots that control channel gain
wire [15:0] cmd_trig;							// received command to digital Pot that controls trigger level
wire cmd_sent,resp_rdy;							// outputs from master UART
wire [7:0] resp_rcv;
wire [7:0] ch1_data,ch2_data,ch3_data;
wire trig1,trig2;

integer fd_out = $fopen("uart_data.txt","w");
integer fd_in = $fopen("uart_commands.txt","r");
reg [23:0] input_cmd;
reg [7:0] delay;

///////////////////////////
// Define command bytes //
/////////////////////////
localparam DUMP_CH  = 8'h01;		// Channel to dump specified in low 2-bits of second byte
localparam CFG_GAIN = 8'h02;		// Gain setting in bits [4:2], and channel in [1:0] of 2nd byte
localparam TRIG_LVL = 8'h03;		// Set trigger level, lower byte specifies value (46,201) is valid
localparam TRIG_POS = 8'h04;		// Set the trigger position. This is a 13-bit number, samples after capture
localparam SET_DEC  = 8'h05;		// Set decimator, lower nibble of 3rd byte. 2^this value is decimator
localparam TRIG_CFG = 8'h06;		// Write trig config.  2nd byte 00dettcc.  d=done, e=edge,
localparam TRIG_RD  = 8'h07;		// Read trig config register
localparam EEP_WRT  = 8'h08;		// Write calibration EEP, 2nd byte is address, 3rd byte is data
localparam EEP_RD   = 8'h09;		// Read calibration EEP, 2nd byte specifies address

//////////////////////
// Instantiate DUT //
////////////////////
DSO_dig iDUT(.clk(clk),.rst_n(rst_n),.adc_clk(adc_clk),.ch1_data(ch1_data),.ch2_data(ch2_data),
             .ch3_data(ch3_data),.trig1(trig1),.trig2(trig2),.MOSI(MOSI),.MISO(MISO),.SCLK(SCLK),
             .trig_ss_n(trig_ss_n),.ch1_ss_n(ch1_ss_n),.ch2_ss_n(ch2_ss_n),.ch3_ss_n(ch3_ss_n),
			 .EEP_ss_n(EEP_ss_n),.TX(TX),.RX(RX),.LED_n());
			   
///////////////////////////////////////////////
// Instantiate Analog Front End & A2D Model //
/////////////////////////////////////////////
AFE_A2D iAFE(.clk(clk),.rst_n(rst_n),.adc_clk(adc_clk),.ch1_ss_n(ch1_ss_n),.ch2_ss_n(ch2_ss_n),.ch3_ss_n(ch3_ss_n),
             .trig_ss_n(trig_ss_n),.MOSI(MOSI),.SCLK(SCLK),.trig1(trig1),.trig2(trig2),.ch1_data(ch1_data),
			 .ch2_data(ch2_data),.ch3_data(ch3_data));
			 
/////////////////////////////////////////////
// Instantiate UART Master (acts as host) //
///////////////////////////////////////////
UART iMSTR(.clk(clk), .rst_n(rst_n), .RX(TX), .TX(RX), .rx_data(resp_rcv), .trmt(send_cmd),
                     .tx_done(cmd_sent), .rdy(resp_rdy), .tx_data(cmd_snd), .clr_rdy(clr_resp_rdy));

always @(posedge resp_rdy)
    $fdisplay(fd_out, "%h", resp_rcv);

/////////////////////////////////////
// Instantiate Calibration EEPROM //
///////////////////////////////////
SPI_EEP iEEP(.clk(clk),.rst_n(rst_n),.SS_n(EEP_ss_n),.SCLK(SCLK),.MOSI(MOSI),.MISO(MISO));
	
initial begin
  clk = 0;
  rst_n = 0;			// assert reset
  fail = 0;
  send_cmd = 0;
  clr_resp_rdy = 1;
  ///////////////////////////////
  // Your testing goes here!! //
  /////////////////////////////
  repeat(10) @(negedge clk);
  rst_n = 1;

  while($fscanf(fd_in, "%h %h", input_cmd, delay) > 0) begin
      casex(input_cmd[23:16])
        DUMP_CH: begin
            $fdisplay(fd_out, "#Sending command %h (dump)",input_cmd);
            send_uart(input_cmd);
            repeat(511) @(posedge resp_rdy);
            repeat(delay) begin
                #1;
            end
        end
        default: begin
            $fdisplay(fd_out, "#Sending command %h",input_cmd);
            send_uart(input_cmd);
            repeat(delay) begin
                #1;
            end
        end
      endcase
  end
  
  $fclose(fd_out);
  $stop;

end

task send_uart(input reg [23:0] input_cmd);
    send_uart_no_resp(input_cmd);
      if(!resp_rdy)
          @(posedge resp_rdy);
endtask

task send_uart_no_resp(input reg [23:0] input_cmd);

  cmd_snd = input_cmd[23:16];
  @(negedge clk);
  send_cmd = 1;
  @(negedge clk);
  send_cmd = 0;
  while(!cmd_sent) @(posedge clk);
  cmd_snd = input_cmd[15:8];
  @(negedge clk);
  send_cmd = 1;
  @(negedge clk);
  send_cmd = 0;
  while(!cmd_sent) @(posedge clk);
  cmd_snd = input_cmd[7:0];
  @(negedge clk);
  send_cmd = 1;
  @(negedge clk);
  send_cmd = 0;
  while(!cmd_sent) @(posedge clk);

endtask

always
  #1 clk = ~clk;
			 

endmodule
			 
			 
