module ClkGen(clk, rst_n, posclk, negclk);

    input clk, rst_n;

    output logic posclk;
    output logic negclk;

    assign negclk = ~posclk;

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            posclk <= 0;
        else
            posclk <= ~posclk;

endmodule

