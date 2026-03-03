module tick_gen #(parameter int tick_ratio = 10)(
    input logic clk,
    input logic reset,
    output logic tick
);

    localparam int nc_w = $clog2(tick_ratio);
    logic [nc_w - 1:0]nc;

    always_ff @(posedge clk) begin
        if (reset) begin
            nc <= 0;
            tick <= 0;
        end else begin
            if (nc == tick_ratio-1) begin
                nc <= 0;
                tick <= 1'b1;
            end else begin
                nc <= nc + 1'b1;
                tick <= 0;
            end
        end
    end

endmodule

module timestamp #(parameter int TS_W=32)(
    input logic clk,
    input logic reset,
    input logic tick,
    output logic [TS_W-1:0]time_c
);

    always_ff @(posedge clk) begin
        if (reset) begin
            time_c <= 0;
        end else if (tick) begin
            time_c <= time_c + 1'b1;
        end
    end

endmodule