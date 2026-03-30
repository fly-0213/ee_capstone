module sht30_ctrl (
    input  logic        clk,
    input  logic        reset,
    input  logic        start,

    // interface to i2c master
    input  logic        i2c_busy,
    input  logic        i2c_done,
    input  logic [47:0] i2c_rdata,
    input  logic        i2c_ack_error,

    output logic        i2c_start,
    output logic        i2c_rw,          // 0=write, 1=read
    output logic [6:0]  i2c_dev_addr,
    output logic [15:0] i2c_wdata,
    output logic [2:0]  i2c_num_bytes,

    // result to upper level
    output logic        busy,
    output logic        data_valid,
    output logic [15:0] temp_raw,
    output logic [15:0] hum_raw,
    output logic        error
);

    // SHT30 default I2C address depends on ADDR pin connection.
    // Here we assume ADDR is tied low -> 0x44.
    localparam logic [6:0] SHT30_ADDR = 7'h44;

    // Single-shot measurement command, high repeatability,
    // clock stretching disabled.
    localparam logic [15:0] SHT30_MEAS_CMD = 16'h2400;

    // Wait time after measurement command.
    // Example: for 50 MHz clock, 1_000_000 cycles = 20 ms.
    localparam int MEAS_WAIT_CYCLES = 1_000_000;

    typedef enum logic [3:0] {
        S_IDLE           = 4'd0,
        S_SEND_CMD       = 4'd1,
        S_WAIT_CMD_DONE  = 4'd2,
        S_WAIT_MEAS      = 4'd3,
        S_READ_DATA      = 4'd4,
        S_WAIT_READ_DONE = 4'd5,
        S_PARSE          = 4'd6,
        S_DONE           = 4'd7,
        S_ERROR          = 4'd8
    } state_t;

    state_t state, next_state;

    logic [$clog2(MEAS_WAIT_CYCLES+1)-1:0] meas_wait_cnt;
    logic [47:0] rx_data;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end


    always_comb begin
        next_state = state;

        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_SEND_CMD;
            end

            S_SEND_CMD: begin
                next_state = S_WAIT_CMD_DONE;
            end

            S_WAIT_CMD_DONE: begin
                if (i2c_done) begin
                    if (i2c_ack_error)
                        next_state = S_ERROR;
                    else
                        next_state = S_WAIT_MEAS;
                end
            end

            S_WAIT_MEAS: begin
                if (meas_wait_cnt == MEAS_WAIT_CYCLES)
                    next_state = S_READ_DATA;
            end

            S_READ_DATA: begin
                next_state = S_WAIT_READ_DONE;
            end

            S_WAIT_READ_DONE: begin
                if (i2c_done) begin
                    if (i2c_ack_error)
                        next_state = S_ERROR;
                    else
                        next_state = S_PARSE;
                end
            end

            S_PARSE: begin
                next_state = S_DONE;
            end

            S_DONE: begin
                next_state = S_IDLE;
            end

            S_ERROR: begin
                if (!start)
                    next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end


    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            meas_wait_cnt <= '0;
            rx_data       <= 48'd0;
            temp_raw      <= 16'd0;
            hum_raw       <= 16'd0;
        end else begin
            if (state == S_WAIT_MEAS) begin
                if (meas_wait_cnt < MEAS_WAIT_CYCLES)
                    meas_wait_cnt <= meas_wait_cnt + 1'b1;
            end else begin
                meas_wait_cnt <= '0;
            end

            // latch 6-byte data after successful read
            if (state == S_WAIT_READ_DONE && i2c_done && !i2c_ack_error) begin
                rx_data <= i2c_rdata;
            end

            //------------------------------------------------
            // parse temperature/humidity raw codes
            //
            // Byte order assumed:
            // [47:40] Temp MSB
            // [39:32] Temp LSB
            // [31:24] Temp CRC
            // [23:16] RH   MSB
            // [15:8]  RH   LSB
            // [7:0]   RH   CRC
            //------------------------------------------------
            if (state == S_PARSE) begin
                temp_raw <= rx_data[47:32];
                hum_raw  <= rx_data[23:8];
            end
        end
    end


    always_comb begin
        i2c_start     = 1'b0;
        i2c_rw        = 1'b0;
        i2c_dev_addr  = SHT30_ADDR;
        i2c_wdata     = 16'h0000;
        i2c_num_bytes = 3'd0;

        busy          = 1'b1;
        data_valid    = 1'b0;
        error         = 1'b0;

        case (state)
            S_IDLE: begin
                busy = 1'b0;
            end

            S_SEND_CMD: begin
                i2c_start     = 1'b1;
                i2c_rw        = 1'b0;          // write
                i2c_dev_addr  = SHT30_ADDR;
                i2c_wdata     = SHT30_MEAS_CMD;
                i2c_num_bytes = 3'd2;
            end

            S_READ_DATA: begin
                i2c_start     = 1'b1;
                i2c_rw        = 1'b1;          // read
                i2c_dev_addr  = SHT30_ADDR;
                i2c_num_bytes = 3'd6;
            end

            S_DONE: begin
                data_valid = 1'b1;
            end

            S_ERROR: begin
                error = 1'b1;
            end
        endcase
    end

endmodule