`timescale 1ns/10ps
module DSO_dig(clk,rst_n,adc_clk,ch1_data,ch2_data,ch3_data,trig1,trig2,MOSI,MISO,
               SCLK,trig_ss_n,ch1_ss_n,ch2_ss_n,ch3_ss_n,EEP_ss_n,TX,RX);
				
  input clk,rst_n;								// clock and active low reset
  output adc_clk;								// 20MHz clocks to ADC
  input [7:0] ch1_data,ch2_data,ch3_data;		// input data from ADC's
  input trig1,trig2;							// trigger inputs from AFE
  input MISO;									// Driven from SPI output of EEPROM chip
  output MOSI;									// SPI output to digital pots and EEPROM chip
  output SCLK;									// SPI clock (40MHz/16)
  output ch1_ss_n,ch2_ss_n,ch3_ss_n;			// SPI slave selects for configuring channel gains (active low)
  output trig_ss_n;								// SPI slave select for configuring trigger level
  output EEP_ss_n;								// Calibration EEPROM slave select
  output TX;									// UART TX to HOST
  input RX;										// UART RX from HOST
  // TODO
  //output LED_n;									// control to active low LED
  
  ////////////////////////////////////////////////////
  // Define any wires needed for interconnect here //
  //////////////////////////////////////////////////


  /////////////////////////////
  // Instantiate SPI master //
  ///////////////////////////
  
  ///////////////////////////////////////////////////////////////
  // You have a SPI master peripheral with a single SS output //
  // you might have to do something creative to generate the //
  // 5 individual SS needed (3 AFE, 1 Trigger, 1 EEP)       //
  ///////////////////////////////////////////////////////////
  
  ///////////////////////////////////
  // Instantiate UART_comm module //
  /////////////////////////////////
  reg clr_cmd_rdy;
  wire cmd_rdy;
  wire [23:0] cmd;
  reg trmt;
  reg [7:0] tx_data;
  wire tx_done;
  UART_comm comm(clk, rst_n, RX, TX, clr_cmd_rdy, cmd_rdy, cmd, trmt, tx_data, tx_done);
				    
  ///////////////////////////
  // Instantiate dig_core //
  /////////////////////////

  //////////////////////////////////////////////////////////////
  // Instantiate the 3 512 RAM blocks that store A2D samples //
  ////////////////////////////////////////////////////////////
  RAM512 iRAM1(.rclk(rclk),.en(en),.we(we),.addr(addr),.wdata(ch1_data),.rdata(ch1_rdata));
  RAM512 iRAM2(.rclk(rclk),.en(en),.we(we),.addr(addr),.wdata(ch2_data),.rdata(ch2_rdata));
  RAM512 iRAM3(.rclk(rclk),.en(en),.we(we),.addr(addr),.wdata(ch3_data),.rdata(ch3_rdata));

endmodule
  
