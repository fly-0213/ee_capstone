module ads1115_ctrl (
    input  logic        clk,
    input  logic        reset,
    input  logic        start,

    // interface to i2c master
    input  logic        i2c_busy,
    input  logic        i2c_done,
    input  logic [15:0] i2c_rdata,
    input  logic        i2c_ack_error,

    output logic        i2c_start,
    output logic        i2c_rw,          // 0=write, 1=read
    output logic [6:0]  i2c_dev_addr,
    output logic [7:0]  i2c_reg_addr,
    output logic [1:0]  i2c_num_bytes,   // 1 or 2 bytes
    output logic [15:0] i2c_wdata,

    // result to upper level
    output logic        busy,
    output logic        data_valid,
    output logic [15:0] data_out,
    output logic        error
);

    localparam logic [6:0] ADS1115_ADDR   = 7'h48;
    localparam logic [7:0] REG_CONVERSION = 8'h00; // read
    localparam logic [7:0] REG_CONFIG     = 8'h01; // write

    // OS=1, MUX=100(AIN0), PGA=001(±4.096V),
    // MODE=1(single-shot), DR=100(128 SPS),
    // COMP_MODE=0, COMP_POL=0, COMP_LAT=0, COMP_QUE=11(disable)
    localparam logic [15:0] ADS1115_CFG   = 16'hC383;

    localparam int CONV_WAIT_CYCLES = 400_000;  // wait cycle/clk > 1/SPS

    typedef enum logic [2:0] {
        S_IDLE           = 3'd0,
        S_WRITE_CFG      = 3'd1,
        S_WAIT_CFG_DONE  = 3'd2,
        S_WAIT_CONV      = 3'd3,
        S_READ_CONV      = 3'd4,
        S_WAIT_READ_DONE = 3'd5,
        S_DONE           = 3'd6,
        S_ERROR          = 3'd7
    } state_t;

    state_t state, next_state;

    logic [$clog2(CONV_WAIT_CYCLES+1)-1:0] conv_wait_cnt;

    // state register
    always_ff @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // next-state logic
    always_comb begin
        next_state = state;

        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_WRITE_CFG;
            end

            S_WRITE_CFG: begin
                next_state = S_WAIT_CFG_DONE;
            end

            S_WAIT_CFG_DONE: begin
                if (i2c_done) begin
                    if (i2c_ack_error)
                        next_state = S_ERROR;
                    else
                        next_state = S_WAIT_CONV;
                end
            end

            S_WAIT_CONV: begin
                if (conv_wait_cnt == CONV_WAIT_CYCLES)
                    next_state = S_READ_CONV;
            end

            S_READ_CONV: begin
                next_state = S_WAIT_READ_DONE;
            end

            S_WAIT_READ_DONE: begin
                if (i2c_done) begin
                    if (i2c_ack_error)
                        next_state = S_ERROR;
                    else
                        next_state = S_DONE;
                end
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

    // sequential data path
    always_ff @(posedge clk) begin
        if (reset) begin
            conv_wait_cnt <= '0;
            data_out      <= 16'd0;
        end else begin
            if (state == S_WAIT_CONV) begin
                if (conv_wait_cnt < CONV_WAIT_CYCLES)
                    conv_wait_cnt <= conv_wait_cnt + 1'b1;
            end else begin
                conv_wait_cnt <= '0;
            end

            if (state == S_WAIT_READ_DONE && i2c_done && !i2c_ack_error) begin
                data_out <= i2c_rdata;
            end
        end
    end

    // output logic
    always_comb begin
        i2c_start     = 1'b0;
        i2c_rw        = 1'b0;
        i2c_dev_addr  = ADS1115_ADDR;
        i2c_reg_addr  = 8'h00;
        i2c_num_bytes = 2'd0;
        i2c_wdata     = 16'h0000;

        busy          = 1'b1;
        data_valid    = 1'b0;
        error         = 1'b0;

        case (state)
            S_IDLE: begin
                busy = 1'b0;
            end

            S_WRITE_CFG: begin
                i2c_start     = 1'b1;
                i2c_rw        = 1'b0;
                i2c_reg_addr  = REG_CONFIG;
                i2c_num_bytes = 2'd2;
                i2c_wdata     = ADS1115_CFG;
            end

            S_READ_CONV: begin
                i2c_start     = 1'b1;
                i2c_rw        = 1'b1;
                i2c_reg_addr  = REG_CONVERSION;
                i2c_num_bytes = 2'd2;
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