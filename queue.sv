module queue #(
    parameter DATA_SIZE = 8,
    parameter QUEUE_SIZE = 8
) (
    input logic clk,
    input logic enqueue,
    input logic [DATA_SIZE - 1:0] enqueue_data,
    input logic dequeue,
    output logic enqueue_success,
    output logic [DATA_SIZE - 1:0] dequeue_data,
    output logic empty,
    output logic full
);

localparam POINTER_SIZE = $clog2(QUEUE_SIZE);

logic [DATA_SIZE-1:0] ram [QUEUE_SIZE-1:0];
logic [POINTER_SIZE - 1:0] head = 0;
logic [POINTER_SIZE - 1:0] tail = 0;

assign empty = head == tail;
assign full = head == (tail + 1'b1);
assign enqueue_success = enqueue & ~full; //Signal that enqeue finished

always_ff @ (posedge clk) begin
    // Allows the queue to have first element the next cycle
    dequeue_data <= empty ? enqueue_data : ram[head];
    if (dequeue) begin
        head <= head + 1'b1;
        dequeue_data <= ram[head + 1'b1];
    end
    if (enqueue & ~full) begin
        ram[tail] <= enqueue_data;
        tail <= tail + 1'b1;
    end
end



endmodule