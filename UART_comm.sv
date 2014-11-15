module UART_comm(clk, rst_n, RX, TX, clr_cmd_rdy, cmd_rdy, cmd, trmt, tx_data, tx_done);
    input clk;
    input rst_n;
    input RX;
    output TX;
    input clr_cmd_rdy;
    output logic cmd_rdy;
    output logic [23:0] cmd;
    input trmt;
    input [7:0] tx_data;
    output tx_done; 

    // Internal signals
    logic rdy;
    logic [7:0] rx_data;
    logic clr_rdy;

    // Need registers to hold previous packets
    logic [7:0] high_byte;
    logic en_high_byte;
    logic [7:0] middle_byte;
    logic en_middle_byte;

    // cmd is three packets concatenated
    assign cmd = {high_byte,middle_byte,rx_data};

    // high_byte is a "async reset with enable" flip-flop controlled from SM
    always_ff @(posedge clk, negedge rst_n)
        if(!rst_n)
            high_byte <= 0;
        else
            if(en_high_byte)
                high_byte <= rx_data;
            else
                high_byte <= high_byte;

    // middle_byte is a "async reset with enable" flip-flop controlled from SM
    always_ff @(posedge clk, negedge rst_n)
        if(!rst_n)
            middle_byte <= 0;
        else
            if(en_middle_byte)
                middle_byte <= rx_data;
            else
                middle_byte <= middle_byte;


    UART uart0(.clk(clk),
                    .rst_n(rst_n),
                    .RX(RX),
                    .TX(TX),
                    .trmt(trmt),
                    .tx_data(tx_data),
                    .tx_done(tx_done),
                    .rdy(rdy),
                    .rx_data(rx_data),
                    .clr_rdy(clr_rdy));

    /////////////////////
    // UART_WRAPPER_SM //
    /////////////////////

    typedef enum logic [1:0] {READ_HIGH_BYTE, READ_MIDDLE_BYTE, READ_LOW_BYTE, COMMAND_READY} State;

    State state;
    State nxt_state;

    always_ff @(posedge clk, negedge rst_n)
       if(!rst_n)
           state <= READ_HIGH_BYTE; 
       else
           state <= nxt_state;

    // UART_WRAPPER State Machine
    // outputs: en_high_byte, en_middle_byte, clr_rdy, cmd_rdy
    // inputs: clr_cmd_rdy, rdy
    always_comb begin
        en_high_byte = 0;
        en_middle_byte = 0;
        nxt_state = READ_HIGH_BYTE;
        cmd_rdy = 0;
        clr_rdy = 0;
        case(state)

            READ_HIGH_BYTE: begin
                if(rdy) begin
                    nxt_state = READ_MIDDLE_BYTE;
                    clr_rdy = 1;
                end
                else begin
                    nxt_state = READ_HIGH_BYTE;
                    en_high_byte = 1;
                end
            end
    
            READ_MIDDLE_BYTE:
                if(rdy) begin
                    nxt_state = READ_LOW_BYTE;
                    clr_rdy = 1;
                end
                else begin
                    en_middle_byte = 1;
                    nxt_state = READ_MIDDLE_BYTE;
                end

            READ_LOW_BYTE:
                if(rdy) begin
                    nxt_state = COMMAND_READY;
                    clr_rdy = 1;
                end
                else
                    nxt_state = READ_LOW_BYTE;

            COMMAND_READY:
                if(clr_cmd_rdy) begin
                    nxt_state = READ_HIGH_BYTE;
                    cmd_rdy = 0;
                end
                else begin
                    nxt_state = COMMAND_READY;
                    cmd_rdy = 1;
                end

            default nxt_state = READ_HIGH_BYTE;

        endcase


    end
        

endmodule
