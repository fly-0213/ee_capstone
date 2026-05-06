module mpl3115_test_ctrl (
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

    typedef enum logic [2:0] {
        S_IDLE,
        S_START_READ,
        S_HOLD_READ,
        S_WAIT_READ,
        S_PAUSE
    } state_t;

    state_t state;

    logic [31:0] cnt;

    logic success_latched;
    logic error_latched;
    logic read_done_latched;

    logic [7:0] whoami_latched;

    localparam logic [6:0] MPL3115_ADDR = 7'h60;
    localparam logic [7:0] REG_WHO_AM_I = 8'h0C;
    localparam logic [7:0] EXPECTED_ID  = 8'hC4;

    localparam int START_HOLD = 32'd200_000;     // 2 ms @ 100 MHz
    localparam int PAUSE_MAX  = 32'd50_000_000;  // 0.5 sec @ 100 MHz

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            cnt <= 0;
            start <= 0;

            success_latched <= 0;
            error_latched <= 0;
            read_done_latched <= 0;
            whoami_latched <= 8'h00;
        end else begin
            start <= 0;

            case (state)

                S_IDLE: begin
                    cnt <= 0;
                    state <= S_START_READ;
                end

                // Read MPL3115 WHO_AM_I register 0x0C.
                // Expected return value is 0xC4.
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

                        // Depending on how your i2c_master packs rdata,
                        // the first byte may appear at rdata[7:0] or rdata[47:40].
                        // This keeps the test tolerant of either convention.
                        if (rdata[7:0] == EXPECTED_ID) begin
                            whoami_latched <= rdata[7:0];
                        end else begin
                            whoami_latched <= rdata[47:40];
                        end

                        if (ack_error) begin
                            error_latched <= 1;
                        end else if ((rdata[7:0] == EXPECTED_ID) || (rdata[47:40] == EXPECTED_ID)) begin
                            success_latched <= 1;
                        end else begin
                            error_latched <= 1;
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
        dev_addr     = MPL3115_ADDR;  // MPL3115A2 default I2C address = 0x60
        reg_addr     = REG_WHO_AM_I;  // WHO_AM_I register = 0x0C
        use_reg_addr = 1'b1;          // MPL3115 uses register-address read
        rw           = 1'b1;          // read
        num_bytes    = 3'd1;          // read one byte
        wdata        = 16'h0000;      // unused for read
    end

    // LED meaning:
    // LED0 = success, WHO_AM_I == 0xC4
    // LED1 = ACK error or wrong WHO_AM_I value
    // LED2 = I2C busy
    // LED3 = read transaction reached done
    assign led[0] = success_latched;
    assign led[1] = error_latched;
    assign led[2] = busy;
    assign led[3] = read_done_latched;

endmodule