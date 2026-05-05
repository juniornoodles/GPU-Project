module mmu (
input logic clk,



output logic awid, //hardcoded
output logic [26:0] awaddr,
output logic [7:0] awlen,
output logic [2:0] awsize, //hardcoded
output logic [1:0] awburst, //hardcoded
output logic awlock, //hardcoded
output logic [3:0] awcache, //hardcoded
output logic [2:0] awprot, //hardcoded
output logic [3:0] awqos, //hardcoded
output logic awvalid,
input logic awready,
output logic [127:0] wdata,
output logic [15:0] wstrb,
output logic wlast,
output logic wvalid,
input logic wready,
output logic bready,
input logic bid, //unused
input logic [1:0] bresp,
input logic bvalid,
output logic arid, //hardcoded
output logic [26:0] araddr,
output logic [7:0] arlen, //hardcoded
output logic [2:0] arsize, //hardcoded
output logic [1:0] arburst, //hardcoded
output logic arlock, //hardcoded
output logic [3:0] arcache, //hardcoded
output logic [2:0] arprot, //hardcoded
output logic [3:0] arqos, //hardcoded
output logic arvalid,
input logic arready,
output logic rready,
input logic rid, //unused
input logic [127:0] rdata,
input logic [1:0] rresp,
input logic rlast, //unused
input logic rvalid

);

// Logic for aw channel

assign awid = 1'b0;
assign awsize = 3'b100;
assign awburst = 2'b01;
assign awlock = 1'b0;
assign awcache = 4'b0;
assign awprot = 3'b0;
assign awqos = 4'b0;

logic start_aw;
logic [11:0] next_waddr;
logic [2:0] next_burst_length;
logic aw_finished;

always_ff @ (posedge clk) begin
    if (start_aw) begin
        awaddr <= {11'b0,next_waddr,4'b0};
        awlen <= {5'b0,next_burst_length};
        awvalid <= 1'b1;
    end else begin
        awvalid <= 1'b0;
    end
end

always_comb begin
    if (awvalid & awready) begin
        aw_finished <= 1'b1;
    end else begin
        aw_finished <= 1'b0;
    end
end



// Logic for w channel
logic start_w;
logic [3:0] wstrb_shift_first;
logic [3:0] wstrb_shift_last;
logic first;
logic last;
logic [2:0] num_bursts;
logic [127:0] next_data;
logic w_finished;

assign wlast = num_bursts == 1;


always_ff @ (posedge clk) begin
    if (start_w) begin
        wvalid <= 1'b1;
        wdata <= next_data;
    end else begin
        wvalid <= 1'b0;
    end
end

always_comb begin
    if (first & wlast) begin
        wstrb = (16'hFFFF >> wstrb_shift_first)
        & (16'hFFFF << wstrb_shift_last);
    end else if (first) begin
        wstrb = (16'hFFFF >> wstrb_shift_first);
    end else if (last) begin
        wstrb = (16'hFFFF << wstrb_shift_last);
    end else begin
        wstrb = 16'hFFFF;
    end
    if (wvalid & wready & last) begin
        w_finished <= 1'b1;
    end else begin
        w_finished <= 1'b0;
    end
end

// logic for b channel

assign bresp = 1'b1;

// logic for ar channel

assign arid = 1'b0;
assign arlen = 8'd79;
assign arsize = 3'b100;
assign arburst = 2'b01;
assign arlock = 1'b0;
assign arcache = 4'b0;
assign arprot = 3'b0;
assign arqos = 4'b0;

logic start_ar;
logic ar_finished;

always_ff @ (posedge clk) begin
    if (start_ar) begin
        arvalid <= 1'b1;
    end else begin
        arvalid <= 1'b0;
    end
end

always_comb begin
    if (arvalid & arready) begin
        ar_finished <= 1'b1;
    end else begin
        ar_finished <= 1'b0;
    end
end

// logic for r channel

logic start_r;
logic r_finished;

always_ff @ (posedge clk) begin
    if (start_r) begin
        rready <= 1'b1;
    end else begin
        rready <= 1'b0;
    end
end

always_comb begin
    if (rvalid & rready) begin
        r_finished <= 1'b1;
    end else begin
        r_finished <= 1'b0;
    end
end

endmodule