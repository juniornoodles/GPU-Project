module core #(
    parameter X = 0, // coordinates based on the tile area the 
    parameter Y = 0 // core manages
) (
    input logic clk,
    input logic uart_clk,
    input logic mig_clk,
    input logic reset,
    input logic [18:0] queue_instruction,
    input logic queue_instruction_en,
    input logic w_en,
    input logic aw_en,
    output logic [48:0] wpacket,
    output logic [23:0] awpacket,
    output logic w_empty,
    output logic aw_empty
);



localparam BASEADDR = (X * 320) + (Y * 153600);
localparam LEFT_EDGE = X * 160;
localparam RIGHT_EDGE = X * 160 + 159;
localparam TOP_EDGE = Y * 120;
localparam BOTTOM_EDGE = Y * 120 + 119;
localparam CLEAR = 3'd0;
localparam SET_COLOR = 3'd1;
localparam DRAW_TRIANGLE = 3'd2;
localparam DRAW_LINE = 3'd3;
localparam DRAW_RECT = 3'd4;
localparam FILL_RECT = 3'd5;
localparam DRAW_SPRITE = 3'd6;
localparam SWAP_BUFFER = 3'd7;

// States for recieving instruction packets
localparam IDLE_INSTR =  3'd0;
localparam CORD1 = 3'd1;
localparam CORD2 = 3'd2;
localparam CORD3 = 3'd3;
localparam BUSY = 3'd4;

// Logic for recieving instruction packets
logic valid;
logic get_next = 1'b0;
logic [18:0] next_instruction;
logic ready_for_next; 
logic [2:0] instr_state = IDLE_INSTR;
logic start = 1'b0;
logic [2:0] opcode;
logic [11:0] clear_color;
logic [11:0] color;
logic [9:0] x1;
logic [8:0] y1;
logic [9:0] x2;
logic [8:0] y2;
logic [9:0] x3;
logic [8:0] y3;

always_ff @ (posedge clk or posedge reset) begin
    if (reset) begin
        instr_state <= IDLE_INSTR;
    end else begin
        if (instr_state == IDLE_INSTR) begin
            if (valid) begin
                opcode <= next_instruction[2:0];
                case (next_instruction[2:0])
                    CLEAR: begin
                        clear_color <= next_instruction[14:3];
                        instr_state <= BUSY;
                        start <= 1'b1;
                    end

                    SET_COLOR: begin
                        color <= next_instruction[14:3];
                    end

                    SWAP_BUFFER: begin
                        instr_state <= BUSY;
                    end

                    default: begin
                        instr_state <= CORD1;
                    end
                endcase
            end
        end else if (instr_state == CORD1) begin
            if (valid) begin
                x1 <= next_instruction[9:0];
                y1 <= next_instruction[18:10];
                instr_state <= CORD2;
            end
        end else if (instr_state == CORD2) begin
            if (valid) begin
                x2 <= next_instruction[9:0];
                y2 <= next_instruction[18:10];
                start <= opcode != DRAW_TRIANGLE;
                instr_state <= opcode != DRAW_TRIANGLE ? BUSY : CORD3;
            end
        end else if (instr_state == CORD3) begin
            if (valid) begin
                x3 <= next_instruction[9:0];
                y3 <= next_instruction[18:10];
                start <= 1'b1;
                instr_state <= BUSY;
            end
        end else if (instr_state == BUSY) begin
            start <= 1'b0;
            if(ready_for_next) begin
                instr_state <= IDLE_INSTR;
            end
        end
    end
end

always_comb begin
    get_next = instr_state != BUSY & valid;
end

// States for the core's computation

localparam IDLE_CALC = 0;
localparam CLEAR_CALC = 1;
localparam DRAW_TRIANGLE_CALC = 2;
localparam DRAW_LINE_CALC = 3;  
localparam DRAW_RECT_CALC = 4;
localparam FILL_RECT_CALC = 5;

// Logic to generate signals to send to mmu

