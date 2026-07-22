module uart_controller (
    input logic clk,
    input logic rxd,
    input logic reset,
    output logic [7:0] data,
    output logic valid
);

localparam IDLE = 2'b0;
localparam START = 2'b1;
localparam DATA = 2'd2;
localparam STOP = 2'd3;

logic [1:0] state = IDLE;
logic [9:0] counter = 10'b0;
logic [2:0] bit_count = 3'b0;
logic half_check;
logic full_check;
logic rxd_meta;
logic rxd_sync;

assign half_check = counter == 10'd433;
assign full_check = counter == 10'd867;



always_ff @(posedge clk) begin
    rxd_meta <= rxd;
    rxd_sync <= rxd_meta;
end

always_ff @ (posedge clk or posedge reset) begin
    if (reset) begin
        state <= IDLE;
    end else begin
        if (state == IDLE) begin
            valid <= 1'b0;
            state <= rxd_sync ? IDLE : START;
            bit_count <= 3'b0;
            counter <= 10'b0;
        end else if (state == START) begin
            valid <= 1'b0;
            counter <= counter + 1;
            if (half_check) begin
            state <= rxd_sync ? IDLE : DATA;
            counter <= 10'b0;
            end
        end else if (state == DATA) begin
            valid <= 1'b0;
            counter <= counter + 1;
            if (full_check) begin
                bit_count <= bit_count + 1;
                data[bit_count] <= rxd_sync;
                counter <= 10'b0;
                if (bit_count == 3'd7) begin
                    state <= STOP;
                end
            end

        end else begin
            counter <= counter + 1;
            valid <= 1'b0;
            if (full_check) begin
                state <= IDLE;
                valid <= rxd_sync;
                counter <= 10'b0;
            end
        end
    end
end

endmodule