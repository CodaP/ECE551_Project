module Capture(clk, rst_n, trigger, en, we, addr, start_dump, dump_channel, dump_data, send_dump, dump_finished, armed);
    input clk,rst_n;
    input trigger;
    output logic en;
    output logic we;
    output logic [8:0] addr;
    input start_dump;
    input [1:0] dump_channel;
    output logic [7:0] dump_data;
    output logic send_dump;
    output logic dump_finished;
    output logic armed;

endmodule
