module scheduler#(parameter int SENS_NUM=4)(
    input                               clk,
    input                               reset,
    input                               start_pulse,
    input                               stop_pulse,
    input                               sens_valid,
    //input                         sens_busy,
    
    output  logic                       sens_req,
    output  logic [$clog2(SENS_NUM)-1:0]sens_id
);

    localparam logic [1:0] S_IDLE       = 2'b00;
    localparam logic [1:0] S_ISSUE      = 2'b01;
    localparam logic [1:0] S_WAIT       = 2'b10;
    //localparam logic [1:0] S_STOP       = 2'b11;

    logic [1:0]state;
    logic capture_en;
    logic stop_pending;
    logic [$clog2(SENS_NUM)-1:0] cur_id;

    function automatic logic [$clog2(SENS_NUM)-1:0] inc_id(
        input logic [$clog2(SENS_NUM)-1:0] id
    );
        if (id == SENS_NUM-1) inc_id = '0;
        else                  inc_id = id + 1'b1;
    endfunction

    always_ff@(posedge clk)begin
        if (reset) begin
            state        <= S_IDLE;
            capture_en   <= 1'b0;
            stop_pending <= 1'b0;
            cur_id       <= '0;
            sens_id      <= '0;
            sens_req     <= 1'b0;
        end else begin
            sens_req <= 1'b0;
            if (start_pulse) begin
                capture_en   <= 1'b1;
                stop_pending <= 1'b0;
                cur_id       <= '0; 
            end
            if (stop_pulse) begin
                stop_pending <= 1'b1; // safe stop: finish current sample then stop
            end
            case (state)
                S_IDLE: begin
                    if (capture_en) begin
                        state <= S_ISSUE;
                    end 
                end
                S_ISSUE: begin
                    sens_id  <= cur_id;
                    sens_req <= 1'b1;
                    state <= S_WAIT;
                end
                S_WAIT: begin
                    if (sens_valid) begin
                        cur_id <= inc_id(cur_id);
                        if (stop_pending) begin
                            capture_en <= 1'b0;
                            state      <= S_IDLE;
                        end else begin
                            state <= S_ISSUE;
                        end
                    end
                end
                //S_STOP: begin
                //    if (!all_sens_valid) begin
                //        state <= S_STOP;
                //    end else if (all_sens_valid) begin
                //        state <= S_IDLE;
                //    end 
                //end 
            endcase
        end
    end

endmodule
