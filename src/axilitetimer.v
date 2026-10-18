`timescale 1ns / 1ps
module axi_timer #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input  wire                      ACLK,
    input  wire                      ARESETN,

    input  wire [ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    input  wire                      S_AXI_AWVALID,
    output reg                       S_AXI_AWREADY,

    input  wire [DATA_WIDTH-1:0]     S_AXI_WDATA,
    input  wire [(DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                      S_AXI_WVALID,
    output reg                       S_AXI_WREADY,

    output reg  [1:0]                S_AXI_BRESP,
    output reg                       S_AXI_BVALID,
    input  wire                      S_AXI_BREADY,

    input  wire [ADDR_WIDTH-1:0]     S_AXI_ARADDR,
    input  wire                      S_AXI_ARVALID,
    output reg                       S_AXI_ARREADY,

    output reg  [DATA_WIDTH-1:0]     S_AXI_RDATA,
    output reg  [1:0]                S_AXI_RRESP,
    output reg                       S_AXI_RVALID,
    input  wire                      S_AXI_RREADY
);

    localparam RESP_OKAY   = 2'b00;
    localparam RESP_SLVERR = 2'b10;
    localparam RESP_DECERR = 2'b11;

    localparam ST_IDLE         = 2'd0;
    localparam ST_WRITE_ACCEPT = 2'd1;
    localparam ST_WRITE_RESP   = 2'd2;
    localparam ST_READ_RESP    = 2'd3;

    reg [1:0] state;

    reg [31:0] reg_ctrl;
    reg [31:0] reg_load;
    reg [31:0] reg_count;
    reg [31:0] reg_status;

    reg [ADDR_WIDTH-1:0] awaddr_r;
    reg [DATA_WIDTH-1:0] wdata_r;
    reg                  aw_done;
    reg                  w_done;
    reg                  wr_applied;

    reg [ADDR_WIDTH-1:0] araddr_r;

    wire enable    = reg_ctrl[0];
    wire count_max = (reg_count == 32'hFFFF_FFFF);

    reg [1:0] wr_resp;
    reg       wr_to_ctrl;
    reg       wr_to_load;
    reg       wr_to_status;
    reg       wr_to_count_bad;
    reg       wr_decerr;

    always @(*) begin
        wr_resp         = RESP_OKAY;
        wr_to_ctrl      = 1'b0;
        wr_to_load      = 1'b0;
        wr_to_status    = 1'b0;
        wr_to_count_bad = 1'b0;
        wr_decerr       = 1'b0;

        if (awaddr_r[7:4] != 4'h0) begin
            wr_decerr = 1'b1;
            wr_resp   = RESP_DECERR;
        end else begin
            case (awaddr_r[3:0])
                4'h0: begin
                    wr_to_ctrl = 1'b1;
                    wr_resp    = RESP_OKAY;
                end
                4'h4: begin
                    wr_to_load = 1'b1;
                    wr_resp    = RESP_OKAY;
                end
                4'h8: begin
                    wr_to_count_bad = 1'b1;
                    wr_resp         = RESP_SLVERR;
                end
                4'hC: begin
                    wr_to_status = 1'b1;
                    wr_resp      = RESP_OKAY;
                end
                default: begin
                    wr_decerr = 1'b1;
                    wr_resp   = RESP_DECERR;
                end
            endcase
        end
    end

    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            state         <= ST_IDLE;
            reg_ctrl      <= 32'h0;
            reg_load      <= 32'h0;
            reg_count     <= 32'h0;
            reg_status    <= 32'h0;
            aw_done       <= 1'b0;
            w_done        <= 1'b0;
            wr_applied    <= 1'b0;
            awaddr_r      <= {ADDR_WIDTH{1'b0}};
            wdata_r       <= {DATA_WIDTH{1'b0}};
            araddr_r      <= {ADDR_WIDTH{1'b0}};
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BVALID  <= 1'b0;
            S_AXI_BRESP   <= RESP_OKAY;
            S_AXI_ARREADY <= 1'b0;
            S_AXI_RVALID  <= 1'b0;
            S_AXI_RDATA   <= 32'h0;
            S_AXI_RRESP   <= RESP_OKAY;
        end else begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_ARREADY <= 1'b0;

            case (state)
                ST_IDLE: begin
                    S_AXI_BVALID <= 1'b0;
                    S_AXI_RVALID <= 1'b0;
                    aw_done      <= 1'b0;
                    w_done       <= 1'b0;
                    wr_applied   <= 1'b0;

                    if (S_AXI_ARVALID) begin
                        S_AXI_ARREADY <= 1'b1;
                        araddr_r      <= S_AXI_ARADDR;
                        state         <= ST_READ_RESP;
                    end else begin
                        if (S_AXI_AWVALID) begin
                            S_AXI_AWREADY <= 1'b1;
                            awaddr_r      <= S_AXI_AWADDR;
                            aw_done       <= 1'b1;
                        end
                        if (S_AXI_WVALID) begin
                            S_AXI_WREADY <= 1'b1;
                            wdata_r      <= S_AXI_WDATA;
                            w_done       <= 1'b1;
                        end

                        if (S_AXI_AWVALID && S_AXI_WVALID)
                            state <= ST_WRITE_RESP;
                        else if (S_AXI_AWVALID || S_AXI_WVALID)
                            state <= ST_WRITE_ACCEPT;
                    end
                end

                ST_WRITE_ACCEPT: begin
                    if (!aw_done && S_AXI_AWVALID) begin
                        S_AXI_AWREADY <= 1'b1;
                        awaddr_r      <= S_AXI_AWADDR;
                        aw_done       <= 1'b1;
                    end
                    if (!w_done && S_AXI_WVALID) begin
                        S_AXI_WREADY <= 1'b1;
                        wdata_r      <= S_AXI_WDATA;
                        w_done       <= 1'b1;
                    end

                    if ((aw_done || S_AXI_AWVALID) && (w_done || S_AXI_WVALID))
                        state <= ST_WRITE_RESP;
                end

                ST_WRITE_RESP: begin
                    S_AXI_BVALID <= 1'b1;
                    S_AXI_BRESP  <= wr_resp;

                    if (!wr_applied) begin
                        wr_applied <= 1'b1;

                        if (wr_to_ctrl) begin
                            reg_ctrl <= wdata_r;
                            if (wdata_r[1])
                                reg_count <= 32'h0;
                        end
                        if (wr_to_load)
                            reg_load <= wdata_r;
                        if (wr_to_status)
                            reg_status <= reg_status & ~wdata_r;
                    end

                    if (S_AXI_BVALID && S_AXI_BREADY) begin
                        S_AXI_BVALID <= 1'b0;
                        state        <= ST_IDLE;
                        aw_done      <= 1'b0;
                        w_done       <= 1'b0;
                        wr_applied   <= 1'b0;
                    end
                end

                ST_READ_RESP: begin
                    S_AXI_RVALID <= 1'b1;

                    if (araddr_r[7:4] != 4'h0) begin
                        S_AXI_RDATA <= 32'h0;
                        S_AXI_RRESP <= RESP_DECERR;
                    end else begin
                        case (araddr_r[3:0])
                            4'h0: begin S_AXI_RDATA <= reg_ctrl;   S_AXI_RRESP <= RESP_OKAY; end
                            4'h4: begin S_AXI_RDATA <= reg_load;   S_AXI_RRESP <= RESP_OKAY; end
                            4'h8: begin S_AXI_RDATA <= reg_count;  S_AXI_RRESP <= RESP_OKAY; end
                            4'hC: begin S_AXI_RDATA <= reg_status; S_AXI_RRESP <= RESP_OKAY; end
                            default: begin
                                S_AXI_RDATA <= 32'h0;
                                S_AXI_RRESP <= RESP_DECERR;
                            end
                        endcase
                    end

                    if (S_AXI_RVALID && S_AXI_RREADY) begin
                        S_AXI_RVALID <= 1'b0;
                        state        <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase

            if (enable) begin
                if (!(state == ST_WRITE_RESP && !wr_applied && wr_to_ctrl && wdata_r[1])) begin
                    if (reg_count == 32'hFFFF_FFFF)
                        reg_status[0] <= 1'b1;
                    reg_count <= reg_count + 32'd1;
                end
            end
        end
    end

endmodule
