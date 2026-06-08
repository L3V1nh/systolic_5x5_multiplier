module systolic_grid (
    input wire clk,
    
    input wire signed [39:0] row,
    input wire signed [39:0] col,
    
    output reg signed [599:0] matrix_out,
    output reg valid_out
);


endmodule

module systolic(
    input wire clk,
    input wire rst,
    input wire signed [7:0] raw_row_0, raw_row_1, raw_row_2, raw_row_3, raw_row_4,
    input wire signed [7:0] raw_col_0, raw_col_1, raw_col_2, raw_col_3, raw_col_4,
    
    output wire signed [599:0] matrix_out,
    output reg valid_out
);
endmodule