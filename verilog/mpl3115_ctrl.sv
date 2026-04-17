module mpl3115_ctrl (
    input  logic        clk,
    input  logic        reset,
    input  logic        start,

    // interface to i2c master
    input  logic        i2c_busy,
    input  logic        i2c_done,
    input  logic [39:0] i2c_rdata,      // up to 5 bytes for MPL3115 readout
    input  logic        i2c_ack_error,

    output logic        i2c_start,
    output logic        i2c_rw,         // 0 = write, 1 = read
    output logic [6:0]  i2c_dev_addr,
    output logic [7:0]  i2c_reg_addr,
    output logic [2:0]  i2c_num_bytes,  // 1 or 5 bytes
    output logic [7:0]  i2c_wdata,      // single-byte register write data

    // result to upper level
    output logic        busy,
    output logic        data_valid,
    output logic [19:0] pressure_raw,   // raw pressure format from OUT_P_* bytes
    output logic [11:0] temp_raw,       // raw temperature format from OUT_T_* bytes
    output logic        error
);


    // 7-bit I2C address
    localparam logic [6:0] MPL3115_ADDR    = 7'h60;

    // Register map
    localparam logic [7:0] REG_STATUS      = 8'h00;
    localparam logic [7:0] REG_OUT_P_MSB   = 8'h01;
    localparam logic [7:0] REG_PT_DATA_CFG = 8'h13;
    localparam logic [7:0] REG_CTRL_REG1   = 8'h26;

    // STATUS bit[3] = PTDR (Pressure/Temperature Data Ready)
    localparam logic [7:0] STATUS_PTDR_MASK = 8'h08;

    // PT_DATA_CFG = 0x07 enables data event flags
    localparam logic [7:0] PT_DATA_CFG_VAL = 8'h07;

    // CTRL_REG1 bit meanings used here:
    // bit7 ALT   = 0 -> barometer mode
    // bit5:3 OS  = 101 -> OSR = 32
    // bit1 OST   = 0/1
    // bit0 SBYB  = 0 -> standby, 1 -> active
    //
    // barometer mode + OSR=32 + standby  = 0b0010_1000 = 0x28
    // barometer mode + OSR=32 + active   = 0b0010_1001 = 0x29
    localparam logic [7:0] CTRL1_CFG_VAL  = 8'h28;
    localparam logic [7:0] CTRL1_OST_VAL  = 8'h2B;
    // 0x2B = 0010_1011
    //      = barometer + OSR=32 + OST=1 + SBYB=1


    typedef enum logic [3:0] {
        S_IDLE                   = 4'd0,
        S_WRITE_CTRL1_CFG        = 4'd1,
        S_WAIT_CTRL1_CFG_DONE    = 4'd2,
        S_WRITE_PT_DATA_CFG      = 4'd3,
        S_WAIT_PT_DATA_CFG_DONE  = 4'd4,
        S_WRITE_CTRL1_OST        = 4'd5,
        S_WAIT_CTRL1_OST_DONE    = 4'd6,
        S_READ_STATUS            = 4'd7,
        S_WAIT_STATUS_DONE       = 4'd8,
        S_CHECK_STATUS           = 4'd9,
        S_READ_DATA              = 4'd10,
        S_WAIT_READ_DATA_DONE    = 4'd11,
        S_PARSE                  = 4'd12,
        S_DONE                   = 4'd13,
        S_ERROR                  = 4'd14
    } state_t;

    state_t state, next_state;

    logic [7:0]  status_reg;
    logic [39:0] rx_data;

    logic [7:0] p_msb, p_csb, p_lsb;
    logic [7:0] t_msb, t_lsb;

    always_ff @(posedge clk) begin
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
                    next_state = S_WRITE_CTRL1_CFG;
            end

            S_WRITE_CTRL1_CFG: begin
                if (i2c_busy)
                    next_state = S_WAIT_CTRL1_CFG_DONE;
                else
                    next_state = S_WRITE_CTRL1_CFG;
            end

            S_WAIT_CTRL1_CFG_DONE: begin
                if (i2c_ack_error)
                    next_state = S_ERROR;
                else if (i2c_done)
                    next_state = S_WRITE_PT_DATA_CFG;
            end

            S_WRITE_PT_DATA_CFG: begin
                if (i2c_busy)
                    next_state = S_WAIT_PT_DATA_CFG_DONE;
                else
                    next_state = S_WRITE_PT_DATA_CFG;
            end

            S_WAIT_PT_DATA_CFG_DONE: begin
                if (i2c_ack_error)
                    next_state = S_ERROR;
                else if (i2c_done)
                    next_state = S_WRITE_CTRL1_OST;
            end

            S_WRITE_CTRL1_OST: begin
                if (i2c_busy)
                    next_state = S_WAIT_CTRL1_OST_DONE;
                else
                    next_state = S_WRITE_CTRL1_OST;
            end

            S_WAIT_CTRL1_OST_DONE: begin
                if (i2c_ack_error)
                    next_state = S_ERROR;
                else if (i2c_done)
                    next_state = S_READ_STATUS;
            end

            S_READ_STATUS: begin
                if (i2c_busy)
                    next_state = S_WAIT_STATUS_DONE;
                else
                    next_state = S_READ_STATUS;
            end

            S_WAIT_STATUS_DONE: begin
                if (i2c_ack_error)
                    next_state = S_ERROR;
                else if (i2c_done)
                    next_state = S_CHECK_STATUS;
            end

            S_CHECK_STATUS: begin
                if (status_reg & STATUS_PTDR_MASK)
                    next_state = S_READ_DATA;
                else
                    next_state = S_READ_STATUS;
            end

            S_READ_DATA: begin
                if (i2c_busy)
                    next_state = S_WAIT_READ_DATA_DONE;
                else
                    next_state = S_READ_DATA;
            end

            S_WAIT_READ_DATA_DONE: begin
                if (i2c_ack_error)
                    next_state = S_ERROR;
                else if (i2c_done)
                    next_state = S_PARSE;
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

    always_ff @(posedge clk) begin
        if (reset) begin
            status_reg    <= 8'd0;
            rx_data       <= 40'd0;
            pressure_raw  <= 20'd0;
            temp_raw      <= 12'd0;
            p_msb         <= 8'd0;
            p_csb         <= 8'd0;
            p_lsb         <= 8'd0;
            t_msb         <= 8'd0;
            t_lsb         <= 8'd0;
        end else begin
            // latch STATUS byte after successful status read
            if (state == S_WAIT_STATUS_DONE && i2c_done && !i2c_ack_error) begin
                status_reg <= i2c_rdata[39:32];
            end

            // latch 5-byte measurement frame after successful data read
            if (state == S_WAIT_READ_DATA_DONE && i2c_done && !i2c_ack_error) begin
                rx_data <= i2c_rdata;
            end

            // parse raw bytes
            if (state == S_PARSE) begin
                // assumed read order:
                // [39:32] OUT_P_MSB
                // [31:24] OUT_P_CSB
                // [23:16] OUT_P_LSB
                // [15:8]  OUT_T_MSB
                // [7:0]   OUT_T_LSB
                p_msb <= rx_data[39:32];
                p_csb <= rx_data[31:24];
                p_lsb <= rx_data[23:16];
                t_msb <= rx_data[15:8];
                t_lsb <= rx_data[7:0];

                // Pressure/altitude output is 20-bit:
                // OUT_P_MSB[7:0], OUT_P_CSB[7:0], OUT_P_LSB[7:4]
                pressure_raw <= {rx_data[39:32], rx_data[31:24], rx_data[23:20]};

                // Temperature output is 12-bit:
                // OUT_T_MSB[7:0], OUT_T_LSB[7:4]
                temp_raw <= {rx_data[15:8], rx_data[7:4]};
            end
        end
    end


    always_comb begin
        i2c_start     = 1'b0;
        i2c_rw        = 1'b0;
        i2c_dev_addr  = MPL3115_ADDR;
        i2c_reg_addr  = 8'h00;
        i2c_num_bytes = 3'd0;
        i2c_wdata     = 8'h00;

        busy          = 1'b1;
        data_valid    = 1'b0;
        error         = 1'b0;

        case (state)
            S_IDLE: begin
                busy = 1'b0;
            end

            S_WRITE_CTRL1_CFG: begin
                i2c_start     = 1'b1;
                i2c_rw        = 1'b0; // write
                i2c_reg_addr  = REG_CTRL_REG1;
                i2c_num_bytes = 3'd1;
                i2c_wdata     = CTRL1_CFG_VAL;
            end

            S_WRITE_PT_DATA_CFG: begin
                i2c_start     = 1'b1;
                i2c_rw        = 1'b0; // write
                i2c_reg_addr  = REG_PT_DATA_CFG;
                i2c_num_bytes = 3'd1;
                i2c_wdata     = PT_DATA_CFG_VAL;
            end

            S_WRITE_CTRL1_OST: begin
                i2c_start     = 1'b1;
                i2c_rw        = 1'b0; // write
                i2c_reg_addr  = REG_CTRL_REG1;
                i2c_num_bytes = 3'd1;
                i2c_wdata     = CTRL1_OST_VAL;
            end

            S_READ_STATUS: begin
                i2c_start     = 1'b1;
                i2c_rw        = 1'b1; // read
                i2c_reg_addr  = REG_STATUS;
                i2c_num_bytes = 3'd1;
            end

            S_READ_DATA: begin
                i2c_start     = 1'b1;
                i2c_rw        = 1'b1; // read
                i2c_reg_addr  = REG_OUT_P_MSB;
                i2c_num_bytes = 3'd5;
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
