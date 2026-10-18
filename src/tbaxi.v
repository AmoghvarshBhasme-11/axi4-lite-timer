`timescale 1ns / 1ps
module tb_axi_timer;

    reg         ACLK;
    reg         ARESETN;

    reg  [7:0]  AWADDR;
    reg         AWVALID;
    wire        AWREADY;

    reg  [31:0] WDATA;
    reg  [3:0]  WSTRB;
    reg         WVALID;
    wire        WREADY;

    wire [1:0]  BRESP;
    wire        BVALID;
    reg         BREADY;

    reg  [7:0]  ARADDR;
    reg         ARVALID;
    wire        ARREADY;

    wire [31:0] RDATA;
    wire [1:0]  RRESP;
    wire        RVALID;
    reg         RREADY;

    axi_timer u0 (
        .ACLK(ACLK),
        .ARESETN(ARESETN),
        .S_AXI_AWADDR(AWADDR),
        .S_AXI_AWVALID(AWVALID),
        .S_AXI_AWREADY(AWREADY),
        .S_AXI_WDATA(WDATA),
        .S_AXI_WSTRB(WSTRB),
        .S_AXI_WVALID(WVALID),
        .S_AXI_WREADY(WREADY),
        .S_AXI_BRESP(BRESP),
        .S_AXI_BVALID(BVALID),
        .S_AXI_BREADY(BREADY),
        .S_AXI_ARADDR(ARADDR),
        .S_AXI_ARVALID(ARVALID),
        .S_AXI_ARREADY(ARREADY),
        .S_AXI_RDATA(RDATA),
        .S_AXI_RRESP(RRESP),
        .S_AXI_RVALID(RVALID),
        .S_AXI_RREADY(RREADY)
    );

    initial ACLK = 0;
    always #5 ACLK = ~ACLK;

    task do_write;
        input  [7:0]  addr;
        input  [31:0] data;
        output [1:0]  resp;
        integer i;
        reg got_aw;
        reg got_w;
        reg got_b;
        begin
            got_aw = 0;
            got_w  = 0;
            got_b  = 0;
            resp   = 2'b00;

            @(posedge ACLK);
            AWADDR  = addr;
            AWVALID = 1;
            WDATA   = data;
            WSTRB   = 4'b1111;
            WVALID  = 1;
            BREADY  = 1;

            for (i = 0; i < 30; i = i + 1) begin
                @(posedge ACLK);
                if (AWVALID && AWREADY) begin
                    got_aw  = 1;
                    AWVALID = 0;
                end
                if (WVALID && WREADY) begin
                    got_w  = 1;
                    WVALID = 0;
                end
                if (BVALID && BREADY) begin
                    got_b = 1;
                    resp  = BRESP;
                end
                if (got_aw && got_w && got_b)
                    i = 30;
            end

            if (!got_aw || !got_w || !got_b) begin
                $display("WRITE TIMEOUT addr=%h got_aw=%b got_w=%b got_b=%b AWREADY=%b WREADY=%b BVALID=%b state=%b",
                         addr, got_aw, got_w, got_b, AWREADY, WREADY, BVALID, u0.state);
                $finish;
            end

            @(posedge ACLK);
            BREADY  = 0;
            AWVALID = 0;
            WVALID  = 0;
        end
    endtask

    task do_read;
        input  [7:0]  addr;
        output [31:0] data;
        output [1:0]  resp;
        integer i;
        reg got_ar;
        reg got_r;
        begin
            got_ar = 0;
            got_r  = 0;
            data   = 0;
            resp   = 2'b00;

            @(posedge ACLK);
            ARADDR  = addr;
            ARVALID = 1;
            RREADY  = 1;

            for (i = 0; i < 30; i = i + 1) begin
                @(posedge ACLK);
                if (ARVALID && ARREADY) begin
                    got_ar  = 1;
                    ARVALID = 0;
                end
                if (RVALID && RREADY) begin
                    got_r = 1;
                    data  = RDATA;
                    resp  = RRESP;
                end
                if (got_ar && got_r)
                    i = 30;
            end

            if (!got_ar || !got_r) begin
                $display("READ TIMEOUT addr=%h got_ar=%b got_r=%b ARREADY=%b RVALID=%b state=%b",
                         addr, got_ar, got_r, ARREADY, RVALID, u0.state);
                $finish;
            end

            @(posedge ACLK);
            RREADY  = 0;
            ARVALID = 0;
        end
    endtask

    reg  [1:0]  resp;
    reg  [31:0] rdata;
    integer     errors;

    initial begin
        errors  = 0;
        AWADDR  = 0; AWVALID = 0;
        WDATA   = 0; WSTRB = 0; WVALID = 0;
        BREADY  = 0;
        ARADDR  = 0; ARVALID = 0;
        RREADY  = 0;

        ARESETN = 0;
        repeat (4) @(posedge ACLK);
        ARESETN = 1;
        repeat (2) @(posedge ACLK);

        $display("T1: write LOAD");
        do_write(8'h04, 32'd5, resp);
        if (resp != 2'b00) begin $display("FAIL T1 resp=%b", resp); errors = errors + 1; end
        else $display("PASS T1");

        $display("T2: read LOAD");
        do_read(8'h04, rdata, resp);
        if (resp != 2'b00 || rdata != 32'd5) begin
            $display("FAIL T2 data=%0d resp=%b", rdata, resp); errors = errors + 1;
        end else $display("PASS T2 data=%0d", rdata);

        $display("T3: enable");
        do_write(8'h00, 32'd1, resp);
        if (resp != 2'b00) begin $display("FAIL T3"); errors = errors + 1; end
        else $display("PASS T3");

        $display("T4: read COUNT");
        repeat (10) @(posedge ACLK);
        do_read(8'h08, rdata, resp);
        if (resp != 2'b00 || rdata == 0) begin
            $display("FAIL T4 count=%0d", rdata); errors = errors + 1;
        end else $display("PASS T4 count=%0d", rdata);

        $display("T5: write COUNT (expect SLVERR)");
        do_write(8'h08, 32'hDEADBEEF, resp);
        if (resp != 2'b10) begin $display("FAIL T5 resp=%b", resp); errors = errors + 1; end
        else $display("PASS T5");

        $display("T6: bad addr (expect DECERR)");
        do_write(8'h20, 32'h12345678, resp);
        if (resp != 2'b11) begin $display("FAIL T6 resp=%b", resp); errors = errors + 1; end
        else $display("PASS T6");

        $display("T7: clear COUNT via CTRL bit1");
        do_write(8'h00, 32'h0000_0003, resp);
        if (resp != 2'b00) begin
            $display("FAIL T7 write resp=%b", resp);
            errors = errors + 1;
        end else begin
            repeat (2) @(posedge ACLK);
            do_read(8'h08, rdata, resp);
            if (resp != 2'b00 || rdata > 32'd5) begin
                $display("FAIL T7 count=%0d (expected small after clear)", rdata);
                errors = errors + 1;
            end else
                $display("PASS T7 count=%0d after clear", rdata);
        end

        $display("T8: STATUS read / W1C write");
        do_read(8'h0C, rdata, resp);
        if (resp != 2'b00) begin
            $display("FAIL T8 read STATUS resp=%b", resp);
            errors = errors + 1;
        end else begin
            $display("STATUS before clear = %h", rdata);
            do_write(8'h0C, 32'h0000_0001, resp);
            if (resp != 2'b00) begin
                $display("FAIL T8 STATUS write resp=%b", resp);
                errors = errors + 1;
            end else begin
                do_read(8'h0C, rdata, resp);
                if (resp != 2'b00 || (rdata & 32'h1) != 0) begin
                    $display("FAIL T8 STATUS after W1C = %h", rdata);
                    errors = errors + 1;
                end else
                    $display("PASS T8 STATUS cleared (or already 0)");
            end
        end

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d FAILED", errors);

        #20;
        $finish;
    end

endmodule
