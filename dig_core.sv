module dig_core(clk,rst_n,adc_clk,trig1,trig2,SPI_data,wrt_SPI,SPI_done,ss,EEP_data,
                rclk,en,we,addr,ch1_rdata,ch2_rdata,ch3_rdata,cmd,cmd_rdy,clr_cmd_rdy,
                resp_data,send_resp,resp_sent);
                
  input clk,rst_n;                              // clock and active low reset
  output logic adc_clk,rclk;                    // 20MHz clocks to ADC and RAM
  input trig1,trig2;                            // trigger inputs from AFE
  output logic [15:0] SPI_data;                 // typically a config command to digital pots or EEPROM
  output logic wrt_SPI;                         // control signal asserted for 1 clock to initiate SPI transaction
  output SlaveSelect ss;                        // determines which Slave gets selected 000=>trig, 001-011=>chX_ss, 100=>EEP
  input SPI_done;                               // asserted by SPI peripheral when finished transaction
  input [7:0] EEP_data;                         // Formed from MISO from EEPROM.  only lower 8-bits needed from SPI periph
  output logic en,we;                           // RAM block control signals (common to all 3 RAM blocks)
  output logic [8:0] addr;                      // Address output to RAM blocks (common to all 3 RAM blocks)
  input [7:0] ch1_rdata,ch2_rdata,ch3_rdata;    // data inputs from RAM blocks
  input [23:0] cmd;                             // 24-bit command from HOST
  input cmd_rdy;                                // tell core command from HOST is valid
  output logic clr_cmd_rdy;
  output logic [7:0] resp_data;                 // response byte to HOST
  output logic send_resp;                       // control signal to UART comm block that initiates a response
  input resp_sent;                              // input from UART comm block that indicates response finished sending
  
  //////////////////////////////////////////////////////////////////////////
  // Interconnects between modules...declare any wire types you need here//
  ////////////////////////////////////////////////////////////////////////
    
  // TwoTrigger interconnects
  logic armed;
  logic trigger;
  logic [5:0] trig_cfg;
 
  // cmd_module <-> Capture interconnects
  logic start_dump;
  logic dump_channel;
  logic dump_data;
  logic send_dump;
  logic dump_finished;
  logic set_capture_done;


  ///////////////////////////////////////////////////////
  // Instantiate the blocks of your digital core next //
  /////////////////////////////////////////////////////

  TwoTrigger tt(clk, rst_n, trig_cfg[0], trig_cfg[2], trig_cfg[4] ,armed, trig1, trig2, trig_cfg[5], trigger);

  Capture capture1(clk,
                   rst_n,
                   trigger,
                   en,
                   we,
                   addr,
                   start_dump,
                   dump_channel,
                   dump_data,
                   send_dump,
                   dump_finished,
                   armed);

  cmd_module c(clk,
               rst_n,
               cmd,
               cmd_rdy,
               clr_cmd_rdy,
               resp_data,
               send_resp,
               resp_sent,
               ss,
               wrt_SPI,
               SPI_data,
               EEP_data,
               SPI_done,
               // Extra connections
               // Capture options for help dumping
               start_dump, // output to Capture
               dump_channel, // output to Capture
               dump_data, // input [7:0] from Capture
               send_dump, // input from Capture
               dump_finished, // input from Capture
               set_capture_done, // input from Capture for trigger
               // Trigger options for help triggering
               trig_cfg, // output [5:0] to trigger
               );

endmodule
