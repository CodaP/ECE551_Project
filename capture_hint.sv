typedef enum logic [2:0] {CAP_START, SAMP_RPOS, SAMP_RNEG, DUMP_RNEG, DUMP_RPOS, DUMP_SEND} State;
typedef logic[8:0] Address;

module capture_hint(clk, rst_n, rclk, trigger, trig_type, trig_pos, capture_done, dec_pwr,
        en, we, addr, armed, set_capture_done,

        start_dump, dump_sent,
        send_dump, dump_finished);

    State state;
    State nxt_state;

    input clk, rst_n; // Clock and active-low asynchronous reset
    input rclk; // The ram clock
    input trigger; // The trigger
    input [1:0] trig_type; // The trigger type
    input Address trig_pos; // The number of triggers for a single capture cycle
    input capture_done; // Whether the system is ready to start capturing again
    input [3:0] dec_pwr; // The sampling decimator
    output logic en; // Enable the ram
    output logic we; // Write the ram if enabled
    output Address addr; // The ram address to write to
    output logic armed; // Is trigger armed?
    output logic set_capture_done; // Should capture_done be set?

    input start_dump; // Whether a dump should begin
    input dump_sent;
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
    Address trace_end, next_trace_end; // The last sample to be captured

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

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            dec_cnt <= 0;
        else
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

    always_ff @(posedge clk)
        trace_end <= next_trace_end;

    always_comb begin
        next_trig_cnt = trig_cnt;
        next_smpl_cnt = smpl_cnt;
        next_addr = addr;
        next_dec_cnt = dec_cnt;
        next_armed = armed;
        next_trace_end = trace_end;
        set_capture_done = 0;
        send_dump = 0;
        dump_finished = 0;
        we = 0;
        en = 0;
        if (start_dump) begin
            if (rclk) begin
                nxt_state = DUMP_RNEG;
                next_addr = trace_end + 1;
            end else begin
                nxt_state = DUMP_RPOS;
                next_addr = trace_end;
            end
        end else begin
            case(state)
                CAP_START: begin
                    nxt_state = CAP_START;
                    if (!capture_done) begin
                        if (|trig_type & ~rclk) begin
                            nxt_state = SAMP_RPOS;
                            next_trig_cnt = 0;
                            next_smpl_cnt = 0; // TODO:[opt] having both trig_cnt and smpl_cnt is redundant
                            next_dec_cnt = 0;
                        end
                    end
                end
                SAMP_RPOS: begin
                    nxt_state = SAMP_RNEG;
                    next_dec_cnt = dec_cnt + 1;
                    next_addr = keep_ff ? addr + 1 : addr;
                    we = keep_ff;
                    en = keep_ff;
                end
                SAMP_RNEG: begin
                    if(trig_cnt == trig_pos) begin
                        nxt_state = CAP_START;
                        set_capture_done = 1;
                        next_trace_end = addr;
                        next_armed = 0;
                    end else begin
                        nxt_state = SAMP_RPOS;
                        en = keep;
                        we = keep;
                        if (keep) begin
                            next_dec_cnt = 0;
                            if (trigger || autoroll && armed) begin
                                next_trig_cnt = trig_cnt + 1;
                            end else begin
                                next_smpl_cnt = smpl_cnt + 1;
                                if (smpl_cnt + trig_pos == 10'h200)
                                    next_armed = 1;
                            end
                        end
                    end
                end
                DUMP_RPOS: begin
                    nxt_state = DUMP_RNEG;
                    next_addr = addr + 1;
                    en = 1;
                end
                DUMP_RNEG: begin
                    nxt_state = DUMP_SEND;
                    en = 1;
                end
                DUMP_SEND: begin
                    en = 1;
                    if (dump_sent) begin
                        if (addr == trace_end) begin
                            nxt_state = CAP_START;
                            dump_finished = 1;
                        end else begin
                            if (rclk) begin
                                nxt_state = DUMP_RNEG;
                                next_addr = addr + 1;
                            end else
                                nxt_state = DUMP_RPOS;
                        end
                    end else begin
                        nxt_state = DUMP_SEND;
                        send_dump = 1;
                    end
                end
                default:
                    nxt_state = CAP_START;
            endcase
        end
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
    logic set_capture_done; // Output
    logic trigger;
    logic [1:0] trig_type;
    logic [3:0] dec_pwr;
    Address trig_pos;
    logic capture_done;

    logic start_dump;
    logic dump_sent;
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
    .capture_done(capture_done),
    .set_capture_done(set_capture_done),

    .start_dump(start_dump),
    .dump_sent(dump_sent),
    .send_dump(send_dump),
    .dump_finished(dump_finished)
    );

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            dump_sent <= 0;
        else
            dump_sent <= send_dump;

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            capture_done <= 0;
        else
            if (set_capture_done)
                capture_done <= 1;

    initial begin
        clk = 1;
        rclk = 0;
        rst_n = 0;
        trigger = 0;
        dec_pwr = 2;
        trig_type = 1;
        trig_pos = 100;
        capture_done = 0;

        start_dump = 0;

        @(negedge clk) rst_n = 1;
        while(!armed) @(posedge clk);
        trigger = 1;
        while(!capture_done) @(posedge clk);
        trigger = 0;
        repeat(20) @(posedge clk);
        start_dump = 1;
        @(posedge clk);
        start_dump = 0;
        while(!dump_finished) @(posedge clk);
        repeat(20) @(posedge clk);

        $stop;

    end

    always #1 clk <= ~clk;
    always #2 rclk <= ~rclk;

endmodule
