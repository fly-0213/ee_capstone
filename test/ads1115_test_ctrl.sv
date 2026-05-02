module ads1115_test_ctrl (
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
        S_WAIT,
        S_START,
        S_HOLD_START,
        S_WAIT_DONE,
        S_PAUSE
    } state_t;

    state_t state;

    logic [31:0] pause_count;
    logic        success_latched;
    logic        error_latched;
    logic        done_latched;

    localparam int PAUSE_MAX = 32'd50_000_000; // about 0.5 sec at 100 MHz

    always_ff @(posedge clk) begin
        if (reset) begin
            state           <= S_WAIT;
            start           <= 1'b0;
            pause_count     <= 32'd0;
            success_latched <= 1'b0;
            error_latched   <= 1'b0;
            done_latched    <= 1'b0;
        end else begin
            start <= 1'b0;

            case (state)

                S_WAIT: begin
                    pause_count <= 32'd0;
                    state <= S_START;
                end

                // Hold start high long enough for i2c_master to catch it on its internal tick
                S_START: begin
                    start <= 1'b1;
                    state <= S_HOLD_START;
                end

                S_HOLD_START: begin
                    start <= 1'b1;
                    if (busy) begin
                        start <= 1'b0;
                        state <= S_WAIT_DONE;
                    end
                end

                S_WAIT_DONE: begin
                    if (done) begin
                        done_latched <= 1'b1;

                        if (!ack_error)
                            success_latched <= 1'b1;
                        else
                            error_latched <= 1'b1;

                        state <= S_PAUSE;
                    end

                    if (ack_error) begin
                        error_latched <= 1'b1;
                        state <= S_PAUSE;
                    end
                end

                S_PAUSE: begin
                    if (pause_count < PAUSE_MAX) begin
                        pause_count <= pause_count + 1'b1;
                    end else begin
                        state <= S_START;
                    end
                end

                default: state <= S_WAIT;

            endcase
        end
    end

    // ADS1115 command setup
    always_comb begin
        dev_addr     = 7'h48;   // ADS1115 default address when ADDR = GND
        reg_addr     = 8'h01;   // Config register
        rw           = 1'b1;    // read
        num_bytes    = 3'd2;    // read 2 bytes
        wdata        = 16'h0000;
        use_reg_addr = 1'b1;
    end

    // LED meanings:
    // LED0 = got successful transaction at least once
    // LED1 = got ACK error at least once
    // LED2 = I2C busy
    // LED3 = done seen at least once
    assign led[0] = success_latched;
    assign led[1] = error_latched;
    assign led[2] = busy;
    assign led[3] = done_latched;

endmodules