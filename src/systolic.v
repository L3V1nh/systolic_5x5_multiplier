module systolic_grid (
    input wire clk,
    input wire rst,
    
    input wire signed [39:0] row,
    input wire signed [39:0] col,
    
    output wire signed [399:0] matrix_out
);


    wire signed [7:0] horizontal [4:0][5:0];
    wire signed [7:0] vertical   [5:0][4:0];
    

    wire signed [15:0] pe_out [4:0][4:0];

    genvar i;
    generate
        for (i = 0; i < 5; i = i + 1) begin
            assign horizontal[i][0] = row[(i*8) +: 8]; 
            assign vertical[0][i]   = col[(i*8) +: 8];
        end
    endgenerate

    genvar r, c;
    generate
        for (r = 0; r < 5; r = r + 1) begin 
            for (c = 0; c < 5; c = c + 1) begin
                
                processing_element pe (
                    .clk(clk),
                    .rst(rst),
                    .row(horizontal[r][c]),      
                    .col(vertical[r][c]),        
                    .row_out(horizontal[r][c+1]),
                    .col_out(vertical[r+1][c]),  
                    .out(pe_out[r][c])        
                );

                assign matrix_out[((r * 5 + c) * 16) +: 16] = pe_out[r][c];
                
            end
        end
    endgenerate
endmodule

module systolic(
    input wire clk,
    input wire rst,
    input wire signed [7:0] raw_row_0, raw_row_1, raw_row_2, raw_row_3, raw_row_4,
    input wire signed [7:0] raw_col_0, raw_col_1, raw_col_2, raw_col_3, raw_col_4,
    
    output wire signed [399:0] matrix_out,
    output reg valid_out
);
    initial valid_out = 0;
    // Row delay chains
    reg signed [7:0] r1_d1;
    
    reg signed [7:0] r2_d1, r2_d2;
    
    reg signed [7:0] r3_d1, r3_d2, r3_d3;
    
    reg signed [7:0] r4_d1, r4_d2, r4_d3, r4_d4;

    // Column delay chains
    reg signed [7:0] c1_d1;
    
    reg signed [7:0] c2_d1, c2_d2;
    
    reg signed [7:0] c3_d1, c3_d2, c3_d3;
    
    reg signed [7:0] c4_d1, c4_d2, c4_d3, c4_d4;

    always @(posedge clk) begin
        if (rst) begin
            // Clear the pipeline registers on reset
            r1_d1 <= 8'd0;
            r2_d1 <= 8'd0; r2_d2 <= 8'd0;
            r3_d1 <= 8'd0; r3_d2 <= 8'd0; r3_d3 <= 8'd0;
            r4_d1 <= 8'd0; r4_d2 <= 8'd0; r4_d3 <= 8'd0; r4_d4 <= 8'd0;

            c1_d1 <= 8'd0;
            c2_d1 <= 8'd0; c2_d2 <= 8'd0;
            c3_d1 <= 8'd0; c3_d2 <= 8'd0; c3_d3 <= 8'd0;
            c4_d1 <= 8'd0; c4_d2 <= 8'd0; c4_d3 <= 8'd0; c4_d4 <= 8'd0;
            
            valid_out <= 1'b0;
        end else begin
            // Shift values through the register chains every clock cycle
            // Row Skewing
            r1_d1 <= raw_row_1;
            
            r2_d1 <= raw_row_2;
            r2_d2 <= r2_d1;  
            
            r3_d1 <= raw_row_3;
            r3_d2 <= r3_d1;
            r3_d3 <= r3_d2; 
            
            r4_d1 <= raw_row_4;
            r4_d2 <= r4_d1;
            r4_d3 <= r4_d2;
            r4_d4 <= r4_d3;  

            
            c1_d1 <= raw_col_1; 
            
            c2_d1 <= raw_col_2;
            c2_d2 <= c2_d1;     
            c3_d1 <= raw_col_3;
            c3_d2 <= c3_d1;
            c3_d3 <= c3_d2;  
            
            c4_d1 <= raw_col_4;
            c4_d2 <= c4_d1;
            c4_d3 <= c4_d2;
            c4_d4 <= c4_d3;
            
            valid_out <= 1'b1; 
        end
    end

    wire signed [39:0] grid_row_bus = { r4_d4, r3_d3, r2_d2, r1_d1, raw_row_0 };
    wire signed [39:0] grid_col_bus = { c4_d4, c3_d3, c2_d2, c1_d1, raw_col_0 };

    systolic_grid u_grid (
        .clk(clk),
        .rst(rst),
        .row(grid_row_bus), 
        .col(grid_col_bus), 
        .matrix_out(matrix_out)
    );
endmodule