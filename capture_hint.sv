typedef enum logic [1:0] {WAIT_TRIG, SAMP1, SAMP2, DONE} State;
typedef logic[8:0] Address;

module capture_hint(clk, rst_n, rclk, addr, we, en, dec_pwr, trig_pos, trigger, autoroll, armed, trig_type);

    State state;
    State nxt_state;

    input logic clk;
    input logic rst_n;

    input logic rclk;
    input Address trig_pos;
    input logic trigger;
    input logic autoroll;
    input logic armed;
    input logic [ 3:0] dec_pwr;

    logic [15:0] dec_cnt, next_dec_cnt;
    logic keep;
    logic keep_ff;
    Address next_addr;
    Address trig_cnt, next_trig_cnt;

    input logic trig_type;
    output Address addr;
    output logic we;
    output logic en;

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

    always_comb begin
        next_trig_cnt = trig_cnt;
        next_addr = addr;
        next_dec_cnt = dec_cnt;
        we = 0;
        en = 0;
        case(state)
            WAIT_TRIG: begin
                nxt_state = WAIT_TRIG;
                if(|trig_type & ~rclk) begin
                    nxt_state = SAMP1;
                    next_trig_cnt = 0;
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
                    // What happens next?
                    //    1. Wait for capture_done to be cleared
                    //    2. Start again
                    // Maybe go back to WAIT_TRIG instead of DONE
                end else begin
                    nxt_state = SAMP1;
                    en = keep;
                    we = keep;
                    if (keep)
                        next_dec_cnt = 0;
                    if (keep && (trigger | autoroll & armed))
                        next_trig_cnt = trig_cnt + 1;
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
    Address addr; //Output
    logic we; // Output
    logic en; // Output 
    Address trig_pos;
    logic trigger;
    logic autoroll;
    logic armed;
    logic [3:0] dec_pwr;


    capture_hint c1(
    .clk(clk),
    .rst_n(rst_n),
    .rclk(rclk),
    .addr(addr),
    .we(we),
    .en(en),
    .dec_pwr(dec_pwr),
    .trig_pos(trig_pos),
    .trigger(trigger),
    .autoroll(autoroll),
    .armed(armed),
    .trig_type(1)
    );

    initial begin
        autoroll = 0;
        armed = 1;
        clk = 0;
        rclk = 0;
        rst_n = 0;
        trigger = 0;
        dec_pwr = 2;
        trig_pos = 100;

        @(negedge clk) rst_n = 1;
        repeat(5) @(negedge rclk);
        trigger = 1;

    end

    always #1 clk <= ~clk;
    always #2 rclk <= ~rclk;
    
endmodule
