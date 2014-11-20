module Trigger(clk,rst_n,trig_set,armed,trig_en,set_capture_done,trigger);
	input clk;
	input rst_n;
	input trig_set;
	input armed;
	input trig_en;
	input set_capture_done;

	output logic trigger;
	logic next_trigger;

	always_ff @(posedge clk or negedge rst_n) begin
		if(rst_n) begin
			trigger <= next_trigger;
		end else begin
			trigger <= 0;
		end
	end

	always_comb begin
		if (set_capture_done)
			next_trigger = 0;
		else
			next_trigger = trigger || (armed && trig_en && trig_set);
	end

endmodule

module DetectTrigger(clk,rst_n,trigger1,trigger2,trigger_source,trig_set,pos_edge);
	input clk;
	input rst_n;
	input trigger1;
	input trigger2;
	input trigger_source;
	output logic trig_set;
	input pos_edge;

	logic source;
	assign source = trigger_source ? trigger2 : trigger1;

	// Triple flop
	logic source_stable;

	logic posEdge;
	logic negEdge;

	DetectStableEdge s1(clk,rst_n,source,source_stable,_,posEdge,negEdge);

	assign trig_set = pos_edge ? posEdge:negEdge;

endmodule

module TwoTrigger(clk, rst_n, trigger_source, trig_en, pos_edge, armed, trig1, trig2, set_capture_done, trigger);
    input clk;
    input rst_n;
    input trigger_source;
    input trig_en;
    input pos_edge;
    input armed;
    input trig1;
    input trig2;
    input set_capture_done;
    output logic trigger;

    logic trig_set;

    DetectTrigger dt(clk, rst_n, trig1, trig2, trigger_source, trig_set, pos_edge);
    Trigger trigger1(clk, rst_n, trig_set, armed, trig_en, set_capture_done, trigger);

endmodule
