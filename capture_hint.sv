typedef enum logic [1:0] {CAP_START, SAMP1, SAMP2, DONE} State;
typedef logic[8:0] Address;

module capture_hint(clk, rst_n, rclk, trigger, trig_type, trig_pos, dec_pwr,
        en, we, addr, armed,
        
        start_dump,
        send_dump, dump_finished);

    State state;
    State nxt_state;

    input clk, rst_n; // Clock and active-low asynchronous reset
    input rclk; // The ram clock
    input trigger; // The trigger
    input [1:0] trig_type; // The trigger type
    input Address trig_pos; // The number of triggers for a single capture cycle
    input [3:0] dec_pwr; // The sampling decimator
    output logic en; // Enable the ram
    output logic we; // Write the ram if enabled
    output Address addr; // The ram address to write to
    output logic armed; // Is trigger armed?

    input start_dump; // Whether a dump should begin
    output logic send_dump; // Whether dump_data is valid
    output logic dump_finished; // Whether the dump is finished

    logic autoroll; // Whether the trigger is on autoroll

    logic next_armed; // The next value for the armed register
    logic [15:0] dec_cnt, next_dec_cnt; // The decimator counter
    logic keep; // Whether a value should be kept
    logic keep_ff; // The preserved value of keep from last cycle
    Address next_addr; // The next value of the addr register
    Address trig_cnt, next_trig_cnt; // The trigger count
    Address smpl_cnt, next_smpl_cnt; // The sample count

    assign autoroll = trig_type[1];

    always_ff @(posedge clk, negedge rst_n)
        if(!rst_n)
            state <= CAP_START;
        else
            state <= nxt_state;

    always_ff @(posedge clk, negedge rst_n)
        if(!rst_n)
            keep_ff <= 1'b0;
        else
            keep_ff <= keep;
 
    assign keep = dec_cnt[dec_pwr];

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            addr <= 0;
        else
            addr <= next_addr;

    always_ff @(posedge clk)
        dec_cnt <= next_dec_cnt;

    always_ff @(posedge clk)
        trig_cnt <= next_trig_cnt;

    always_ff @(posedge clk)
        smpl_cnt <= next_smpl_cnt;

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            armed <= 0;
        else
            armed <= next_armed;

    always_comb begin
        next_trig_cnt = trig_cnt;
        next_smpl_cnt = smpl_cnt;
        next_addr = addr;
        next_dec_cnt = dec_cnt;
        next_armed = armed;
        we = 0;
        en = 0;
        case(state)
            CAP_START: begin
                nxt_state = CAP_START;
                if(|trig_type & ~rclk) begin
                    nxt_state = SAMP1;
                    next_trig_cnt = 0;
                    next_smpl_cnt = 0; // TODO:[opt] having both trig_cnt and smpl_cnt is redundant
                    next_dec_cnt = 0;
                end
            end
            SAMP1: begin
                nxt_state = SAMP2;
                next_dec_cnt = dec_cnt + 1;
                next_addr = keep_ff ? addr + 1 : addr;
                we = keep_ff;
                en = keep_ff;
            end
            SAMP2: begin
                if(trig_cnt == trig_pos) begin
                    nxt_state = DONE;
                    // Finish aquisition
                    //    - Set capture_done
                    //    - Save address pointer in trace_end
                    //      - or use trig_base_addr and use one bit instead of
                    //        a 9-bit subtracter
                    //    - clear armed
                    next_armed = 0;
                    // What happens next?
                    //    1. Wait for capture_done to be cleared
                    //    2. Start again
                    // Maybe go back to CAP_START instead of DONE
                end else begin
                    nxt_state = SAMP1;
                    en = keep;
                    we = keep;
                    if (keep) begin
                        next_dec_cnt = 0;
                        if (trigger || autoroll && armed) begin
                            // TODO:[func] Detect if this is the first trigger and
                            // if so, save off addr as trig_base_addr or
                            // something similar
                            next_trig_cnt = trig_cnt + 1;
                        end else begin
                            next_smpl_cnt = smpl_cnt + 1;
                            if (smpl_cnt + trig_pos == 10'h200)
                                next_armed = 1; // when is armed unset?
                        end
                    end
                end
            end
            DONE:
                nxt_state = CAP_START;
            default:
                nxt_state = CAP_START;
        endcase
    end
endmodule


module capture_hint_tb;
    logic clk;
    logic rst_n;
    logic rclk;
    Address addr; // Output
    logic we; // Output
    logic en; // Output 
    logic armed; // Output
    logic trigger;
    logic [1:0] trig_type;
    logic [3:0] dec_pwr;
    Address trig_pos;

    logic start_dump;
    logic send_dump; // Output
    logic dump_finished; // Output

    capture_hint c1(
    .clk(clk),
    .rst_n(rst_n),
    .rclk(rclk),
    .addr(addr),
    .en(en),
    .we(we),
    .dec_pwr(dec_pwr),
    .trig_type(trig_type),
    .trigger(trigger),
    .trig_pos(trig_pos),
    .armed(armed),

    .start_dump(start_dump),
    .send_dump(send_dump),
    .dump_finished(dump_finished)
    );

    initial begin
        clk = 0;
        rclk = 0;
        rst_n = 0;
        trigger = 0;
        dec_pwr = 2;
        trig_type = 1;
        trig_pos = 100;

        start_dump = 0;
        dump_channel = 0;

        @(negedge clk) rst_n = 1;
        repeat(5) @(negedge rclk);
        trigger = 1;

    end

    always #1 clk <= ~clk;
    always #2 rclk <= ~rclk;
    
endmodule
