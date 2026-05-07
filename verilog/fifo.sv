`include "packet_defs.svh"
module fifo#(parameter int DEPTH = 8)(
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

    logic [PACK_W-1:0] list [0:DEPTH-1];

    logic [$clog2(DEPTH)-1:0] head;
    logic [$clog2(DEPTH)-1:0] tail;
    logic [$clog2(DEPTH+1)-1:0] count;

    logic do_write;
    logic do_read;

    assign empty = (count == 0);
    assign full  = (count == DEPTH);

    assign do_write = write_valid && !full;
    assign do_read  = read_en && !empty;

    // Show-ahead output:
    // If FIFO is not empty, output is always valid and points to head.
    assign packet_out       = empty ? '0 : list[head];
    assign packet_out_valid = !empty;

    always_ff @(posedge clk) begin
        if (reset) begin
            head  <= '0;
            tail  <= '0;
            count <= '0;
        end else begin
            if (do_write) begin
                list[tail] <= packet_in;
                if (tail == DEPTH-1)
                    tail <= '0;
                else
                    tail <= tail + 1'b1;
            end
            if (do_read) begin
                if (head == DEPTH-1)
                    head <= '0;
                else
                    head <= head + 1'b1;
            end
            case ({do_write, do_read})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end
endmodule