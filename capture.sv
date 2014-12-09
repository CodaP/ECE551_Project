module Capture(clk, rst_n, trigger, en, we, addr, start_dump, dump_channel, dump_data, send_dump, dump_finished, armed, trig_cfg, decimator, trig_pos);
    input logic clk,rst_n;
    input logic trigger;
    output logic en;
    output logic we;
    output logic [8:0] addr;
    input logic start_dump;
    input logic [1:0] dump_channel;
    output logic [7:0] dump_data;
    output logic send_dump;
    output logic dump_finished;
    output logic armed;
    input logic [5:0] trig_cfg;
    input logic [3:0] decimator;
    input logic [8:0] trig_pos;

endmodule
