    module pixel_buffer( // Would work for 640 x 480 resolution, but I made it 64 x 48 for easue of use
        input logic clk,
        input logic reset,
        input logic visible_x,
        input logic visible_y,
        input logic hsync,
        input logic vsync,
        input logic [127:0] pixel_reads,
        input logic [8:0] pixel_reads_left,
        output logic fill_buffer,
        output logic next_pixel_read,
        output logic [11:0] pixel_data 
    );
    localparam START_OF_PIXELS = 300;
    logic [9:0] x;
    logic [9:0] y;
    logic hsync_prev;
    logic vsync_prev;
    logic hsync_falling;
    logic vsync_falling;
    logic [3:0] count = 4'd0;
    logic hold = 1'b1;
    logic [8:0] pixel_reads_left_reg = 0;
    always_ff @(posedge clk) begin
        hsync_prev <= hsync;
        vsync_prev <= vsync;
        pixel_reads_left_reg <= pixel_reads_left;
    end
    assign hsync_falling = ~hsync & hsync_prev;
    assign vsync_falling = ~vsync & vsync_prev;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            x <= 0;
            y <= 0;
            hold <= 1;
            count <= 0;
        end else if (vsync_falling) begin
            x <= 0;
            y <= 0;
            if (~fill_buffer) begin
                hold <= 0;
            end
        end else if (hsync_falling) begin
            x <= 0;
            if(visible_y) begin
                y <= y + 1;
            end 
        end else if (visible_x & visible_y) begin
        x <= x + 1;
        end
    end

    always_comb begin
        pixel_data = (pixel_reads >> (x[2:0] << 3'd4));
        next_pixel_read = (x[2:0] == 3'd7) & ~hold;
        fill_buffer = (pixel_reads_left_reg < 9'd160) & ~reset;
    end

    endmodule