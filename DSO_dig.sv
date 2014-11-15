`timescale 1ns/10ps
`include "types.h"
module DSO_dig(clk,rst_n,adc_clk,ch1_data,ch2_data,ch3_data,trig1,trig2,MOSI,MISO,
               SCLK,trig_ss_n,ch1_ss_n,ch2_ss_n,ch3_ss_n,EEP_ss_n,TX,RX);
				
  input clk,rst_n;								// clock and active low reset
  output adc_clk;								// 20MHz clocks to ADC
  input [7:0] ch1_data,ch2_data,ch3_data;		// input data from ADC's
  input trig1,trig2;							// trigger inputs from AFE
  input MISO;									// Driven from SPI output of EEPROM chip
  output MOSI;									// SPI output to digital pots and EEPROM chip
  output SCLK;									// SPI clock (40MHz/16)
  output logic ch1_ss_n,ch2_ss_n,ch3_ss_n;			// SPI slave selects for configuring channel gains (active low)
  output logic trig_ss_n;								// SPI slave select for configuring trigger level
  output logic EEP_ss_n;								// Calibration EEPROM slave select
  output TX;									// UART TX to HOST
  input RX;										// UART RX from HOST
  // TODO
  //output LED_n;									// control to active low LED
  logic clr_cmd_rdy;
  logic cmd_rdy;
  logic trmt;
  logic [7:0] tx_data;
  logic tx_done;
  logic [23:0] cmd;

  ////////////////////////////////////////////////////
  // Define any wires needed for interconnect here //
  //////////////////////////////////////////////////
  SlaveSelect ss;
  SlaveSelect nxt_ss;
  logic wrt_SPI;
  logic SPI_data;
  logic SPI_done;

  logic EEP_data;
  logic rclk;
  logic en,we;
  logic [8:0] addr;
  logic [7:0] ch1_rdata;
  logic [7:0] ch2_rdata;
  logic [7:0] ch3_rdata;

  always_ff @(posedge clk, negedge rst_n)
    if(!rst_n)
        ss <= SS_NONE;
    else
        if(wrt_SPI)
            ss <= nxt_ss;
        else
            ss <= ss;


  logic SS_n;
  logic nxt_SS_n;

  always_ff @(posedge clk, negedge rst_n)
    if(!rst_n)
        SS_n <= 1;
    else
        SS_n <= nxt_SS_n;


  /////////////////////////////
  // Instantiate SPI master //
  ///////////////////////////
  SPIMaster spi(clk, rst_n, cmd, wrt_SPI, MISO, SCLK, MOSI, nxt_SS_n, SPI_data, SPI_done);
  
  ///////////////////////////////////////////////////////////////
  // You have a SPI master peripheral with a single SS output //
  // you might have to do something creative to generate the //
  // 5 individual SS needed (3 AFE, 1 Trigger, 1 EEP)       //
  ///////////////////////////////////////////////////////////
    always_comb begin
        EEP_ss_n = 1;
        ch1_ss_n = 1;
        ch2_ss_n = 1;
        ch3_ss_n = 1;
        trig_ss_n = 1;
        case(ss)
            SS_EEPROM: EEP_ss_n = SS_n;
            SS_CH1: ch1_ss_n = SS_n;
            SS_CH2: ch2_ss_n = SS_n;
            SS_CH3: ch3_ss_n = SS_n;
            SS_TRIGGER: trig_ss_n = SS_n;
            default: EEP_ss_n = 1;
        endcase
    end
  
  ///////////////////////////////////
  // Instantiate UART_comm module //
  /////////////////////////////////
  UART_comm comm(clk, rst_n, RX, TX, clr_cmd_rdy, cmd_rdy, cmd, trmt, tx_data, tx_done);
				    
  ///////////////////////////
  // Instantiate dig_core //
  /////////////////////////
  dig_core core(clk,rst_n,adc_clk,trig1,trig2,SPI_data,wrt_SPI,SPI_done,nxt_ss,EEP_data,
                  rclk,en,we,addr,ch1_rdata,ch2_rdata,ch3_rdata,cmd,cmd_rdy,clr_cmd_rdy,
                  tx_data,trmt,tx_done);

  //////////////////////////////////////////////////////////////
  // Instantiate the 3 512 RAM blocks that store A2D samples //
  ////////////////////////////////////////////////////////////
  RAM512 iRAM1(.rclk(rclk),.en(en),.we(we),.addr(addr),.wdata(ch1_data),.rdata(ch1_rdata));
  RAM512 iRAM2(.rclk(rclk),.en(en),.we(we),.addr(addr),.wdata(ch2_data),.rdata(ch2_rdata));
  RAM512 iRAM3(.rclk(rclk),.en(en),.we(we),.addr(addr),.wdata(ch3_data),.rdata(ch3_rdata));

endmodule
  
