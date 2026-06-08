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
    input wire wrt_en, // High when new data is being streamed in
    input wire signed [7:0] raw_row_0, raw_row_1, raw_row_2, raw_row_3, raw_row_4,
    input wire signed [7:0] raw_col_0, raw_col_1, raw_col_2, raw_col_3, raw_col_4,
    
    output wire signed [399:0] matrix_out,
    output reg valid_out
);

    // 1. Existing Row/Column Skewing Registers
    reg signed [7:0] r1_d1;
    reg signed [7:0] r2_d1, r2_d2;
    reg signed [7:0] r3_d1, r3_d2, r3_d3;
    reg signed [7:0] r4_d1, r4_d2, r4_d3, r4_d4;

    reg signed [7:0] c1_d1;
    reg signed [7:0] c2_d1, c2_d2;
    reg signed [7:0] c3_d1, c3_d2, c3_d3;
    reg signed [7:0] c4_d1, c4_d2, c4_d3, c4_d4;

    // 2. Hardware Flush Tracking (Tracking the valid wavefront)
    // We create a delay chain for the wrt_en signal itself!
    reg v0, v1, v2, v3, v4;
    reg v1_d1;
    reg v2_d1, v2_d2;
    reg v3_d1, v3_d2, v3_d3;
    reg v4_d1, v4_d2, v4_d3, v4_d4;

    always @(posedge clk) begin
        if (rst) begin
            // Clear data delay pipelines
            r1_d1 <= 0; r2_d1 <= 0; r2_d2 <= 0;
            r3_d1 <= 0; r3_d2 <= 0; r3_d3 <= 0;
            r4_d1 <= 0; r4_d2 <= 0; r4_d3 <= 0; r4_d4 <= 0;

            c1_d1 <= 0; c2_d1 <= 0; c2_d2 <= 0;
            c3_d1 <= 0; c3_d2 <= 0; c3_d3 <= 0;
            c4_d1 <= 0; c4_d2 <= 0; c4_d3 <= 0; c4_d4 <= 0;

            // Clear execution tracking pipelines
            v1_d1 <= 0; v2_d1 <= 0; v2_d2 <= 0;
            v3_d1 <= 0; v3_d2 <= 0; v3_d3 <= 0;
            v4_d1 <= 0; v4_d2 <= 0; v4_d3 <= 0; v4_d4 <= 0;

            valid_out <= 1'b0;
        end else begin
            // Pure Bucket Brigade Shifting
            r1_d1 <= raw_row_1;
            r2_d1 <= raw_row_2; r2_d2 <= r2_d1;
            r3_d1 <= raw_row_3; r3_d2 <= r3_d1; r3_d3 <= r3_d2;
            r4_d1 <= raw_row_4; r4_d2 <= r4_d1; r4_d3 <= r4_d2; r4_d4 <= r4_d3;

            c1_d1 <= raw_col_1;
            c2_d1 <= raw_col_2; c2_d2 <= c2_d1;
            c3_d1 <= raw_col_3; c3_d2 <= c3_d1; c3_d3 <= c3_d2;
            c4_d1 <= raw_col_4; c4_d2 <= c4_d1; c4_d3 <= c4_d2; c4_d4 <= c4_d3;

            // Shift wrt_en along with the rows to track when data waves actually exit
            v1_d1 <= wrt_en;
            v2_d1 <= wrt_en; v2_d2 <= v2_d1;
            v3_d1 <= wrt_en; v3_d2 <= v3_d1; v3_d3 <= v3_d2;
            v4_d1 <= wrt_en; v4_d2 <= v4_d1; v4_d3 <= v4_d2; v4_d4 <= v4_d3;

            // valid_out goes high when the very last valid element has trickled 
            // through the longest pipeline delay register chain.
            valid_out <= v4_d4; 
        end
    end

    // 3. Tail Guarding Multiplexers
    // If wrt_en or the tracked lane valid bit is low, we force 0 into the grid.
    // This protects the grid inputs if the outside bus floats or stays dirty.
    wire signed [7:0] grid_r0 = (wrt_en) ? raw_row_0 : 8'sd0;
    wire signed [7:0] grid_r1 = (v1_d1)  ? r1_d1     : 8'sd0;
    wire signed [7:0] grid_r2 = (v2_d2)  ? r2_d2     : 8'sd0;
    wire signed [7:0] grid_r3 = (v3_d3)  ? r3_d3     : 8'sd0;
    wire signed [7:0] grid_r4 = (v4_d4)  ? r4_d4     : 8'sd0;

    wire signed [7:0] grid_c0 = (wrt_en) ? raw_col_0 : 8'sd0;
    wire signed [7:0] grid_c1 = (v1_d1)  ? c1_d1     : 8'sd0;
    wire signed [7:0] grid_c2 = (v2_d2)  ? c2_d2     : 8'sd0;
    wire signed [7:0] grid_c3 = (v3_d3)  ? c3_d3     : 8'sd0;
    wire signed [7:0] grid_c4 = (v4_d4)  ? c4_d4     : 8'sd0;

    // Bundle clean, protected streams into the grid bus
    wire signed [39:0] grid_row_bus = { grid_r4, grid_r3, grid_r2, grid_r1, grid_r0 };
    wire signed [39:0] grid_col_bus = { grid_c4, grid_c3, grid_c2, grid_c1, grid_c0 };

    // 4. Instantiate Grid
    systolic_grid u_grid (
        .clk(clk),
        .rst(rst),
        .row(grid_row_bus), 
        .col(grid_col_bus), 
        .matrix_out(matrix_out)
    );

endmodule