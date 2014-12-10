module dig_core(clk,rst_n,adc_clk,trig1,trig2,SPI_data,wrt_SPI,SPI_done,ss,EEP_data,
                rclk,en,we,addr,ch1_rdata,ch2_rdata,ch3_rdata,cmd,cmd_rdy,clr_cmd_rdy,
                resp_data,send_resp,resp_sent);

    input clk,rst_n;                              // clock and active low reset
    output logic adc_clk,rclk;                    // 20MHz clocks to ADC and RAM
    input trig1,trig2;                            // trigger inputs from AFE
    output logic [15:0] SPI_data;                 // typically a config command to digital pots or EEPROM
    output logic wrt_SPI;                         // control signal asserted for 1 clock to initiate SPI transaction
    output logic [2:0] ss;                        // determines which Slave gets selected 000=>trig, 001-011=>chX_ss, 100=>EEP
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
    logic [1:0] dump_channel;
    logic [7:0] dump_data;
    logic send_dump;
    logic dump_finished;
    logic set_capture_done;
    logic [3:0] decimator;
    logic [8:0] trig_pos;

    assign dump_data = (dump_channel == 0) ? ch1_rdata:
                       (dump_channel == 1) ? ch2_rdata:
                                             ch3_rdata;

    ///////////////////////////////////////////////////////
    // Instantiate the blocks of your digital core next //
    /////////////////////////////////////////////////////

    ClkGen clocker(
        .clk(clk),
        .rst_n(rst_n),
        .posclk(rclk),
        .negclk(adc_clk)
    );

    TwoTrigger triggerer(
        .clk(clk),
        .rst_n(rst_n),
        .trigger_source(trig_cfg[0]),
        .trig_en(trig_cfg[2]),
        .pos_edge(trig_cfg[4]),
        .armed(armed),
        .trig1(trig1),
        .trig2(trig2),
        .set_capture_done(set_capture_done),
        .trigger(trigger)
    );

    Capture capturer(
        .clk(clk),
        .rst_n(rst_n),
        .rclk(rclk),
        .trigger(trigger),
        .trig_type(trig_cfg[3:2]),
        .trig_pos(trig_pos),
        .capture_done(trig_cfg[5]),
        .dec_pwr(decimator),
        .en(en),
        .we(we),
        .addr(addr),
        .armed(armed),
        .set_capture_done(set_capture_done),
        .start_dump(start_dump),
        .dump_sent(resp_sent),
        .send_dump(send_dump),
        .dump_finished(dump_finished)
    );

    cmd_module cmdr(
        .clk(clk),
        .rst_n(rst_n),
        .cmd(cmd),
        .cmd_rdy(cmd_rdy),
        .clr_cmd_rdy(clr_cmd_rdy),
        .resp_data(resp_data),
        .send_resp(send_resp),
        .ss(ss),
        .wrt_SPI(wrt_SPI),
        .SPI_data(SPI_data),
        .EEP_data(EEP_data),
        .SPI_done(SPI_done),
        //Dumping
        .start_dump(start_dump), // output to Capture
        .dump_channel(dump_channel), // output [1:0] to Capture
        .dump_data(dump_data), // input [7:0] from Capture
        .send_dump(send_dump), // input from Capture
        .dump_finished(dump_finished), // input from Capture
        //Triggering
        .set_capture_done(set_capture_done), // input from Capture for trigger
        .trig_cfg(trig_cfg), // output [5:0] to trigger
        .decimator(decimator),
        .trig_pos(trig_pos)
    );

endmodule

