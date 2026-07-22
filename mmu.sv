module mmu (
input logic clk,

input logic [23:0] aw_packet,
input logic aw_packet_valid,
output logic next_aw_packet,

input logic [48:0] w_packet,
input logic w_packet_valid,
output logic next_w_packet,

input logic start_reads,

output logic add_pixel_reads,
output logic [127:0] pixel_reads,


//AXI ports
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
input logic rlast,
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



always_comb begin
    awaddr = {7'b0, aw_packet[18:3], 4'b0};
    awlen = {3'b0, aw_packet[23:19]};
    awvalid = aw_packet_valid;
    next_aw_packet = awvalid & awready;
end



// Logic for w channel
logic [15:0] wstrb_shift_first;
logic [15:0] wstrb_shift_last;
logic first = 1'b1;
logic [4:0] num_bursts;
logic [4:0] burst_count = 5'b0;




always_ff @ (posedge clk) begin
    if (next_w_packet) begin
        burst_count <= 0;
    end else if (wvalid & wready) begin
        burst_count <= burst_count + 1;
    end

    if (next_w_packet) begin
        first <= 1'b1;
    end else if (first & wvalid & wready) begin
        first <= 1'b0;
    end
end

always_comb begin
    num_bursts = w_packet[16:12];
    wlast = num_bursts == burst_count;
    wvalid = w_packet_valid;
    next_w_packet = wvalid & wready & wlast;
    wstrb_shift_first = w_packet[32:17];
    wstrb_shift_last = w_packet[48:33];
    wdata = {8{4'b0,w_packet[11:0]}};
    if (first & wlast) begin
        wstrb = wstrb_shift_first & wstrb_shift_last;
    end else if (first) begin
        wstrb = wstrb_shift_first;
    end else if (wlast) begin
        wstrb = wstrb_shift_last;
    end else begin
        wstrb = 16'hFFFF;
    end
end

// logic for b channel

assign bready = 1'b1;

// logic for ar channel

assign arid = 1'b0;
assign arlen = 8'd79;
assign arsize = 3'b100;
assign arburst = 2'b01;
assign arlock = 1'b0;
assign arcache = 4'b0;
assign arprot = 3'b0;
assign arqos = 4'b0;

logic [19:0] next_read_addr = 20'b0;
logic adding_pixel_values = 1'b0;

always_ff @ (posedge clk or posedge reset) begin
    if (reset) begin
       next_read_addr = 0; 
    end else begin
        if (arvalid & arready) begin
            next_read_addr <= araddr == 20'd613120 ? 0 : next_read_addr + 1280; 
        end
        if (~adding_pixel_values) begin
            arvalid <= start_reads;
            adding_pixel_values <= start_reads;
        end else begin
            if (arvalid & arready) begin
                arvalid <= 1'b0;
            end
            adding_pixel_values <= ~rlast;
        end
    end
end

always_comb begin
    araddr = {7'b0, next_read_addr};
end

// logic for r channel

assign rready = 1'b1;
assign pixel_reads = rdata;

always_comb begin
    add_pixel_reads = rready & rvalid;
end

endmodule
