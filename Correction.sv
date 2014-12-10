module Correction(raw, offset, gain, corrected);

    input[7:0] raw;
    input signed[7:0] offset;
    input [7:0] gain;
    output[7:0] corrected;

    logic[15:0] product;
    logic[15:0] saturatedProduct;
    logic[7:0] offsetValue;
    logic[7:0] saturatedOffsetValue;
    logic overflow;

    assign {overflow, offsetValue} = raw + offset;
    assign saturatedOffsetValue = offset >= 0 && overflow ? 8'hFF :
                                  offset < 0 && !overflow ? 8'h00 :
                                  offsetValue;
    assign product = gain * saturatedOffsetValue;
    assign saturatedProduct = product[15] ? 16'h7FFF : product;
    assign corrected = saturatedProduct >> 7;

endmodule

