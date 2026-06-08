module processing_element(
    input wire clk,
    input wire rst,
    input wire signed [7:0] row,
    input wire signed [7:0] col,
    output reg signed [7:0] row_out,
    output reg signed [7:0] col_out,
    output reg signed [15:0] out
);

    wire signed [15:0] product;

    BoothMultiplier mul(
        .multiplicand(row),
        .multiplier(col),
        .product(product)
    );
    always @(posedge clk) begin
        if (rst) begin
            out <= 16'd0;
            row_out <= 8'd0;
            col_out <= 8'd0;
        end else begin
            out <= out + product;
            row_out <= row;
            col_out <= col;
        end
    end

endmodule