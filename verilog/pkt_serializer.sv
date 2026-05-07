`include "packet_defs.svh"

module pkt_serializer(
    input               clk,
    input               reset,
    input               pkt_valid,
    input  [PACK_W-1:0] packet_in,
    output logic        pkt_ready,
    input               uart_ready,

    output logic [7:0]  byte_out,
    output logic        pkt_done,
    output logic        byte_valid,
    output logic        busy
);

    localparam int NUM_BYTES = PACK_W / 8;

    typedef enum logic [1:0] {
        S_IDLE,
        S_PRESENT,
        S_WAIT_ACCEPT
    } state_t;

    state_t state;

    logic [PACK_W-1:0] pkt_mem;
    logic [$clog2(NUM_BYTES)-1:0] byte_count;

    assign busy      = (state != S_IDLE);
    assign pkt_ready = (state == S_IDLE);

    always_ff @(posedge clk) begin
        if (reset) begin
            state      <= S_IDLE;
            pkt_mem    <= '0;
            byte_count <= '0;
            byte_out   <= 8'd0;
            byte_valid <= 1'b0;
            pkt_done   <= 1'b0;
        end else begin
            pkt_done <= 1'b0;

            case (state)

                S_IDLE: begin
                    byte_valid <= 1'b0;

                    if (pkt_valid) begin
                        pkt_mem    <= packet_in;
                        byte_count <= '0;
                        byte_out   <= packet_in[(PACK_W-1) -: 8];
                        byte_valid <= 1'b1;
                        state      <= S_PRESENT;
                    end
                end

                // Hold byte_valid high until UART actually accepts it.
                S_PRESENT: begin
                    byte_valid <= 1'b1;

                    if (!uart_ready) begin
                        state <= S_WAIT_ACCEPT;
                    end
                end

                // UART is sending this byte. Wait until it becomes ready again.
                S_WAIT_ACCEPT: begin
                    byte_valid <= 1'b0;

                    if (uart_ready) begin
                        if (byte_count == NUM_BYTES-1) begin
                            pkt_done <= 1'b1;
                            state    <= S_IDLE;
                        end else begin
                            byte_count <= byte_count + 1'b1;
                            byte_out   <= pkt_mem[(PACK_W-1) - 8*(byte_count + 1'b1) -: 8];
                            byte_valid <= 1'b1;
                            state      <= S_PRESENT;
                        end
                    end
                end

                default: begin
                    state      <= S_IDLE;
                    byte_valid <= 1'b0;
                    pkt_done   <= 1'b0;
                end

            endcase
        end
    end

endmodule