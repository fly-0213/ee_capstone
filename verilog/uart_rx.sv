module uart_rx #(
    parameter int CLKS_PER_BIT = 868   // 100 MHz / 115200 baud
)(
    input  logic clk,
    input  logic reset,

    input  logic rx_serial,

    output logic rx_valid,
    output logic [7:0] rx_data
);

    typedef enum logic [2:0] {
        S_IDLE,
        S_START,
        S_DATA,
        S_STOP,
        S_DONE
    } state_t;

    state_t state;

    logic [$clog2(CLKS_PER_BIT+1)-1:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] rx_shift;

    always_ff @(posedge clk) begin
        if (reset) begin
            state     <= S_IDLE;
            clk_count <= '0;
            bit_index <= '0;
            rx_shift  <= 8'd0;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
        end else begin
            rx_valid <= 1'b0;

            case (state)

                S_IDLE: begin
                    clk_count <= '0;
                    bit_index <= '0;

                    if (rx_serial == 1'b0) begin
                        state <= S_START;
                    end
                end

                // sample in the middle of start bit
                S_START: begin
                    if (clk_count == (CLKS_PER_BIT/2)) begin
                        if (rx_serial == 1'b0) begin
                            clk_count <= '0;
                            state <= S_DATA;
                        end else begin
                            state <= S_IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_DATA: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= '0;
                        rx_shift[bit_index] <= rx_serial;

                        if (bit_index == 3'd7) begin
                            bit_index <= '0;
                            state <= S_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_STOP: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= '0;

                        if (rx_serial == 1'b1) begin
                            rx_data <= rx_shift;
                            state <= S_DONE;
                        end else begin
                            state <= S_IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_DONE: begin
                    rx_valid <= 1'b1;
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end

            endcase
        end
    end

endmodule