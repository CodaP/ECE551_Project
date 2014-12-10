module Capture(clk, rst_n, rclk, trigger, trig_type, en, we, addr, start_dump, send_dump, dump_sent, dump_finished, armed, dec_pwr, trig_pos, capture_done, set_capture_done);
    input logic clk,rst_n;
    input logic rclk;
    input logic trigger;
    input [1:0] trig_type;
    input logic[8:0] trig_pos;
    input logic capture_done;
    input logic [3:0] dec_pwr;
    output logic en;
    output logic we;
    output logic [8:0] addr;
    output logic armed;
    output logic set_capture_done;
    input logic start_dump;
    output logic send_dump;
    output logic dump_finished;
    input logic dump_sent;

endmodule
