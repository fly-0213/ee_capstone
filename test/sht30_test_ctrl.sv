module sht30_test_ctrl (
    input  logic clk,
    input  logic reset,

    output logic        start,
    output logic        rw,
    output logic [6:0]  dev_addr,
    output logic [7:0]  reg_addr,
    output logic [2:0]  num_bytes,
    output logic [15:0] wdata,
    output logic        use_reg_addr,

    input  logic        busy,
    input  logic        done,
    input  logic        ack_error,
    input  logic [47:0] rdata,

    output logic [3:0]  led
);

    typedef enum logic [3:0] {
        S_IDLE,
        S_START_WRITE,
        S_HOLD_WRITE,
        S_WAIT_WRITE,
        S_MEAS_DELAY,
        S_START_READ,
        S_HOLD_READ,
        S_WAIT_READ,
        S_PAUSE
    } state_t;

    state_t state;

    logic [31:0] cnt;

    logic success_latched;
    logic error_latched;
    logic write_done_latched;
    logic read_done_latched;

    logic mode_read;

    localparam int START_HOLD  = 32'd200_000;    // 2 ms @ 100 MHz
    localparam int MEAS_WAIT   = 32'd2_000_000;  // 20 ms @ 100 MHz
    localparam int PAUSE_MAX   = 32'd50_000_000; // 0.5 sec @ 100 MHz

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            cnt <= 0;
            start <= 0;
            mode_read <= 0;

            success_latched <= 0;
            error_latched <= 0;
            write_done_latched <= 0;
            read_done_latched <= 0;
        end else begin
            start <= 0;

            case (state)

                S_IDLE: begin
                    cnt <= 0;
                    mode_read <= 0;
                    state <= S_START_WRITE;
                end

                // Write command 0x2400 to SHT30
                S_START_WRITE: begin
                    start <= 1;
                    cnt <= 0;
                    state <= S_HOLD_WRITE;
                end

                S_HOLD_WRITE: begin
                    start <= 1;
                    if (cnt < START_HOLD) begin
                        cnt <= cnt + 1;
                    end else begin
                        start <= 0;
                        cnt <= 0;
                        state <= S_WAIT_WRITE;
                    end
                end

                S_WAIT_WRITE: begin
                    if (done) begin
                        write_done_latched <= 1;
                        if (ack_error) begin
                            error_latched <= 1;
                            state <= S_PAUSE;
                        end else begin
                            cnt <= 0;
                            state <= S_MEAS_DELAY;
                        end
                    end else if (ack_error && !busy) begin
                        error_latched <= 1;
                        state <= S_PAUSE;
                    end
                end

                // Wait for SHT30 measurement to finish
                S_MEAS_DELAY: begin
                    if (cnt < MEAS_WAIT) begin
                        cnt <= cnt + 1;
                    end else begin
                        cnt <= 0;
                        mode_read <= 1;
                        state <= S_START_READ;
                    end
                end

                // Read 6 bytes from SHT30
                S_START_READ: begin
                    start <= 1;
                    cnt <= 0;
                    state <= S_HOLD_READ;
                end

                S_HOLD_READ: begin
                    start <= 1;
                    if (cnt < START_HOLD) begin
                        cnt <= cnt + 1;
                    end else begin
                        start <= 0;
                        cnt <= 0;
                        state <= S_WAIT_READ;
                    end
                end

                S_WAIT_READ: begin
                    if (done) begin
                        read_done_latched <= 1;
                        if (ack_error) begin
                            error_latched <= 1;
                        end else begin
                            success_latched <= 1;
                        end
                        cnt <= 0;
                        state <= S_PAUSE;
                    end else if (ack_error && !busy) begin
                        error_latched <= 1;
                        state <= S_PAUSE;
                    end
                end

                S_PAUSE: begin
                    if (cnt < PAUSE_MAX) begin
                        cnt <= cnt + 1;
                    end else begin
                        cnt <= 0;
                        state <= S_IDLE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end

            endcase
        end
    end

    always_comb begin
        dev_addr = 7'h44;        // SHT30 default I2C address
        reg_addr = 8'h00;        // unused for SHT30 command mode
        use_reg_addr = 1'b0;     // important: SHT30 uses command, not register address

        if (mode_read) begin
            rw        = 1'b1;    // read
            num_bytes = 3'd6;    // temp MSB, temp LSB, temp CRC, hum MSB, hum LSB, hum CRC
            wdata     = 16'h0000;
        end else begin
            rw        = 1'b0;    // write
            num_bytes = 3'd2;
            wdata     = 16'h2400; // SHT30 single-shot high repeatability, no clock stretching
        end
    end

    // LED meaning:
    // LED0 = successful SHT30 read
    // LED1 = ACK error
    // LED2 = I2C busy
    // LED3 = write/read transaction reached done
    assign led[0] = success_latched;
    assign led[1] = error_latched;
    assign led[2] = busy;
    assign led[3] = write_done_latched | read_done_latched;

endmodule