logic [6:0] awline;
logic [6:0] wline;
logic awfinished;
logic wfinished;
logic write_ready;
logic waddr_ready;
logic [19:0] temp_waddr;
logic [2:0] calc_state = IDLE_CALC;
logic [48:0] write_request;
logic write_request_en;
logic [23:0] writeaddress_request;
logic writeaddress_request_en;
logic [15:0] wstrb_shift_first;
logic [15:0] wstrb_shift_last;
logic [4:0] wnum_bursts;
logic [4:0] awnum_bursts;
logic skip;
logic [9:0] xstart_pixel;
logic [9:0] xend_pixel;
logic [19:0] xstart_addr;
logic [9:0] x_draw_line;
logic [8:0] y_draw_line;
logic signed [11:0] dx_draw_line;
logic signed [11:0] dy_draw_line;
logic [9:0] dy_draw_line_choices[2];
logic signed [11:0] err_sums[3];
logic signed [11:0] neg_dy_draw_line;
logic sy_draw_line;
logic signed [11:0] err_draw_line;
logic signed [12:0] e2_draw_line;
logic signed [12:0] e2_draw_line_prev;
logic [8:0] pixels_in_a_row;
logic [9:0] xstart_pixel_draw_line;
logic [1:0] draw_line_state;    
localparam IDLE_LINE = 0;
localparam START_LINE = 1;
localparam COMPUTE_LINE = 2;
logic [9:0] x_min_draw_tri;
logic [8:0] y_min_draw_tri;
logic [9:0] x_max_draw_tri;
logic [8:0] y_max_draw_tri;
logic [2:0] counter;
logic signed [12:0] a0_draw_tri;
logic signed [12:0] b0_draw_tri;
logic signed [31:0] c0_draw_tri;
logic signed [12:0] a1_draw_tri;
logic signed [12:0] b1_draw_tri;
logic signed [31:0] c1_draw_tri;
logic signed [12:0] a2_draw_tri;
logic signed [12:0] b2_draw_tri;
logic signed [31:0] c2_draw_tri;
logic signed [31:0] c_multiplies[6];
logic signed [31:0] a_multiplies[3];
logic signed [31:0] b_multiplies[3];
logic signed [31:0] e0_draw_tri;
logic signed [31:0] e1_draw_tri;
logic signed [22:0] e2_draw_tri;
logic signed [22:0] e0_start_draw_tri;
logic signed [22:0] e1_start_draw_tri;
logic signed [22:0] e2_start_draw_tri;
logic signed [11:0] x_draw_tri;
logic signed [11:0] y_draw_tri;
logic [9:0] xstart_pixel_draw_tri;
logic [1:0] draw_tri_state;
logic inside_tri;
logic inside_tri_prev;
localparam IDLE_TRI = 0;
localparam START_TRI = 1;
localparam COMPUTE_TRI = 2;


