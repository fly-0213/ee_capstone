`include "packet_defs.svh"
module uart_tx#(parameter int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE
)(
    input         clk,
    input         reset,
    input         tx_valid,
    input   [7:0] tx_data,

    output logic  tx_serial,
    output logic  tx_busy,
    output logic  tx_done,
    output logic  tx_ready
    
);

    localparam logic [1:0] S_IDLE = 2'b00;
    localparam logic [1:0] S_START = 2'b01;
    localparam logic [1:0] S_DATA = 2'b10;
    localparam logic [1:0] S_STOP = 2'b11;

    localparam logic start_bit = 1'b0;
    localparam logic stop_bit = 1'b1;

    logic [1:0]state;
    logic [7:0]byte_mem;
    logic [$clog2(8)-1:0] bit_count;
    logic [$clog2(CLKS_PER_BIT+1)-1:0] clk_count;
    assign tx_ready = (state == S_IDLE);

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            byte_mem  <= '0;
            bit_count <= '0;
            clk_count <= '0;
            tx_serial <= 1'b1;
            tx_busy <= 1'b0;
            tx_done <= 1'b0;
        end else begin
            tx_done <= 1'b0;
            case(state)
                S_IDLE: begin
                    tx_serial <= 1'b1;
                    tx_busy <= 1'b0;
                    clk_count <= '0;
                    bit_count <= '0;
                    if (tx_valid) begin
                        byte_mem <= tx_data;
                        tx_busy <= 1'b1;
                        state <= S_START;
                    end 
                end 
                S_START: begin
                    tx_serial <= start_bit;
                    tx_busy   <= 1'b1;
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= '0;
                        state <= S_DATA;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end 
                S_DATA: begin
                    tx_serial <= byte_mem[bit_count];
                    tx_busy   <= 1'b1;
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= '0;
                        if (bit_count==3'd7) begin
                            state <= S_STOP;
                        end else begin 
                            bit_count <= bit_count + 1'b1;
                        end 
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end 
                end 
                S_STOP: begin
                    tx_serial <= stop_bit;
                    tx_busy   <= 1'b1;
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= '0;
                        tx_busy <= 1'b0;
                        tx_done <= 1'b1;
                        state <= S_IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end 
                end
                default: begin
                    state <= S_IDLE;
                    tx_serial <= 1'b1;
                    tx_busy   <= 1'b0;
                    tx_done   <= 1'b0;
                    clk_count <= '0;
                    bit_count <= '0;
                end 
            endcase
        end 
    end 

endmodule