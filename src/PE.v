module processing_element(
    input wire clk,
    input wire rst,
    input wire signed [7:0] row,
    input wire signed [7:0] col,
    
    output reg signed [23:0] out
);

    wire signed [15:0] product;

    BoothMultiplier mul(
        .multiplicand(row),
        .multiplier(col),
        .product(product)
    );

    always @(posedge clk) begin
        if (rst) begin
            out <= 24'd0;
        end else begin
            out <= out + product;
        end
    end

endmodule