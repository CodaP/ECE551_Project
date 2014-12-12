`include "types.h"

module cmd_module(clk, rst_n, cmd, cmd_rdy, clr_cmd_rdy, resp_data, send_resp, ss, wrt_SPI, SPI_data, EEP_data, SPI_done,
                // Extra ports
               start_dump, dump_channel, dump_data, send_dump, dump_finished, set_capture_done, trig_cfg, decimator, trig_pos);
	
    // Enumerations for the types of commands available
    enum logic [7:0] {  DUMP          = 8'h01,
                        CONFIG_GAIN   = 8'h02,
                        SET_TRIGGER   = 8'h03,
                        SET_TRIGPOS   = 8'h04,
                        SET_DEC       = 8'h05,
                        SET_TRIG_CFG  = 8'h06,
                        READ_TRIG_CFG = 8'h07,
                        WRITE_EEPROM  = 8'h08,
                        READ_EEPROM   = 8'h09
    } Opcode; 

    // Typical responses to a command
    localparam ACK = 8'hA5;
    localparam NACK = 8'hEE;

	input clk, rst_n;
	//Connections to the UART command aggregator
	input[23:0] cmd; //Received data
	input cmd_rdy; // data was received and is in cmd
	output logic clr_cmd_rdy; // Done reading cmd
	output logic[7:0] resp_data; // Data to transmit
	output logic send_resp; // Transmit resp_data
	//Connections to the SPI module and related logic
	output SlaveSelect ss; // Which slave spi devices to connect
	output logic wrt_SPI; // initiate a SPI transaction
	output logic[15:0] SPI_data; // Data to transmit via SPI
	input[7:0] EEP_data; // Response data from slave
	input SPI_done; // EEP_data is ready to read

    //Extra ports
    output logic start_dump; // output to Capture, start the dump
    output logic [1:0] dump_channel; // output to RAM mux in dig_core
    logic [1:0] nxt_dump_channel; // next value of dump_channel
    input [7:0] dump_data; // line in from RAM mux in dig_core
    input send_dump; // Signal from capture that memory is set to next sample
    input dump_finished; // Signal from capture that the dump is complete
    input set_capture_done; // signal from capture that capture is done
    // Trigger options for help triggering
    output logic [5:0] trig_cfg; // configuration register for trigger
    logic [5:0] nxt_trig_cfg;
    output logic [3:0] decimator; // decimator register
    logic [3:0] nxt_decimator;
    output logic [8:0] trig_pos; // Trig_pos register
    logic [8:0] nxt_trig_pos;

    logic [2:0] ch1_ggg; // cached ch1 AFE gain setting
    logic [2:0] nxt_ch1_ggg; 
    logic [2:0] ch2_ggg; // cached ch2 AFE gain setting
    logic [2:0] nxt_ch2_ggg;
    logic [2:0] ch3_ggg; // cached ch3 AFE gain setting
    logic [2:0] nxt_ch3_ggg;

    logic signed [7:0] offset; // register storing offet component of correction
    logic signed [7:0] nxt_offset;
    logic [7:0] gain; // register storing gain component of correction
    logic [7:0] nxt_gain;

    logic [7:0] corrected; // corrected dump_data

    // Correction module
    Correction correction(dump_data,offset,gain,corrected);

    // enumeration of cmd_module states
    typedef enum logic [3:0] { DISPATCH_CMD, WRT_EEP, RD_EEP_0, RD_EEP_1, RD_EEP_2, DUMP_STATE, DUMP_TX_OFFSET_REQUEST, DUMP_STALL_OFFSET, DUMP_TX_GAIN_REQUEST, DUMP_STALL_GAIN, DUMP_TX_GARBAGE_REQUEST } State;

    State state;
    State nxt_state;

    // Offset flop
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            offset <= 0;
        else
            offset <= nxt_offset;
    end

    // Gain flop
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            gain <= 0;
        else
            gain <= nxt_gain;
    end

    // dump_channel flop
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            dump_channel <= 0;
        else
            dump_channel <= nxt_dump_channel;
    end


    // State flop
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            state <= DISPATCH_CMD;
        else
            state <= nxt_state;
    end

    // Ch1 AFE gain flop
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            ch1_ggg <= 0;
        else
            ch1_ggg <= nxt_ch1_ggg;
    end

    // Ch2 AFE gain flop
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            ch2_ggg <= 0;
        else
            ch2_ggg <= nxt_ch2_ggg;
    end

    // Ch3 AFE gain flop
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            ch3_ggg <= 0;
        else
            ch3_ggg <= nxt_ch3_ggg;
    end

    // decimator flop
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            decimator <= 0;
        else
            decimator <= nxt_decimator;
    end

    // trig_cfg flop
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            trig_cfg <= 0;
        // capture_done bit has a synchronous preset
        else
            trig_cfg <= {set_capture_done | nxt_trig_cfg[5], nxt_trig_cfg[4:0]};
    end

    // trig_pos flop
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            trig_pos <= 0;
        else
            trig_pos <= nxt_trig_pos;
    end

    always_comb begin
        // Combination signal defaults
        clr_cmd_rdy = 0;
        resp_data = 8'hxx;
        send_resp = 0;
        ss = SS_NONE;
        wrt_SPI = 0;
        SPI_data = 16'h0xxx;
        nxt_state = DISPATCH_CMD;
        nxt_decimator = decimator;
        nxt_trig_pos = trig_pos;
        nxt_trig_cfg = trig_cfg;
        nxt_ch1_ggg = ch1_ggg;
        nxt_ch2_ggg = ch2_ggg;
        nxt_ch3_ggg = ch3_ggg;
        nxt_offset = offset;
        nxt_gain = gain;
        start_dump = 0;
        nxt_dump_channel = dump_channel;
        case(state)
            // Direct SM to handle cmd
            DISPATCH_CMD:
                if(cmd_rdy) begin
                    clr_cmd_rdy = 1;
                    // Only need to switch on the Opcode portion of cmd
                    case(cmd[19:16])
                        // Initiate a dump
                        DUMP: begin
                            // First we will read offset and gain from EEPROM
                            nxt_state = DUMP_TX_OFFSET_REQUEST;
                            // Configure channel
                            nxt_dump_channel = cmd[9:8];
                            wrt_SPI = 1;
                            ss = SS_EEPROM;
                            // Read offset from EEPROM cmd[13:8] (addr) cmd[7:0] (data)
                            if(nxt_dump_channel == 0)
                                SPI_data = {2'b00, nxt_dump_channel, ch1_ggg, 1'b0, 8'hxx};
                            else if(nxt_dump_channel == 1)
                                SPI_data = {2'b00, nxt_dump_channel, ch2_ggg, 1'b0, 8'hxx};
                            else 
                                SPI_data = {2'b00, nxt_dump_channel, ch3_ggg, 1'b0, 8'hxx};
                        end
                        SET_TRIGPOS: begin
                            // Load a new trig_pos
                            nxt_trig_pos = cmd[8:0];
                            // Send ACK
                            resp_data = ACK;
                            send_resp = 1;
                        end
                        SET_DEC: begin
                            // Load a new decimator
                            nxt_decimator = cmd[3:0];
                            // Send ACK
                            resp_data = ACK;
                            send_resp = 1;
                        end
                        SET_TRIG_CFG: begin
                            // Load a new trig_cfg
                            nxt_trig_cfg = cmd[13:8];
                            // Send ACK
                            resp_data = ACK;
                            send_resp = 1;
                        end
                        READ_TRIG_CFG: begin
                            // Transmit trig_cfg
                            resp_data = trig_cfg;
                            send_resp = 1;
                        end

                        CONFIG_GAIN:begin
                            // Send a SPI write to digital potentiometer
                            nxt_state = WRT_EEP;
                            wrt_SPI = 1;

                            // Decode cc
                            case(cmd[9:8])
                                // Channel 1
                                2'b00:begin
                                    ss = SS_CH1;
                                    nxt_ch1_ggg = cmd[12:10];
                                end
                                // Channel 2
                                2'b01: begin
                                    ss = SS_CH2;
                                    nxt_ch2_ggg = cmd[12:10];
                                end
                                // Channel 3
                                default: begin
                                    ss = SS_CH3;
                                    nxt_ch3_ggg = cmd[12:10];
                                end
                            endcase

                            // Decode ggg
                            case(cmd[12:10])
                                3'h0: SPI_data = 16'h1302;
                                3'h1: SPI_data = 16'h1305;
                                3'h2: SPI_data = 16'h1309;
                                3'h3: SPI_data = 16'h1314;
                                3'h4: SPI_data = 16'h1328;
                                3'h5: SPI_data = 16'h1346;
                                3'h6: SPI_data = 16'h136b;
                                3'h7: SPI_data = 16'h13dd;
                                default: SPI_data = 16'hxxxx;
                            endcase

                        end
                        SET_TRIGGER:begin
                            // Configure the trigger over SPI
                            nxt_state = WRT_EEP;
                            SPI_data = {8'h13,cmd[7:0]};
                            ss = SS_TRIGGER;
                            wrt_SPI = 1;
                        end
                        WRITE_EEPROM:begin
                            // Write to an address in EEPROM
                            nxt_state = WRT_EEP;
                            wrt_SPI = 1;
                            ss = SS_EEPROM;
                            // Write to EEPROM cmd[13:8] (addr) cmd[7:0] (data)
                            SPI_data = {2'b01, cmd[13:0]};
                        end
                        READ_EEPROM:begin
                            // Read from an address in EEPROM
                            nxt_state = RD_EEP_0;
                            wrt_SPI = 1;
                            ss = SS_EEPROM;
                            // Read from EEPROM cmd[13:8] (addr) cmd[7:0] (data)
                            SPI_data = {2'b00, cmd[13:8],8'hxx};
                        end
                        default: begin
                            // Unused command
                            nxt_state = DISPATCH_CMD;
                            // Send NACK
                            resp_data = NACK;
                            send_resp = 1;
                        end
                    endcase
                end
                else
                    // Wait for cmd_rdy
                    nxt_state = DISPATCH_CMD;
            // Write to EEPROM
            WRT_EEP:begin
                if(SPI_done) begin
                    nxt_state = DISPATCH_CMD;
                    resp_data = ACK;
                    send_resp = 1;
                end
                else
                    nxt_state = WRT_EEP;
            end

            // Read garbage from EEPROM
            RD_EEP_0:begin
                if(SPI_done) begin
                    // When done waiting send a bogus transaction to nobody
                    // Used to wait for EEPROM to read
                    nxt_state = RD_EEP_1;
                    wrt_SPI = 1;
                    ss = SS_NONE;
                    SPI_data = {2'b00, 14'h0000};
                end
                else
                    nxt_state = RD_EEP_0;
            end

            // Stall during a phony transaction used for timing
            RD_EEP_1:begin
                if(SPI_done) begin
                    // When done issue another bogus read
                    // This time to the EEPROM
                    nxt_state = RD_EEP_2;
                    wrt_SPI = 1;
                    ss = SS_EEPROM;
                end
                else
                    nxt_state = RD_EEP_1;

            end

            // Read data from EEPROM while bogus read goes out
            RD_EEP_2:begin
                if(SPI_done) begin
                    // When done set UART response to received data
                    nxt_state = DISPATCH_CMD;
                    resp_data = EEP_data;
                    send_resp = 1;
                end
                else
                    nxt_state = RD_EEP_2;
            end
            // Wait for request to EEPROM for offset to complete
            DUMP_TX_OFFSET_REQUEST: begin
                nxt_state = DUMP_TX_OFFSET_REQUEST;
                if(SPI_done) begin
                    // When done waiting issue a phony request to nobody
                    wrt_SPI = 1;
                    nxt_state = DUMP_STALL_OFFSET;
                    ss = SS_NONE;
                end
            end

            // Wait for phony request to complete
            DUMP_STALL_OFFSET: begin
                nxt_state = DUMP_STALL_OFFSET;
                if(SPI_done) begin
                    // When completed start a request for gain
                    wrt_SPI = 1;
                    nxt_state = DUMP_TX_GAIN_REQUEST;
                    ss = SS_EEPROM;
                    if(dump_channel == 0)
                        SPI_data = {2'b00, dump_channel, ch1_ggg, 1'b1, 8'hxx};
                    else if(dump_channel == 1)
                        SPI_data = {2'b00, dump_channel, ch2_ggg, 1'b1, 8'hxx};
                    else 
                        SPI_data = {2'b00, dump_channel, ch3_ggg, 1'b1, 8'hxx};
                end
            end
            // Wait for gain request to complete. Also receive offset data
            // from before
            DUMP_TX_GAIN_REQUEST: begin
                nxt_state = DUMP_TX_GAIN_REQUEST;
                if(SPI_done) begin
                    // When finished we have the offset data
                    // Kickoff another stall
                    wrt_SPI = 1;
                    ss = SS_NONE;
                    nxt_state = DUMP_STALL_GAIN;
                    nxt_offset = EEP_data;
                end
            end
            // Wait for bogus request to complete
            DUMP_STALL_GAIN: begin
                nxt_state = DUMP_STALL_GAIN;
                if(SPI_done) begin
                    // Start a garbage request
                    wrt_SPI = 1;
                    ss = SS_EEPROM;
                    nxt_state = DUMP_TX_GARBAGE_REQUEST;
                end
            end
            // Wait for garbage reqeust to complete before grabbing the gain
            // data the came in during it.
            DUMP_TX_GARBAGE_REQUEST: begin
                nxt_state = DUMP_TX_GARBAGE_REQUEST;
                if(SPI_done) begin
                    // When done set the gain and begin dump
                    nxt_state = DUMP_STATE;
                    nxt_gain = EEP_data;
                    start_dump = 1;
                end
            end
            // Let capture do it's thing
            // We send when it tells us to send
            DUMP_STATE:begin
                if(send_dump) begin
                    // Send corrected sample
                    resp_data = corrected;
                    send_resp = 1;
                    nxt_state = DUMP_STATE;
                end
                else if(dump_finished) begin
                    // Finish dump
                    nxt_state = DISPATCH_CMD;
                end
                else begin
                    // Wait for send_dump or dump_finished
                    nxt_state = DUMP_STATE;
                end

            end

            default: nxt_state = DISPATCH_CMD;

        endcase

    end

endmodule
