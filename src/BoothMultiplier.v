module BoothMultiplier (
    input  wire signed [7:0] multiplicand,
    input  wire signed [7:0] multiplier,
    output reg  signed [15:0] product
);

    reg signed [15:0] A;
    reg signed [7:0]  Q;
    reg              Q_1;
    reg signed [7:0]  M;

    always @* begin
        A    = 16'sd0;
        M    = multiplicand;
        Q    = multiplier;
        Q_1  = 1'b0;

        repeat (8) begin
            case ({Q[0], Q_1})
                2'b01: A = A + {{8{M[7]}}, M};  // A = A + M
                2'b10: A = A - {{8{M[7]}}, M};  // A = A - M
                default: ; // No operation
            endcase

            {A, Q, Q_1} = {A[15], A, Q, Q_1} >>> 1;

        end

        product = {A[15:0], Q};
    end

endmodule