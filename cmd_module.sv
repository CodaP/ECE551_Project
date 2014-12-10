`include "types.h"

module cmd_module(clk, rst_n, cmd, cmd_rdy, clr_cmd_rdy, resp_data, send_resp, ss, wrt_SPI, SPI_data, EEP_data, SPI_done,
                // Extra ports
               start_dump, dump_channel, dump_data, send_dump, dump_finished, set_capture_done, trig_cfg, decimator, trig_pos);
	
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
    localparam ACK = 8'hA5;
    localparam NACK = 8'hEE;

	input clk, rst_n;
	//Connections to the UART command aggregator
	input[23:0] cmd;
	input cmd_rdy;
	output logic clr_cmd_rdy;
	output logic[7:0] resp_data;
	output logic send_resp;
	//Connections to the SPI module and related logic
	output SlaveSelect ss;
	output logic wrt_SPI;
	output logic[15:0] SPI_data;
	input[7:0] EEP_data;
	input SPI_done;

    //Extra ports
    output logic start_dump; // output to Capture
    output logic [1:0] dump_channel; // output to Capture
    input [7:0] dump_data; // input [7:0] from Capture
    input send_dump; // input from Capture
    input dump_finished; // input from Capture
    input set_capture_done; // input from Capture for trigger
    // Trigger options for help triggering
    output logic [5:0] trig_cfg; // output [5:0] to trigger
    logic [5:0] nxt_trig_cfg;
    output logic [3:0] decimator;
    logic [3:0] nxt_decimator;
    output logic [8:0] trig_pos;
    logic [8:0] nxt_trig_pos;

    typedef enum logic [2:0] { DISPATCH_CMD, WRT_EEP, RD_EEP_0, RD_EEP_1, RD_EEP_2, DUMP_STATE } State;

    State state;
    State nxt_state;

    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            state <= DISPATCH_CMD;
        else
            state <= nxt_state;
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            decimator <= 0;
        else
            decimator <= nxt_decimator;
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            trig_cfg <= 0;
        else
            trig_cfg <= {~set_capture_done & nxt_trig_cfg[5], nxt_trig_cfg[4:0]};
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            trig_pos <= 0;
        else
            trig_pos <= nxt_trig_pos;
    end

    always_comb begin
        clr_cmd_rdy = 0;
        resp_data = 8'hxx;
        send_resp = 0;
        ss = SS_NONE;
        wrt_SPI = 0;
        SPI_data = 16'hxxxx;
        nxt_state = DISPATCH_CMD;
        nxt_decimator = decimator;
        nxt_trig_pos = trig_pos;
        nxt_trig_cfg = trig_cfg;
        start_dump = 0;
        dump_channel = 0;
        case(state)
            // Direct SM to handle cmd
            DISPATCH_CMD:
                if(cmd_rdy) begin
                    clr_cmd_rdy = 1;
                    case(cmd[19:16])
                        DUMP: begin
                            nxt_state = DUMP_STATE;
                            start_dump = 1;
                            dump_channel = cmd[9:8];
                        end
                        SET_TRIGPOS: begin
                            nxt_trig_pos = cmd[8:0];
                            resp_data = ACK;
                            send_resp = 1;
                        end
                        SET_DEC: begin
                            nxt_decimator = cmd[3:0];
                            resp_data = ACK;
                            send_resp = 1;
                        end
                        SET_TRIG_CFG: begin
                            nxt_trig_cfg = cmd[13:8];
                            resp_data = ACK;
                            send_resp = 1;
                        end
                        READ_TRIG_CFG: begin
                            resp_data = trig_cfg;
                            send_resp = 1;
                        end

                        CONFIG_GAIN:begin
                            nxt_state = WRT_EEP;
                            wrt_SPI = 1;

                            // Decode cc
                            case(cmd[9:8])
                                // Channel 1
                                2'b00:
                                    ss = SS_CH1;
                                // Channel 2
                                2'b01:
                                    ss = SS_CH2;
                                // Channel 3
                                default: begin
                                    ss = SS_CH3;
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
                            nxt_state = WRT_EEP;
                            SPI_data = {8'h13,cmd[7:0]};
                            ss = SS_TRIGGER;
                            wrt_SPI = 1;
                        end
                        WRITE_EEPROM:begin
                            nxt_state = WRT_EEP;
                            wrt_SPI = 1;
                            ss = SS_EEPROM;
                            // Write to EEPROM cmd[13:8] (addr) cmd[7:0] (data)
                            SPI_data = {2'b01, cmd[13:0]};
                        end
                        READ_EEPROM:begin
                            nxt_state = RD_EEP_0;
                            wrt_SPI = 1;
                            ss = SS_EEPROM;
                            // Read from EEPROM cmd[13:8] (addr) cmd[7:0] (data)
                            SPI_data = {2'b00, cmd[13:8],8'hxx};
                        end
                        default: nxt_state = DISPATCH_CMD;
                    endcase
                end
                else
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

            // Read from EEPROM
            RD_EEP_0:begin
                if(SPI_done) begin
                    nxt_state = RD_EEP_1;
                    wrt_SPI = 1;
                    ss = SS_NONE;
                    SPI_data = {2'b00, 14'h0000};
                end
                else
                    nxt_state = RD_EEP_0;

            end

            RD_EEP_1:begin
                if(SPI_done) begin
                    nxt_state = RD_EEP_2;
                    wrt_SPI = 1;
                    ss = SS_EEPROM;
                    SPI_data = {2'b00, 14'h0000};
                end
                else
                    nxt_state = RD_EEP_1;

            end

            // Read from EEPROM
            RD_EEP_2:begin
                if(SPI_done) begin
                    nxt_state = DISPATCH_CMD;
                    resp_data = EEP_data;
                    send_resp = 1;
                end
                else
                    nxt_state = RD_EEP_2;
            end
            DUMP_STATE:begin
                // Need Flow control with the UART
                if(send_dump) begin
                    resp_data = dump_data;
                    send_resp = 1;
                    nxt_state = DUMP_STATE;
                end
                else if(dump_finished) begin
                    nxt_state = DISPATCH_CMD;
                end
                else begin
                    nxt_state = DUMP_STATE;
                end

            end

            default: nxt_state = DISPATCH_CMD;

        endcase

    end

endmodule
