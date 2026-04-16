module i2c_master (
    input  logic        clk,
    input  logic        reset,

    input  logic        start,
    input  logic        rw,           // 0=write, 1=read
    input  logic [6:0]  dev_addr,
    input  logic [7:0]  reg_addr,
    input  logic [2:0]  num_bytes,    
    input  logic [15:0] wdata,
    input  logic        use_reg_addr,

    output logic [47:0] rdata,
    output logic        busy,
    output logic        done,
    output logic        ack_error,

    input  logic        sda_in,
    output logic        sda_oe,
    output logic        sda_out_low,
    output logic        scl
);

    tick_gen #(.tick_ratio(1000)) u_tick_gen (
        .clk   (clk),
        .reset (reset),
        .tick  (tick)
    );

    typedef enum logic [3:0] {
        S_IDLE            = 4'd0,
        S_START           = 4'd1,
        S_SEND_BYTE       = 4'd2,
        S_GET_ACK         = 4'd3,
        S_RESTART         = 4'd4,
        S_READ_BYTE       = 4'd5,
        S_SEND_MASTER_ACK = 4'd6,
        S_STOP            = 4'd7,
        S_DONE            = 4'd8,
        S_ERROR           = 4'd9
    } state_t;

    typedef enum logic [2:0] {
        PH_ADDR_W,
        PH_REG,
        PH_WRITE_DATA,
        PH_ADDR_R,
        PH_READ_DATA
    } phase_t;

    typedef enum logic [1:0] {
        SUB_0,
        SUB_1,
        SUB_2,
        SUB_3
    } subphase_t;
    

    state_t state;
    phase_t phase;
    subphase_t subphase;
    logic[3:0]   w_bit_cnt;
    logic[3:0]   r_bit_cnt;
    logic[7:0]   rx_shift;
    logic[2:0]   byt_cnt;
    logic[7:0]   send_byte;
    logic        tick;
    logic        ack_sample;
    logic        cmd_rw;
    logic [6:0]  cmd_dev_addr;
    logic [7:0]  cmd_reg_addr;
    logic [2:0]  cmd_num_bytes;
    logic [15:0] cmd_wdata;
    logic        cmd_use_reg_addr;


    always_ff @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            phase <= PH_ADDR_W;
            subphase <= SUB_0;
            w_bit_cnt <= '0;
            r_bit_cnt <= '0;
            rdata     <= '0;
            ack_error <= '0;
            rx_shift  <= '0;
            byt_cnt   <= '0;
            done      <= '0;
            busy      <= '0;
            ack_sample <= 1'b0;
            scl         <= 1'b1;
            sda_oe      <= 1'b0;
            sda_out_low <= 1'b1;
            cmd_rw          <= 1'b0;
            cmd_dev_addr    <= '0;
            cmd_reg_addr    <= '0;
            cmd_num_bytes   <= '0;
            cmd_wdata       <= '0;
            cmd_use_reg_addr<= 1'b0;
        end else if (tick) begin
            if (state == S_IDLE) begin
                busy <= '0;
                done <= '0;
                ack_error <= 1'b0;
                if (start) begin
                    state <= S_START;
                    byt_cnt <= '0;
                    w_bit_cnt  <= '0;
                    r_bit_cnt  <= '0;
                    rx_shift   <= '0;
                    rdata      <= '0;
                    ack_sample <= 1'b0;
                    subphase   <= SUB_0;
                    cmd_rw           <= rw;
                    cmd_dev_addr     <= dev_addr;
                    cmd_reg_addr     <= reg_addr;
                    cmd_num_bytes    <= num_bytes;
                    cmd_wdata        <= wdata;
                    cmd_use_reg_addr <= use_reg_addr;
                    if (!rw) begin
                        phase <= PH_ADDR_W;
                    end 
                    else if (rw && use_reg_addr) begin
                        phase <= PH_ADDR_W;
                    end 
                    else if (rw && !use_reg_addr) begin
                        phase <= PH_ADDR_R;
                    end
                end
            end 
            if (state == S_START) begin
                busy <= 1'b1;
                case (subphase)
                    SUB_0: begin
                        scl <= 1'b1;
                        sda_oe <= 1'b0;
                        subphase <= SUB_1;
                    end 
                    SUB_1: begin
                        scl <= 1'b1;
                        sda_oe <= 1'b1;
                        sda_out_low <= 1'b1;
                        subphase <= SUB_2;
                    end 
                    SUB_2: begin
                        scl <= 1'b0;
                        sda_oe <= 1'b1;
                        sda_out_low <= 1'b1;
                        subphase <= SUB_0;
                        state <= S_SEND_BYTE;
                    end
                endcase
            end 
            if (state == S_SEND_BYTE) begin
                case (subphase)
                    SUB_0: begin
                        scl <= 1'b0;
                        if (send_byte[7 - w_bit_cnt]) begin
                            sda_oe <= 1'b0;
                        end 
                        else begin
                            sda_oe <= 1'b1;
                            sda_out_low <= 1'b1;
                        end 
                        subphase <= SUB_1;
                    end 
                    SUB_1: begin
                        scl <= 1'b1;
                        subphase <= SUB_2;
                    end 
                    SUB_2: begin
                        scl <= 1'b0;
                        subphase <= SUB_3;
                    end
                    SUB_3: begin
                        if (w_bit_cnt < 7) begin
                            w_bit_cnt <= w_bit_cnt + 1'b1;
                            subphase <= SUB_0;
                            state <= S_SEND_BYTE;
                        end 
                        else begin
                            subphase <= SUB_0;
                            w_bit_cnt <= '0;
                            scl <= 1'b0;
                            state <= S_GET_ACK;
                        end 
                    end
                endcase
            end 
            if (state == S_GET_ACK) begin
                case (subphase)
                    SUB_0: begin
                        scl <= 1'b0;
                        sda_oe <= 1'b0;
                        subphase <= SUB_1;
                    end 
                    SUB_1: begin
                        scl <= 1'b1;
                        subphase <= SUB_2;
                    end 
                    SUB_2: begin
                        scl <= 1'b1;
                        ack_sample <= sda_in;
                        subphase <= SUB_3;
                    end
                    SUB_3: begin
                        scl <= 1'b0;
                        if (ack_sample) begin
                            ack_error <= ack_sample;
                            subphase <= SUB_0;
                            state <= S_ERROR;
                        end 
                        else begin
                            subphase <= SUB_0;
                            case (phase)
                                PH_ADDR_W: begin
                                    if (cmd_use_reg_addr) begin
                                        state <= S_SEND_BYTE;
                                        phase <= PH_REG;
                                    end else begin
                                        state <= S_SEND_BYTE;
                                        phase <= PH_WRITE_DATA;
                                    end
                                end
                                PH_REG: begin
                                    if (cmd_rw) begin
                                        state <= S_RESTART;
                                        phase <= PH_ADDR_R;
                                    end else begin
                                        state <= S_SEND_BYTE;
                                        phase <= PH_WRITE_DATA;
                                    end
                                end
                                PH_WRITE_DATA: begin 
                                    byt_cnt <= byt_cnt + 1'b1;
                                    if (byt_cnt + 1 == cmd_num_bytes) begin
                                        state <= S_STOP;
                                    end else begin
                                        state <= S_SEND_BYTE;
                                        phase <= PH_WRITE_DATA;
                                    end
                                end
                                PH_ADDR_R: begin
                                    state <= S_READ_BYTE;
                                    phase <= PH_READ_DATA;
                                end
                                default: begin
                                    state <= S_ERROR;
                                end
                            endcase
                        end 
                    end
                endcase 
            end
            if (state == S_RESTART) begin
                case (subphase)
                    SUB_0: begin
                        scl <= 1'b1;
                        sda_oe <= 1'b0;
                        subphase <= SUB_1;
                    end 
                    SUB_1: begin
                        scl <= 1'b1;
                        sda_oe <= 1'b1;
                        sda_out_low <= 1'b1;
                        subphase <= SUB_2;
                    end 
                    SUB_2: begin
                        scl <= 1'b0;
                        sda_oe <= 1'b1;
                        sda_out_low <= 1'b1;
                        subphase <= SUB_0;
                        phase <= PH_ADDR_R;
                        state <= S_SEND_BYTE;
                    end
                endcase
            end 
            if (state == S_READ_BYTE) begin
                case (subphase)
                    SUB_0: begin
                        scl <= 1'b0;
                        sda_oe <= 1'b0;
                        subphase <= SUB_1;
                    end 
                    SUB_1: begin
                        scl <= 1'b1;
                        subphase <= SUB_2;
                    end 
                    SUB_2: begin
                        scl <= 1'b1;
                        rx_shift[7 - r_bit_cnt] <= sda_in;
                        subphase <= SUB_3;
                    end
                    SUB_3: begin
                        scl <= 1'b0;
                        if (r_bit_cnt < 7) begin
                            r_bit_cnt <= r_bit_cnt + 1'b1;
                            subphase <= SUB_0;
                            state <= S_READ_BYTE;
                        end 
                        else begin
                            subphase <= SUB_0;
                            r_bit_cnt <= '0;
                            case (byt_cnt)
                                3'd0: rdata[47:40] <= rx_shift;
                                3'd1: rdata[39:32] <= rx_shift;
                                3'd2: rdata[31:24] <= rx_shift;
                                3'd3: rdata[23:16] <= rx_shift;
                                3'd4: rdata[15:8]  <= rx_shift;
                                3'd5: rdata[7:0]   <= rx_shift;
                            endcase
                            byt_cnt <= byt_cnt + 1'b1;
                            state <= S_SEND_MASTER_ACK;
                        end 
                    end
                endcase 
            end
            if (state == S_SEND_MASTER_ACK) begin
                case (subphase) 
                    SUB_0: begin
                        scl <= 1'b0;
                        if (byt_cnt == cmd_num_bytes) begin
                            sda_oe <= 1'b0;
                        end 
                        else begin
                            sda_oe <= 1'b1;
                            sda_out_low <= 1'b1;
                        end 
                        subphase <= SUB_1;
                    end 
                    SUB_1: begin
                        scl <= 1'b1;
                        subphase <= SUB_2;
                    end 
                    SUB_2: begin
                        scl <= 1'b1;
                        subphase <= SUB_3;
                    end
                    SUB_3: begin
                        scl <= 1'b0;
                        if (byt_cnt == cmd_num_bytes) begin
                            state <= S_STOP;
                        end 
                        else begin
                            state <= S_READ_BYTE;
                        end
                        subphase <= SUB_0; 
                    end
                endcase 
            end
            if (state == S_STOP) begin
                case (subphase)
                    SUB_0: begin
                        scl <= 1'b0;
                        sda_oe <= 1'b1;
                        sda_out_low <= 1'b1;
                        subphase <= SUB_1;
                    end 
                    SUB_1: begin
                        scl <= 1'b1;
                        subphase <= SUB_2;
                    end 
                    SUB_2: begin
                        scl <= 1'b1;
                        sda_oe <= 1'b0;
                        subphase <= SUB_3;
                    end
                    SUB_3: begin
                        state <= S_DONE;
                    end
                endcase 
            end 
            if (state == S_DONE) begin
                done <= 1'b1;
                busy <= 1'b0;
                subphase <= SUB_0;
                state <= S_IDLE;
            end 
            if (state == S_ERROR) begin
                busy <= 1'b0;
                if (!start) begin 
                    state <= S_IDLE;
                    subphase <= SUB_0;
                end 
            end
        end
    end

    always_comb begin
        send_byte = '0;
        case (state)
            S_SEND_BYTE: begin
                if (phase == PH_ADDR_W)
                    send_byte = {cmd_dev_addr, 1'b0};
                else if (phase == PH_ADDR_R)
                    send_byte = {cmd_dev_addr, 1'b1}; 
                if (phase == PH_REG) begin
                    send_byte = cmd_reg_addr;
                end 
                if (phase == PH_WRITE_DATA) begin
                    if (cmd_num_bytes == 3'd1) begin
                        send_byte = cmd_wdata[7:0];
                    end else begin
                        if (byt_cnt == '0)
                            send_byte = cmd_wdata[15:8];
                        else
                            send_byte = cmd_wdata[7:0];
                    end
                end
            end 
        endcase
    end 
endmodule
