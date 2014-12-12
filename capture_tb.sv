typedef logic[8:0] Address;

module capture_tb;
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

    Capture c1(
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

    logic waiting;
    logic[3:0] waiter;
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n) begin
            waiter <= 4'hF;
        end else begin
            waiter <= waiting ? waiter + 1 : waiter;
        end

    assign waiting = !dump_sent || send_dump;
    assign dump_sent = &waiter;

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
        trig_type = 2;
        trig_pos = 20;
        capture_done = 0;

        start_dump = 0;

        @(negedge clk) rst_n = 1;
        while(!armed) @(posedge clk);
        repeat(16) @(posedge clk);
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
