module mock_adc #(parameter int DATA_W=52)(
    input  logic clk,
    input  logic reset,
    input  logic req,
    output logic valid,
    output logic [DATA_W-1:0]data,
    output logic busy
);

    logic [1:0] state;
    logic [DATA_W-1:0] sample_cnt;

    localparam STAY = 2'd0;
    localparam CONV = 2'd1;
    localparam DONE = 2'd2;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= STAY;
            sample_cnt <= 0;
            valid <= 0;
            data <= 0;
            busy <= 0;
        end else begin
            valid <= 0;
            case (state)
                STAY: begin
                    if (req) begin
                        busy <= 1;
                        state <= CONV;
                    end 
                end 
                CONV: begin
                    busy <= 1;
                    state <= DONE;
                end
                DONE: begin
                    sample_cnt <= sample_cnt + 1'b1;
                    valid <= 1'b1;
                    data <= sample_cnt + 1'b1;
                    busy <= 0;
                    state <= STAY;
                end
            endcase
        end
    end 

endmodule