`include "axi_lite_if.sv"

module axi4_lite_wrapper #(
    parameter N = 3,
    parameter DATA_W = 8,
    parameter ACC_W = 16
)(
    axi4_lite_if.slave axi
);

    logic start_reg;
    logic done_reg;

    logic signed [DATA_W-1:0] matrix_a [N][N];
    logic signed [DATA_W-1:0] matrix_b [N][N];
    logic signed [ACC_W-1:0]  matrix_c [N][N];

    // Register Map
    localparam CONTROL = 32'h0;
    localparam STATUS = 32'h4;

    localparam int WORD_BYTES = 4;
    localparam int MAT_SIZE_BYTES = N*N*WORD_BYTES;

    localparam logic [31:0] A_BASE = 32'h100;
    localparam logic [31:0] B_BASE = A_BASE + MAT_SIZE_BYTES;
    localparam logic [31:0] C_BASE = B_BASE + MAT_SIZE_BYTES;

    function automatic int addr_to_idx(
        input logic [31:0] addr,
        input logic [31:0] base
    );
    begin
        addr_to_idx = (addr - base) >> 2;
    end
    endfunction

    function automatic logic in_range(
        input logic [31:0] addr,
        input logic [31:0] base,
        input int size_bytes
    );
    begin
        in_range = (addr >= base) && (addr < (base + size_bytes));
    end
    endfunction

    // AXI WRITE
    typedef enum logic [1:0] {
        W_IDLE,
        W_COMMIT,
        W_RESP
    } Wstate_t;

    Wstate_t wstate, wstate_next;

    logic [31:0] waddr_reg, wdata_reg;
    logic aw_handshake, w_handshake;
    logic aw_done, w_done;
    assign aw_handshake = axi.awvalid && axi.awready;
    assign w_handshake  = axi.wvalid && axi.wready;

    always_ff @(posedge axi.clk) begin: Wstate_register
        if (axi.rst) begin
            wstate <= W_IDLE;

            waddr_reg <= '0;
            wdata_reg <= '0;
            aw_done <= 1'b0;
            w_done <= 1'b0;

            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    matrix_a[i][j] <= '0;
                    matrix_b[i][j] <= '0;
                end
            end
        end
        else begin
            wstate <= wstate_next;
            if (aw_handshake) begin
                waddr_reg <= axi.awaddr;
                aw_done <= 1'b1;
            end
            if (w_handshake) begin
                wdata_reg <= axi.wdata;
                w_done <= 1'b1;
            end
            if (wstate == W_RESP && axi.bready) begin
                aw_done <= 1'b0;
                w_done <= 1'b0;
            end
        end
    end

    always_comb begin : Wstate_transition
        wstate_next = wstate;
        case (wstate)
            W_IDLE: begin
                if ((aw_done || aw_handshake) && (w_done || w_handshake))
                    wstate_next = W_COMMIT;
            end
            W_COMMIT: wstate_next = W_RESP;
            W_RESP: wstate_next = (axi.bready) ? W_IDLE : W_RESP;
        endcase
    end

    logic a_sel, b_sel, control_sel, invalid_addr;

    int idx;
    int row;
    int col;

    always_comb begin: datapath
        control_sel = (waddr_reg == CONTROL);
        a_sel = in_range(waddr_reg, A_BASE, MAT_SIZE_BYTES);
        b_sel = in_range(waddr_reg, B_BASE, MAT_SIZE_BYTES);
        invalid_addr = !(control_sel || a_sel || b_sel);

        idx = 0;
        if (a_sel)
            idx = addr_to_idx(waddr_reg, A_BASE);
        else if (b_sel)
            idx = addr_to_idx(waddr_reg, B_BASE);

        row = idx / N;
        col = idx % N;

        axi.awready = (wstate == W_IDLE) && !aw_done;
        axi.wready  = (wstate == W_IDLE) && !w_done;
        axi.bvalid  = 1'b0;
        axi.bresp   = 2'b00;

        case (wstate)
            W_IDLE: begin
            end

            W_COMMIT: begin
            end

            W_RESP: begin
                axi.bvalid = 1'b1;

                if (invalid_addr)
                    axi.bresp = 2'b11;
                else
                    axi.bresp = 2'b00;
            end

            default: begin
            end
        endcase
    end

    always_ff @(posedge axi.clk) begin : matrix_write
        if (axi.rst) begin
            start_reg <= 1'b0;
        end
        else begin
            if (wstate == W_COMMIT) begin
                start_reg <= control_sel ? wdata_reg[0] : 1'b0;

                if (a_sel)
                    matrix_a[row][col] <= wdata_reg[DATA_W-1:0];
                else if (b_sel)
                    matrix_b[row][col] <= wdata_reg[DATA_W-1:0];
            end
            else begin
                start_reg <= 1'b0;
            end
        end
    end

    //  AXI READ
    typedef enum logic [1:0] {
        R_IDLE,
        R_COMMIT,
        R_RESP
    } Rstate_t;

    Rstate_t rstate, rstate_next;
    logic [31:0] raddr_reg, rdata_reg;
    logic [1:0] rresp_reg;
    logic ar_handshake, r_handshake;
    assign ar_handshake = axi.arvalid && axi.arready;
    assign r_handshake = axi.rvalid && axi.rready;

    always_ff @(posedge axi.clk) begin: Rstate_register
        if (axi.rst) begin
            rstate <= R_IDLE;
            raddr_reg <= '0;
            rdata_reg <= '0;
            rresp_reg <= 2'b00;
        end
        else begin
            rstate <= rstate_next;
            if (ar_handshake) begin
                raddr_reg <= axi.araddr;
            end
            if (rstate == R_COMMIT) begin
                rdata_reg <= 32'h0;
                rresp_reg <= 2'b00;
                if (raddr_reg == STATUS) begin
                    rdata_reg <= {31'b0, done_reg};
                end
                else if (in_range(raddr_reg, C_BASE, MAT_SIZE_BYTES)) begin
                    rdata_reg <= $signed(matrix_c[
                        addr_to_idx(raddr_reg, C_BASE) / N
                    ][
                        addr_to_idx(raddr_reg, C_BASE) % N
                    ]);
                end
                else begin
                    rresp_reg <= 2'b11;
                end
            end
        end
    end

    always_comb begin: Rstate_transition
        rstate_next = rstate;
        case (rstate)
            R_IDLE: if (ar_handshake) rstate_next = R_COMMIT;
            R_COMMIT: rstate_next = R_RESP;
            R_RESP: if (r_handshake) rstate_next = R_IDLE;
        endcase
    end

    always_comb begin: read_response
        axi.arready = (rstate == R_IDLE);
        axi.rvalid = (rstate == R_RESP);
        axi.rdata = rdata_reg;
        axi.rresp = rresp_reg;
    end

    // MODULE INSTANTIATION
    matrix_accel #(
        .N(N),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) accel (
        .clk(axi.clk),
        .rst(axi.rst),
        .matrix_a(matrix_a),
        .matrix_b(matrix_b),
        .matrix_c(matrix_c),
        .start(start_reg),
        .done(done_reg)
    );
endmodule