typedef enum logic [1:0] {WAIT_TRIG, SAMP1, SAMP2, DONE} State;
typedef logic[8:0] Address;

module capture_hint(clk, rst_n, rclk, clr_trig_cnt, clr_dec_cnt, en_dec_cnt, addr, we, en, en_trig_cnt, trig_cnt, dec_cnt, dec_pwr, trig_pos, trigger, autoroll, armed, trig_type);

    State state;
    State nxt_state;

    input logic clk;
    input logic rst_n;

    input logic rclk;
    input Address trig_pos;
    input logic trigger;
    input logic autoroll;
    input logic armed;
    input Address trig_cnt;

    input logic [ 3:0] dec_pwr;
    input logic [15:0] dec_cnt;

    logic keep;
    logic keep_ff;
    Address next_addr;

    input logic trig_type;
    output logic clr_trig_cnt;
    output logic clr_dec_cnt;
    output logic en_dec_cnt;
    output Address addr;
    output logic we;
    output logic en;
    output logic en_trig_cnt;

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

    always_comb begin
        clr_trig_cnt = 0;
        clr_dec_cnt = 0;
        en_dec_cnt = 0;
        next_addr = addr;
        we = 0;
        en = 0;
        en_trig_cnt = 0;
        case(state)
            WAIT_TRIG:
                if(~rclk & |trig_type) begin
                    nxt_state = SAMP1;
                    clr_trig_cnt= 1;
                    clr_dec_cnt= 1;
                end
                else
                    nxt_state = WAIT_TRIG;
            SAMP1: begin
                nxt_state = SAMP2;
                en_dec_cnt = 1;
                next_addr = keep_ff ? addr + 1 : addr;
                we = keep_ff;
                en = keep_ff;
            end
            SAMP2:begin
                if(trig_cnt == trig_pos) begin
                    // Finish aquisition
                    //    - Set capture_done
                    //    - Save address pointer in trace_end
                    //    - clear armed
                    // What happens next?
                    //    1. Wait for capture_done to be cleared
                    //    2. Start again
                    // Maybe go back to WAIT_TRIG instead of DONE
                    nxt_state = DONE;
                end
                else begin
                    en = keep;
                    we = keep;
                    clr_dec_cnt = keep;
                    en_trig_cnt = (trigger | autoroll & armed) & keep;
                    nxt_state = SAMP1;
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
    logic clr_trig_cnt; //Output
    logic clr_dec_cnt; //Output
    logic en_dec_cnt; //Output
    Address addr; //Output
    logic we; // Output
    logic en; // Output 
    logic en_trig_cnt; // Output
    Address trig_cnt;
    logic [15:0] dec_cnt;
    Address trig_pos;
    logic trigger;
    logic autoroll;
    logic armed;
    logic [3:0] dec_pwr;


    capture_hint c1(
    .clk(clk),
    .rst_n(rst_n),
    .rclk(rclk),
    .clr_trig_cnt(clr_trig_cnt),
    .clr_dec_cnt(clr_dec_cnt),
    .en_dec_cnt(en_dec_cnt),
    .addr(addr),
    .we(we),
    .en(en),
    .en_trig_cnt(en_trig_cnt),
    .trig_cnt(trig_cnt),
    .dec_cnt(dec_cnt),
    .dec_pwr(dec_pwr),
    .trig_pos(trig_pos),
    .trigger(trigger),
    .autoroll(autoroll),
    .armed(armed),
    .trig_type(1)
    );

    always_ff @(posedge clk, negedge rst_n)
        if(!rst_n)
            trig_cnt <= 0;
        else
            if(clr_trig_cnt)
                trig_cnt <= 0;
            else if(en_trig_cnt)
                trig_cnt <= trig_cnt + 1;
            else
                trig_pos <= trig_pos;

    always_ff @(posedge clk, negedge rst_n)
        if(!rst_n)
            dec_cnt <= 0;
        else
            if(clr_dec_cnt)
                dec_cnt <= 0;
            else if(en_dec_cnt)
                dec_cnt <= dec_cnt + 1;
            else
                dec_cnt <= dec_cnt;

    initial begin
        autoroll = 0;
        armed = 1;
        clk = 0;
        rclk = 0;
        rst_n = 0;
        trigger = 0;
        dec_pwr = 0;
        trig_pos = 100;

        @(negedge clk) rst_n = 1;
        repeat(5) @(negedge rclk);
        trigger = 1;

    end

    always #1 clk <= ~clk;
    always #2 rclk <= ~rclk;
    
endmodule