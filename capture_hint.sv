typedef enum logic [1:0] {WAIT_TRIG, SAMP1, SAMP2, DONE} State;
typedef logic[8:0] Address;

module capture_hint(clk, rst_n, rclk, trigger, trig_type, dec_pwr,
        en, we, addr, armed,
        
        start_dump, dump_channel,
        dump_data, send_dump, dump_finished);

    State state;
    State nxt_state;

    input clk, rst_n;
    input rclk;
    input trigger;
    input [1:0] trig_type;
    input [3:0] dec_pwr;
    output logic en;
    output logic we;
    output Address addr;
    output logic armed;

    input start_dump;
    input [1:0] dump_channel;
    output logic [7:0] dump_data;
    output logic send_dump;
    output logic dump_finished;

    logic autoroll;

    logic next_armed;
    logic [15:0] dec_cnt, next_dec_cnt;
    logic keep;
    logic keep_ff;
    Address next_addr;
    Address trig_pos, next_trig_pos;
    Address trig_cnt, next_trig_cnt;
    Address smpl_cnt, next_smpl_cnt;

    assign autoroll = trig_type[1];

    always_ff @(posedge clk, negedge rst_n)
        if(!rst_n)
            state <= WAIT_TRIG;
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
        trig_pos <= next_trig_pos;

    always_ff @(posedge clk)
        smpl_cnt <= next_smpl_cnt;

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            armed <= 0;
        else
            armed <= next_armed;

    always_comb begin
        next_trig_cnt = trig_cnt;
        next_trig_pos = trig_pos;
        next_smpl_cnt = smpl_cnt;
        next_addr = addr;
        next_dec_cnt = dec_cnt;
        next_armed = armed;
        we = 0;
        en = 0;
        case(state)
            WAIT_TRIG: begin
                nxt_state = WAIT_TRIG;
                if(|trig_type & ~rclk) begin
                    nxt_state = SAMP1;
                    next_trig_cnt = 0;
                    next_smpl_cnt = 0;
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
                    //    - clear armed
                    next_armed = 0;
                    // What happens next?
                    //    1. Wait for capture_done to be cleared
                    //    2. Start again
                    // Maybe go back to WAIT_TRIG instead of DONE
                end else begin
                    nxt_state = SAMP1;
                    en = keep;
                    we = keep;
                    if (keep) begin
                        next_dec_cnt = 0;
                        if (trigger || autoroll && armed)
                            next_trig_cnt = trig_cnt + 1; // Martin doesn't understand this line :( - isn't this in the Trigger module?
                        else begin
                            next_smpl_cnt = smpl_cnt + 1;
                            if (smpl_cnt + trig_pos == 10'h200)
                                next_armed = 1; // when is armed unset?
                        end
                    end
                end
            end
            DONE:
                nxt_state = WAIT_TRIG;
            default: 
                nxt_state = WAIT_TRIG;
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

    logic start_dump;
    logic [1:0] dump_channel;
    logic [7:0] dump_data; // Output
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
    .armed(armed),

    .start_dump(start_dump),
    .dump_channel(dump_channel),
    .dump_data(dump_data),
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

        start_dump = 0;
        dump_channel = 0;

        @(negedge clk) rst_n = 1;
        repeat(5) @(negedge rclk);
        trigger = 1;

    end

    always #1 clk <= ~clk;
    always #2 rclk <= ~rclk;
    
endmodule
