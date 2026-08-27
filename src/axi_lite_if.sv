interface axi_lite_if;
    logic clk;
    logic rst;

    logic [31:0] awaddr;
    logic awvalid;
    logic awready;

    logic [31:0] wdata;
    logic wvalid;
    logic wready;

    logic [1:0] bresp;
    logic bvalid;
    logic bready;

    logic [31:0] araddr;
    logic arvalid;
    logic arready;

    logic [31:0] rdata;
    logic [1:0] rresp;
    logic rvalid;
    logic rready;

    modport slave (
        input clk, rst, awaddr, awvalid, wdata, wvalid, bready, araddr, arvalid, rready,
        output awready, wready, bresp, bvalid, arready, rdata, rresp, rvalid
    );
endinterface
