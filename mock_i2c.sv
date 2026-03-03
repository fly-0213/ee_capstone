module mock_i2c #(parameter int DATA_W=52,
                  parameter int LAT   = 6)(
    input  logic clk,
    input  logic reset,
    input  logic req,
    output logic valid,
    output logic [DATA_W-1:0]data,
    output logic busy
);

    logic [1:0] state;
    logic [DATA_W-1:0] sample_cnt;
    logic [$clog2(LAT+1)-1:0] cnt;

    localparam STAY = 2'd0;
    localparam CONV = 2'd1;
    localparam DONE = 2'd2;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= STAY;
            sample_cnt <= 0;
            valid <= 0;
            busy <= 0;
            data <= 0;
            cnt  <= '0;
        end else begin
            valid <= 1'b0;
            case (state)
                STAY: begin
                    busy <= 0;
                    cnt  <= '0;
                    if (req) begin
                        busy <= 1;
                        state <= CONV;
                    end 
                end 
                CONV: begin
                    busy <= 1'b1;
                    if (cnt == LAT-1) begin
                        state <= DONE;
                        cnt   <= 0;
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end
                DONE: begin
                    busy       <= 1'b0;
                    valid      <= 1'b1;               
                    sample_cnt <= sample_cnt + 16;  
                    data       <= sample_cnt;
                    state      <= STAY;
                end
            endcase
        end
    end 

endmodule