always_ff @ (posedge clk or posedge reset) begin
    if (reset) begin
        calc_state <= IDLE_CALC;
    end else begin
        if (calc_state == IDLE_CALC) begin
            ready_for_next <= 1'b0;
            awfinished <= 0;
            wfinished <= 0;
            awline <= 0;
            wline <= 0;
            temp_waddr <= BASEADDR;
            draw_line_state <= START_LINE;
            draw_tri_state <= START_TRI;
            counter <= 3'b0;
            pixels_in_a_row <= 1'b0;
            if(start) begin
                case (opcode)
                    CLEAR: calc_state <= CLEAR_CALC;
                    DRAW_TRIANGLE: calc_state <= DRAW_TRIANGLE_CALC;
                    DRAW_LINE: calc_state <= DRAW_LINE_CALC;
                    DRAW_RECT: calc_state <= DRAW_RECT_CALC;
                    FILL_RECT: calc_state <= FILL_RECT_CALC;

                endcase
            end
        end else if (calc_state == CLEAR_CALC) begin
            if (waddr_ready) begin
                awline <= awline + 1;
                temp_waddr <= temp_waddr + 11'd1280;
                if (awline == 7'd119) begin
                    awfinished <= 1'b1;
                end
            end
            if (write_ready) begin
                wline <= wline + 1;
                if (wline == 7'd119) begin
                    wfinished <= 1'b1;
                end
            end
            if (wfinished & awfinished) begin
                calc_state <= IDLE_CALC;
                ready_for_next <= 1'b1;
            end
        end else if (calc_state == DRAW_TRIANGLE_CALC) begin
            case (draw_tri_state)
                START_TRI: begin
                    case (counter)
                        3'b0: begin
                            inside_tri_prev <= 1'b0;
                            x_min_draw_tri <= x1 < LEFT_EDGE ? LEFT_EDGE : x1;
                            x_max_draw_tri <= x1 > RIGHT_EDGE ? RIGHT_EDGE : x1;
                            y_min_draw_tri <= y1 < TOP_EDGE ? TOP_EDGE : y1;
                            y_max_draw_tri <= y1 > BOTTOM_EDGE ? BOTTOM_EDGE : y1;
                            a0_draw_tri <= $signed({1'b0, y2}) - $signed({1'b0, y1});
                            b0_draw_tri <= $signed({1'b0, x1}) - $signed({1'b0, x2});
                            a1_draw_tri <= $signed({1'b0, y3}) - $signed({1'b0, y2});
                            b1_draw_tri <= $signed({1'b0, x2}) - $signed({1'b0, x3});
                            a2_draw_tri <= $signed({1'b0, y1}) - $signed({1'b0, y3});
                            b2_draw_tri <= $signed({1'b0, x3}) - $signed({1'b0, x1});
                            c_multiplies[0] <= x2 * y1;
                            c_multiplies[1] <= x1 * y2;
                            c_multiplies[2] <= x3 * y2;
                            c_multiplies[3] <= x2 * y3;
                            c_multiplies[4] <= x1 * y3;
                            c_multiplies[5] <= x3 * y1;
                            counter <= counter + 1'b1;
                        end

                        3'b1: begin
                            x_min_draw_tri <= x2 > x_min_draw_tri ? x_min_draw_tri : (x2 < LEFT_EDGE ? LEFT_EDGE : x2);
                            x_max_draw_tri <= x2 < x_max_draw_tri ? x_max_draw_tri : (x2 > RIGHT_EDGE ? RIGHT_EDGE : x2);
                            y_min_draw_tri <= y2 > y_min_draw_tri ? y_min_draw_tri : (y2 < TOP_EDGE ? TOP_EDGE : y2);
                            y_max_draw_tri <= y2 < y_max_draw_tri ? y_max_draw_tri : (y2 > BOTTOM_EDGE ? BOTTOM_EDGE : y2);
                            c0_draw_tri = c_multiplies[0] - c_multiplies[1];
                            c1_draw_tri = c_multiplies[2] - c_multiplies[3];
                            c2_draw_tri = c_multiplies[4] - c_multiplies[5];
                            counter <= counter + 1'b1;
                        end

                        3'd2: begin
                            x_min_draw_tri <= x3 > x_min_draw_tri ? x_min_draw_tri : (x3 < LEFT_EDGE ? LEFT_EDGE : x3);
                            x_max_draw_tri <= x3 < x_max_draw_tri ? x_max_draw_tri : (x3 > RIGHT_EDGE ? RIGHT_EDGE : x3);
                            y_min_draw_tri <= y3 > y_min_draw_tri ? y_min_draw_tri : (y3 < TOP_EDGE ? TOP_EDGE : y3);
                            y_max_draw_tri <= y3 < y_max_draw_tri ? y_max_draw_tri : (y3 > BOTTOM_EDGE ? BOTTOM_EDGE : y3);
                            x_draw_tri <= x3 > x_min_draw_tri ? x_min_draw_tri : (x3 < LEFT_EDGE ? LEFT_EDGE : x3);
                            y_draw_tri <= y3 > y_min_draw_tri ? y_min_draw_tri : (y3 < TOP_EDGE ? TOP_EDGE : y3);
                            counter <= counter + 1'b1;
                        end

                        3'd3: begin
                            if (skip) begin
                                calc_state <= IDLE_CALC;
                                ready_for_next <= 1'b1;
                            end
                            a_multiplies[0] <= a0_draw_tri * x_draw_tri;
                            a_multiplies[1] <= a1_draw_tri * x_draw_tri;
                            a_multiplies[2] <= a2_draw_tri * x_draw_tri;
                            b_multiplies[0] <= b0_draw_tri * y_draw_tri;
                            b_multiplies[1] <= b1_draw_tri * y_draw_tri;
                            b_multiplies[2] <= b2_draw_tri * y_draw_tri;
                            counter <= counter + 1'b1;
                            temp_waddr <= y_draw_tri * 19'd1280;
                        end

                        3'd4: begin
                            e0_start_draw_tri <= a_multiplies[0]+ b_multiplies[0] + c0_draw_tri;
                            e1_start_draw_tri <= a_multiplies[1]+ b_multiplies[1] + c1_draw_tri;
                            e2_start_draw_tri <= a_multiplies[2]+ b_multiplies[2] + c2_draw_tri;
                            e0_draw_tri <= a_multiplies[0]+ b_multiplies[0] + c0_draw_tri;
                            e1_draw_tri <= a_multiplies[1]+ b_multiplies[1] + c1_draw_tri;
                            e2_draw_tri <= a_multiplies[2]+ b_multiplies[2] + c2_draw_tri;
                            counter <= 2'b0;
                            draw_tri_state <= COMPUTE_TRI;
                        end
                    endcase
                end 

                COMPUTE_TRI: begin
                    e0_draw_tri <= e0_draw_tri + a0_draw_tri;
                    e1_draw_tri <= e1_draw_tri + a1_draw_tri;
                    e2_draw_tri <= e2_draw_tri + a2_draw_tri;
                    x_draw_tri <= x_draw_tri + 1'b1;
                    if (~inside_tri_prev) begin
                        if(inside_tri) begin
                            inside_tri_prev <= 1'b1;
                            xstart_pixel_draw_tri <= x_draw_tri;
                        end
                        if(x_draw_tri > x_max_draw_tri) begin
                            awfinished = 0;
                            wfinished = 0;
                            draw_tri_state <= IDLE_TRI;
                        end
                    end else begin
                        pixels_in_a_row <= pixels_in_a_row + 1'b1;
                        if(~inside_tri | (x_draw_tri == x_max_draw_tri)) begin
                            inside_tri_prev <= 1'b0;
                            pixels_in_a_row <= x_draw_tri == x_max_draw_tri ? pixels_in_a_row + 1 : pixels_in_a_row;
                            draw_tri_state <= IDLE_TRI;
                        end
                    end
                end

                IDLE_TRI: begin
                    if (waddr_ready) begin
                        awfinished <= 1'b1;
                    end
                    if (write_ready) begin
                        wfinished <= 1'b1;
                    end
                    if (wfinished & awfinished) begin
                        if (y_draw_tri == y_max_draw_tri) begin
                            calc_state <= IDLE_CALC;
                            ready_for_next <= 1'b1;
                        end
                        wfinished <= 1'b0;
                        awfinished <= 1'b0;
                        draw_tri_state <= COMPUTE_TRI;
                        pixels_in_a_row <= 8'b0;
                        y_draw_tri <= y_draw_tri + 1'b1;
                        temp_waddr <= temp_waddr + 19'd1280;
                        x_draw_tri <= x_min_draw_tri;
                        e0_start_draw_tri <= e0_start_draw_tri + b0_draw_tri;
                        e1_start_draw_tri <= e1_start_draw_tri + b1_draw_tri;
                        e2_start_draw_tri <= e2_start_draw_tri + b2_draw_tri;
                        e0_draw_tri <= e0_start_draw_tri + b0_draw_tri;
                        e1_draw_tri <= e1_start_draw_tri + b1_draw_tri;
                        e2_draw_tri <= e2_start_draw_tri + b2_draw_tri;
                    end
                end
            endcase
        end else if (calc_state == DRAW_LINE_CALC) begin
            if (skip & draw_line_state != START_LINE) begin
                calc_state <= IDLE_CALC;
                ready_for_next <= 1'b1;
            end
            case (draw_line_state)
                START_LINE: begin
                    case (counter)
                        1'b0: begin
                            x_draw_line <= x1;
                            y_draw_line <= y1;
                            dx_draw_line <= x2 - x1;
                            dy_draw_line_choices[0] <= y1 - y2;
                            dy_draw_line_choices[1] <= y2 - y1;
                            pixels_in_a_row <= 8'b0;
                            temp_waddr <= y1 * 19'd1280;
                            xstart_pixel_draw_line <= x1;
                            sy_draw_line <= y2 > y1;
                            counter <= counter + 1'b1;
                        end 

                        1'b1: begin
                            dy_draw_line <= sy_draw_line ? dy_draw_line_choices[1] : dy_draw_line_choices[0];
                            counter <= counter + 1'b1;
                        end

                        2'd2: begin
                            err_draw_line <= dx_draw_line - dy_draw_line;
                            counter <= 1'b0;
                            draw_line_state <= COMPUTE_LINE;
                        end
                    endcase
                end

                COMPUTE_LINE: begin
                    awfinished <= 1'b0;
                    wfinished <= 1'b0;
                    case (counter)
                        3'b0: begin
                            err_sums[0] <= e2_draw_line > neg_dy_draw_line ? dy_draw_line : 1'b0;
                            err_sums[1] <= e2_draw_line < dx_draw_line ? dx_draw_line : 1'b0;
                            counter <= counter + 1'b1;
                        end 

                        3'b1: begin
                            err_sums[2] <= err_sums[1] - err_sums[0];
                            counter <= counter + 1'b1;
                        end

                        3'd2: begin
                            if (e2_draw_line > neg_dy_draw_line) begin
                                x_draw_line <= x_draw_line + 1'b1;
                            end
                            if (e2_draw_line < dx_draw_line) begin
                                draw_line_state <= IDLE_LINE;
                            end else begin
                                pixels_in_a_row <= pixels_in_a_row + 1'b1;
                            end
                            err_draw_line <= err_draw_line + err_sums[2];
                            counter <= 1'b0;
                        end
                    endcase
                end

                IDLE_LINE: begin
                    if (waddr_ready) begin
                        awfinished <= 1'b1;
                    end
                    if (write_ready) begin
                        wfinished <= 1'b1;
                    end
                    if (wfinished & awfinished) begin
                        draw_line_state <= COMPUTE_LINE;
                        pixels_in_a_row <= 8'b0;
                        y_draw_line <= sy_draw_line ? y_draw_line + 1'b1 : y_draw_line - 1'b1;
                        temp_waddr <= sy_draw_line ? temp_waddr + 11'd1280 : temp_waddr - 11'd1280;
                        xstart_pixel_draw_line <= x_draw_line;
                    end
                end
            endcase
        end else if (calc_state == DRAW_RECT_CALC) begin
            if (waddr_ready) begin
                awline <= awline + 1;
                temp_waddr <= temp_waddr + 1280;
                if (awline == 7'd119) begin
                    awfinished <= 1'b1;
                end
            end
            if (write_ready) begin
                wline <= wline + 1;
                if (wline == 7'd119) begin
                    wfinished <= 1'b1;
                end
            end
            if ((wfinished & awfinished) | skip) begin
                calc_state <= IDLE_CALC;
                ready_for_next <= 1'b1;
            end
        end else if (calc_state == FILL_RECT_CALC) begin
            if (waddr_ready) begin
                awline <= awline + 1;
                temp_waddr <= temp_waddr + 1280;
                if (awline == 7'd119) begin
                    awfinished <= 1'b1;
                end
            end
            if (write_ready) begin
                wline <= wline + 1;
                if (wline == 7'd119) begin
                    wfinished <= 1'b1;
                end
            end
            if ((wfinished & awfinished) | skip) begin
                calc_state <= IDLE_CALC;
                ready_for_next <= 1'b1;
            end
        end
    end
end

always_comb begin
    case (calc_state)
        IDLE_CALC: begin
            writeaddress_request_en = 1'b0;
            writeaddress_request = 24'b0;
            write_request = 49'b0;
            write_request_en = 1'b0;
        end

        CLEAR_CALC: begin
            writeaddress_request_en = waddr_ready & ~awfinished;
            writeaddress_request = {5'd19, temp_waddr[19:1]};
            write_request = {32'hffffffff, 5'd19, clear_color};
            write_request_en = write_ready & ~wfinished;
        end

        DRAW_TRIANGLE_CALC: begin
            xstart_pixel = xstart_pixel_draw_tri < LEFT_EDGE ? 10'b0 : (xstart_pixel_draw_tri - LEFT_EDGE) << 1'b1;
            xend_pixel = xstart_pixel + (pixels_in_a_row << 1'b1);
            xstart_addr = temp_waddr + xstart_pixel + (LEFT_EDGE << 1'b1);
            skip = (x_min_draw_tri > RIGHT_EDGE) | (x_max_draw_tri < LEFT_EDGE) | (y_min_draw_tri > BOTTOM_EDGE) | (y_max_draw_tri < TOP_EDGE);
            inside_tri = ((e0_draw_tri <= 0) & (e1_draw_tri <= 0) & (e2_draw_tri <= 0)) |
            ((e0_draw_tri >= 0) & (e1_draw_tri >= 0) & (e2_draw_tri >= 0));
            awnum_bursts = (xend_pixel >> 3'd4) - (xstart_pixel >> 3'd4);
            wnum_bursts = (xend_pixel >> 3'd4) - (xstart_pixel >> 3'd4);
            wstrb_shift_first = 16'hffff << xstart_pixel[3:0];
            wstrb_shift_last = 16'hffff >> (4'd14 - xend_pixel[3:0]);
            writeaddress_request = {awnum_bursts, xstart_addr[19:1]};
            write_request = {wstrb_shift_last, wstrb_shift_first, wnum_bursts, color};
            write_request_en = write_ready & ~wfinished & (draw_tri_state == IDLE_TRI);
            writeaddress_request_en = waddr_ready & ~awfinished & (draw_tri_state == IDLE_TRI);
        end


        DRAW_LINE_CALC: begin
            xstart_pixel = xstart_pixel_draw_line < LEFT_EDGE ? 10'b0 : (xstart_pixel_draw_line - LEFT_EDGE) << 1'b1;
            skip = (x_draw_line >= RIGHT_EDGE) | (x_draw_line == x2 & y_draw_line == y2);
            xend_pixel = xstart_pixel + (pixels_in_a_row << 1'b1) + (skip ? 2'd2 : 2'b0);
            xstart_addr = temp_waddr + xstart_pixel + (LEFT_EDGE << 1'b1);
            neg_dy_draw_line = 1'b0 - dy_draw_line;
            e2_draw_line = err_draw_line << 1'b1;
            awnum_bursts = (xend_pixel >> 3'd4) - (xstart_pixel >> 3'd4);
            wnum_bursts = (xend_pixel >> 3'd4) - (xstart_pixel >> 3'd4);
            wstrb_shift_first = 16'hffff << xstart_pixel[3:0];
            wstrb_shift_last = 16'hffff >> (4'd14 - xend_pixel[3:0]);
            writeaddress_request = {awnum_bursts, xstart_addr[19:1]};
            write_request = {wstrb_shift_last, wstrb_shift_first, wnum_bursts, color};
            write_request_en = write_ready & ~wfinished & draw_line_state != START_LINE & (y_draw_line >= TOP_EDGE) & (y_draw_line <= BOTTOM_EDGE) & (x_draw_line >= LEFT_EDGE) & (x_draw_line <= RIGHT_EDGE) & (skip | draw_line_state == IDLE_LINE);
            writeaddress_request_en = waddr_ready & ~awfinished & draw_line_state != START_LINE & (y_draw_line >= TOP_EDGE) & (y_draw_line <= BOTTOM_EDGE) & (x_draw_line >= LEFT_EDGE) & (x_draw_line <= RIGHT_EDGE) & (skip | draw_line_state == IDLE_LINE);
        end

        DRAW_RECT_CALC: begin
            if ((LEFT_EDGE > x1 + x2) | (RIGHT_EDGE < x1) | (TOP_EDGE > y1 + y2) | 
            (BOTTOM_EDGE < y1) | (awline + TOP_EDGE > y1 + y2 & wline + TOP_EDGE > y1 + y2)) begin
                skip = 1'b1;
            end else begin
                skip = 1'b0;
            end
            xstart_pixel = x1 < LEFT_EDGE ? 10'b0 : (x1 - LEFT_EDGE) << 1'b1;
            xend_pixel = x1 + x2 > RIGHT_EDGE ? 10'd318 : (x1 + x2 - LEFT_EDGE) << 1'b1;
            xstart_addr = temp_waddr + xstart_pixel;
            if (awline + TOP_EDGE == y1 | awline + TOP_EDGE == y1 + y2) begin
                awnum_bursts = (xend_pixel >> 3'd4) - (xstart_pixel >> 3'd4);
            end else begin
                awnum_bursts = 1'b0;
            end

            if (wline + TOP_EDGE == y1 | wline + TOP_EDGE == y1 + y2) begin
                wnum_bursts = (xend_pixel >> 3'd4) - (xstart_pixel >> 3'd4);
                wstrb_shift_first = 16'hffff << xstart_pixel[3:0];
                wstrb_shift_last = 16'hffff >> (4'd14 - xend_pixel[3:0]);
            end else begin
                wnum_bursts = 1'b0;
                wstrb_shift_first = 16'hffff << xstart_pixel[3:0];
                wstrb_shift_last = 16'hffff >> (4'd14 - xstart_pixel[3:0]);
            end
            writeaddress_request = {awnum_bursts, xstart_addr[19:1]};
            write_request = {wstrb_shift_last, wstrb_shift_first, wnum_bursts, color};
            write_request_en = write_ready & ~wfinished & ~skip & ~(wline + TOP_EDGE < y1);
            writeaddress_request_en = waddr_ready & ~awfinished & ~skip & ~(awline + TOP_EDGE < y1);                            
        end

        FILL_RECT_CALC: begin
            if ((LEFT_EDGE > x1 + x2) | (RIGHT_EDGE < x1) | (TOP_EDGE > y1 + y2) | 
            (BOTTOM_EDGE < y1) | (awline + TOP_EDGE > y1 + y2 & wline + TOP_EDGE > y1 + y2)) begin
                skip = 1'b1;
            end else begin
                skip = 1'b0;
            end
            xstart_pixel = x1 < LEFT_EDGE ? 10'b0 : (x1 - LEFT_EDGE) << 1'b1 ;
            xend_pixel = x1 + x2 > RIGHT_EDGE ? 10'd318 : (x1 + x2 - LEFT_EDGE) << 1'b1;
            xstart_addr = temp_waddr + xstart_pixel;
            awnum_bursts = (xend_pixel >> 3'd4) - (xstart_pixel >> 3'd4);
            writeaddress_request = {awnum_bursts, xstart_addr[19:1]};
            wnum_bursts = (xend_pixel >> 3'd4) - (xstart_pixel >> 3'd4);
            wstrb_shift_first = 16'hffff << xstart_pixel[3:0];
            wstrb_shift_last = 16'hffff >> (4'd14 - xend_pixel[3:0]);
            write_request = {wstrb_shift_last, wstrb_shift_first, wnum_bursts, color};
            write_request_en = write_ready & ~wfinished & ~skip & ~(wline + TOP_EDGE < y1);
            writeaddress_request_en = waddr_ready & ~awfinished & ~skip & ~(awline + TOP_EDGE < y1);
        end
    endcase
end

logic empty;
logic wfull;
logic awfull;
assign valid = ~empty;
assign write_ready = ~wfull;
assign waddr_ready = ~awfull;
Core_FIFOs Core_FIFOs_inst (
    .din_0(queue_instruction),
    .wr_en_0(queue_instruction_en),
    .rd_en_0(get_next),
    .dout_0(next_instruction),
    .empty_0(empty),
    .wr_clk_0(uart_clk),
    .rst_0(reset),
    .rd_clk_0(clk),
    .dout_1(wpacket),
    .empty_1(w_empty),
    .wr_en_1(write_request_en),
    .din_1(write_request),
    .full_1(wfull),
    .wr_clk_1(clk),
    .rst_1(reset),
    .rd_en_1(w_en),
    .rd_clk_1(mig_clk),
    .empty_2(aw_empty),
    .wr_en_2(writeaddress_request_en),
    .din_2(writeaddress_request),
    .full_2(awfull),
    .wr_clk_2(clk),
    .rst_2(reset),
    .rd_en_2(aw_en),
    .dout_2(awpacket),
    .rd_clk_2(mig_clk)
);


endmodule
