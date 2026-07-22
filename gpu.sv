module gpu (
    input logic clk,
    input logic reset,

    input logic uart_clk,
    input logic [7:0] uart_byte,
    input logic uart_valid,

    input logic mig_clk,
    input logic next_w_packet,
    input logic next_aw_packet,
    output logic [48:0] write_request,
    output logic [23:0] address_write_request, 
    output logic wpacket_valid,
    output logic awpacket_valid
);

// logic for creating all of the gpu cores

logic add_instr;
logic [18:0] next_instr;
logic wempty[16];
logic awempty[16];
logic [48:0] wpacket[16];
logic [23:0] awpacket[16];
logic w_en[16];
logic aw_en[16];
logic word_finished = 1'b0;

genvar i;
genvar j;
generate
    for (i = 0; i < 4; i++) begin : CORE_GEN_X
        for (j = 0; j < 4; j++) begin :CORE_GEN_Y
            core #(
                .X(j),
                .Y(i)
            ) cores (
                .clk(clk),
                .uart_clk(uart_clk),
                .mig_clk(mig_clk),
                .reset(reset),
                .queue_instruction(next_instr),
                .queue_instruction_en(word_finished),
                .w_en(w_en[j+4*i]),
                .aw_en(aw_en[j+4*i]),
                .wpacket(wpacket[j+4*i]),
                .awpacket(awpacket[j+4*i]),
                .w_empty(wempty[j+4*i]),
                .aw_empty(awempty[j+4*i])
            );
        end
    end
endgenerate

// logic for the uart submitting instructions to the cores

logic [1:0] uart_byte_count = 2'b0;

always_ff @ (posedge uart_clk) begin
    if (uart_valid) begin
        uart_byte_count <= uart_byte_count + 1;
        next_instr <= {next_instr[10:0], uart_byte};
        if (uart_byte_count == 2'd2) begin
            uart_byte_count <= 2'b0;
            word_finished <= 1'b1;
        end
    end
    if (word_finished) begin
        word_finished = 1'b0;
    end
end

always_comb begin
    add_instr = word_finished;
end

// logic for scheduling write requests to the mig
logic idle = 1'b1;
logic [3:0] current_core = 4'b0;
logic wfinished;
logic awfinished;
always_ff @ (posedge mig_clk) begin
    if (idle) begin
        wfinished <= 1'b0;
        awfinished <= 1'b0;
        if (~wempty[current_core] & ~awempty[current_core]) begin
            idle <= 1'b0;
        end else begin
            current_core <= current_core + 1;
        end
    end else begin
        if (next_w_packet) begin
            wfinished <= 1'b1;
        end
        if (next_aw_packet) begin
            awfinished <= 1'b1;
        end
        if (awfinished & wfinished) begin
            current_core <= current_core + 1;
            idle <= 1'b1;
        end
    end
end

always_comb begin
    write_request = wpacket[current_core];
    address_write_request = awpacket[current_core];
    wpacket_valid = ~idle & ~wfinished;
    awpacket_valid = ~idle & ~awfinished;
end

generate
    for (i = 0; i < 4; i++) begin 
        for (j = 0; j < 4; j++) begin 
            assign w_en[j+4*i] = awfinished & wfinished & ~idle & (current_core == j+4*i);
            assign aw_en[j+4*i] = awfinished & wfinished & ~idle & (current_core == j+4*i);
        end
    end
endgenerate

endmodule