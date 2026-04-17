`include "packet_defs.svh"
module fifo#(parameter int DEPTH  = 8)(
    input                     clk,
    input                     reset,
    input                     write_valid,
    input        [PACK_W-1:0] packet_in,
    input                     read_en,

    output logic [PACK_W-1:0] packet_out,
    output logic              packet_out_valid,
    output logic              full,
    output logic              empty
    
);

    logic [PACK_W-1:0]list[0:DEPTH-1];
    logic [$clog2(DEPTH)-1:0]head;
    logic [$clog2(DEPTH)-1:0]tail;
    logic [$clog2(DEPTH+1)-1:0]count;
    logic [$clog2(DEPTH)-1:0]head_n;
    logic [$clog2(DEPTH)-1:0]tail_n;
    logic [$clog2(DEPTH+1)-1:0]count_n;
    logic [PACK_W-1:0]packet_out_n;

    logic do_write;
    logic do_read;

    always_comb begin
        empty = (count == 0);
        full  = (count == DEPTH);
        do_write = write_valid && !full;
        do_read  = read_en  && !empty;
        head_n       = head;
        tail_n       = tail;
        count_n      = count;
        packet_out_n = packet_out;

        if (do_read) begin
            packet_out_n = list[head];
            if (head == DEPTH-1)
                head_n = '0;
            else
                head_n = head + 1'b1;
        end

        // write path
        if (do_write) begin
            if (tail == DEPTH-1)
                tail_n = '0;
            else
                tail_n = tail + 1'b1;
        end

        // count update
        case ({do_write, do_read})
            2'b10: count_n = count + 1'b1; 
            2'b01: count_n = count - 1'b1; 
            default: count_n = count;      
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            head <= '0;
            tail <= '0;
            count <= '0;
            packet_out <= '0;
            packet_out_valid <= 1'b0;
        end else begin
            packet_out_valid <= do_read;
            if (do_write) begin
                list[tail] <= packet_in;
            end 
            head       <= head_n;
            tail       <= tail_n;
            count      <= count_n;
            packet_out <= packet_out_n;
        end 
    end

endmodule