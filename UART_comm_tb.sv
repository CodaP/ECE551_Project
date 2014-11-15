module UART_comm_tb;
    logic clk;
    logic rst_n;
    logic TXRX;
    logic clr_cmd_rdy;
    logic cmd_rdy;
    logic [23:0] cmd;
    logic trmt;
    logic [7:0] tx_data;
    logic tx_done;

    int fail;


    UART_comm c(clk,
                rst_n,
                TXRX,
                TXRX,
                clr_cmd_rdy, 
                cmd_rdy,
                cmd,
                trmt,
                tx_data,
                tx_done);


    initial begin
        initialize_inputs();

        // Deassert reset
        repeat(10) @(negedge clk);
        rst_n = 1;

        // Try sending all zeros
        send_cmd(24'h000000);

        // Check result
        if(cmd != 24'h000000) fail = fail + 1;

        // Get ready for another
        @(negedge clk) clr_cmd_rdy = 1;
        @(negedge clk) clr_cmd_rdy = 0;

        // Send 123456
        send_cmd(24'h123456);

        // Check result
        if(cmd != 24'h123456) fail = fail + 1;

        $stop;

    end

    // Start the clock
    always #1 clk = ~clk;
        
    task initialize_inputs;
        clk = 0;
        rst_n = 0;
        clr_cmd_rdy = 0;
        trmt = 0;
        tx_data = 8'h00;
        fail = 0;
    endtask

    task send_cmd(input logic [23:0] cmd_to_send);

        // Prepare to transmit high byte
        tx_data = cmd_to_send[23:16];
        @(negedge clk);
        trmt = 1;

        // Prepare to load next byte
        repeat(10) @(negedge clk);
        tx_data = cmd_to_send[15:8];

        // Wait for UART to transmit high byte
        @(posedge tx_done);

        // Prepare to load last byte
        repeat(10) @(negedge clk);
        tx_data = cmd_to_send[7:0];
        
        // Wait for UART to transmit middle byte
        @(posedge tx_done);

        // Prepare to end transmission
        repeat(10) @(negedge clk);
        trmt = 0;

        // Wait for UART to transmit last byte
        @(posedge tx_done);

    endtask

endmodule
