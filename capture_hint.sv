typedef enum logic [1:0] {WAIT_TRIG, SAMP1, SAMP2, DONE} State;
module capture_hint(clk, rst_n, rclk, clr_trig_cnt, clr_dec_cnt, en_dec_cnt, inc_addr, we, en ,en_trig_cnt, trig_cnt, dec, trig_pos, trigger, autoroll, armed);

    State state;
    State nxt_state;

    input logic clk;
    input logic rst_n;

    input logic rclk;
    input logic [8:0] trig_pos;
    input logic trigger;
    input logic autoroll;
    input logic armed;

    input logic [3:0] dec;
    logic [15:0] dec_pwr;

    assign dec_pwr = 1 << dec_pwr;

    logic keep;
    logic keep_ff;
    logic dec_cnt;
    logic trig_type;
    output logic clr_trig_cnt;
    output logic clr_dec_cnt;
    output logic en_dec_cnt;
    output logic inc_addr;
    output logic we;
    output logic en;
    output logic en_trig_cnt;
    output logic trig_cnt;

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

    assign keep = (dec_cnt == dec_pwr)? 1'b1 : 1'b0;

    always_comb begin
        clr_trig_cnt = 0;
        clr_dec_cnt = 0;
        en_dec_cnt = 0;
        inc_addr = 0;
        we = 0;
        en = 0;
        en_trig_cnt = 0;
        trig_cnt = 0;
        case(state)
            WAIT_TRIG:
                if(~rclk && trig_type) begin
                    nxt_state = SAMP1;
                    clr_trig_cnt= 1;
                    clr_dec_cnt= 1;
                end
                else
                    nxt_state = WAIT_TRIG;
            SAMP1: begin
                nxt_state = SAMP2;
                en_dec_cnt = 1;
                inc_addr = keep_ff;
                we = keep_ff;
                en = keep_ff;
            end
            SAMP2:begin
                if(trig_cnt == trig_pos)
                    nxt_state = DONE;
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

