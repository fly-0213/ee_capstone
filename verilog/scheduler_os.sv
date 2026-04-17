module scheduler_os#(parameter int SENS_NUM=3)(
    input                               clk,
    input                               reset,
    input                               start_pulse,
    input                               stop_pulse,
    input                               result_valid,
    input                               result_error,
    
    output  logic                       sens_req,
    output  logic [$clog2(SENS_NUM)-1:0]sens_id
);

    localparam logic [1:0] S_IDLE       = 2'b00;
    localparam logic [1:0] S_ISSUE      = 2'b01;
    localparam logic [1:0] S_WAIT       = 2'b10;

    logic [1:0]state;
    logic stop_pending;
    logic [$clog2(SENS_NUM)-1:0] cur_id;
    logic sens_done;

    assign sens_done = result_valid || result_error;

    function automatic logic [$clog2(SENS_NUM)-1:0] inc_id(
        input logic [$clog2(SENS_NUM)-1:0] id
    );
        if (id == SENS_NUM-1) inc_id = '0;
        else                  inc_id = id + 1'b1;
    endfunction

    always_ff @(posedge clk) begin
        if (reset) begin
            state        <= S_IDLE;
            stop_pending <= 1'b0;
            cur_id       <= '0;
            sens_id      <= '0;
            sens_req     <= 1'b0;
        end else begin
            sens_req <= 1'b0;

            case (state)
                S_IDLE: begin
                    stop_pending <= 1'b0;
                    if (start_pulse) begin
                        cur_id  <= '0;
                        sens_id <= '0;
                        state   <= S_ISSUE;
                    end
                end

                S_ISSUE: begin
                    sens_id  <= cur_id;
                    sens_req <= 1'b1;
                    state    <= S_WAIT;
                end

                S_WAIT: begin
                    if (stop_pulse) begin
                        stop_pending <= 1'b1;
                    end
                    if (sens_done) begin
                        if (stop_pending) begin
                            state <= S_IDLE;
                        end else if (result_error) begin
                            state <= S_IDLE;
                        end else if (cur_id == SENS_NUM-1) begin
                            state <= S_IDLE;   // one-shot: last sensor finished
                        end else begin
                            cur_id <= inc_id(cur_id);
                            state  <= S_ISSUE;
                        end
                    end
                end
            endcase
        end
    end

endmodule
