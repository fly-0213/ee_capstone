module i2c_master (
    input  logic        clk,
    input  logic        reset,

    input  logic        start,
    input  logic        rw,           // 0=write, 1=read
    input  logic [6:0]  dev_addr,
    input  logic [7:0]  reg_addr,
    input  logic [6:0]  num_bytes,    // 1 or 2
    input  logic [15:0] wdata,
    input  logic        use_reg_addr,

    output logic [47:0] rdata,
    output logic        busy,
    output logic        done,
    output logic        ack_error,

    inout  wire         sda_in,
    output logic        sda_oe,
    output logic        sda_out_low,
    output logic        scl
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
        S_DONE            = 4'd8
    } state_t;

    typedef enum logic [2:0] {
        PH_ADDR_W,
        PH_REG,
        PH_WRITE_DATA,
        PH_ADDR_R,
        PH_READ_DATAz
    } phase_t;
    

    state_t state, next_state;
    phase_t phase;
    logic[3:0]   bit_cnt;

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
                if (start) begin
                    next_state = S_START;
                end 
            end 
            S_START: begin
                next_state = S_SEND_BYTE;
            end 
            S_SEND_BYTE: begin
                if (bit_cnt == 7) begin
                    next_state = S_GET_ACK;
                end 
            end 
            S_GET_ACK: begin
                if (!use_reg_addr) begin
                    if (rw)
                end 
            end 
            S_RESTART         = 4'd4,
            S_READ_BYTE       = 4'd5,
            S_SEND_MASTER_ACK = 4'd6,
            S_STOP            = 4'd7,
            S_DONE            = 4'd8
        endcase

    end 

endmodule