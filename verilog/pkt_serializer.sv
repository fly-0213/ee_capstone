`include "packet_defs.svh"
module pkt_serializer(
    input              clk,
    input              reset,
    input              pkt_valid,
    input [PACK_W-1:0] packet_in,
    input              uart_ready,

    output logic [7:0] byte_out,
    output logic       pkt_done,
    output logic       byte_valid
    
);

    localparam logic [1:0] S_IDLE = 2'b01;
    localparam logic [1:0] S_SEND = 2'b10;

    logic [1:0]state;
    logic [$clog2(PACK_W/8)-1:0]byte_count;
    logic [PACK_W-1:0]pkt_mem;


    always_ff @(posedge clk)begin
        if (reset) begin
            state <= S_IDLE;
            byte_count <= '0;
	    	pkt_mem <= '0;
	    	byte_out <= '0;
	    	byte_valid <= '0;
	    	pkt_done <= '0;
        end else begin
            byte_valid   <= 1'b0;
            pkt_done <= 1'b0;
            case(state)
                S_IDLE: begin
                    if (pkt_valid) begin
                        pkt_mem <= packet_in;
                        byte_count <= 0;
                        state <= S_SEND;
                    end 
                end 
                S_SEND: begin
                    if (uart_ready) begin
                        byte_out <= pkt_mem[(PACK_W-1) - 8*byte_count -: 8];
                        byte_valid <= 1'b1;
                        if (byte_count == PACK_W/8 - 1) begin
                            pkt_done <= 1'b1;
                            state <= S_IDLE;
                        end else begin
                            byte_count <= byte_count + 1'b1;
                        end 
                    end 
                end 
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end 
    end 
endmodule