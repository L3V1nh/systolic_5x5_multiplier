`include "axi_transaction.sv"

class axi_driver;
    virtual axi_lite_if vif;

    function new(virtual axi_lite_if vif);
        this.vif = vif;
    endfunction

    task drive(axi_transaction transaction);
        repeat (transaction.delay_cycles)
            @(negedge vif.clk);

        case (transaction.operation)
            axi_transaction::WRITE: drive_write(transaction);
            axi_transaction::READ:  drive_read(transaction);
        endcase
    endtask

    task automatic drive_write(axi_transaction transaction);
        @(negedge vif.clk);
        vif.awaddr  = transaction.addr;
        vif.awvalid = 1'b1;
        vif.wdata   = transaction.data;
        vif.wvalid  = 1'b1;
        vif.bready  = 1'b1;

        fork
            begin
                while (!vif.awready)
                    @(negedge vif.clk);
                @(posedge vif.clk);
                @(negedge vif.clk);
                vif.awvalid = 1'b0;
            end
            begin
                while (!vif.wready)
                    @(negedge vif.clk);
                @(posedge vif.clk);
                @(negedge vif.clk);
                vif.wvalid = 1'b0;
            end
        join

        while (!vif.bvalid)
            @(posedge vif.clk);

        transaction.response = vif.bresp;
        @(negedge vif.clk);
        vif.bready = 1'b0;
    endtask

    task automatic drive_read(axi_transaction transaction);
        @(negedge vif.clk);
        vif.araddr  = transaction.addr;
        vif.arvalid = 1'b1;
        vif.rready  = 1'b1;

        while (!vif.arready)
            @(negedge vif.clk);
        @(posedge vif.clk);
        @(negedge vif.clk);
        vif.arvalid = 1'b0;

        while (!vif.rvalid)
            @(posedge vif.clk);

        transaction.read_data = vif.rdata;
        transaction.response = vif.rresp;
        @(negedge vif.clk);
        vif.rready = 1'b0;
    endtask
endclass