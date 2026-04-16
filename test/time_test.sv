`timescale 1ns/100ps

module time_tb;

    // ---- signals ----
    logic clk;
    logic reset;
    logic tick;
    logic [31:0] time_c;

    // ---- clock: 100MHz (10ns period) ----
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- DUT ----
    tick_gen #(.tick_ratio(10)) u_tick (
        .clk   (clk),
        .reset (reset),
        .tick  (tick)
    );

    timestamp #(.TS_W(32)) u_ts (
        .clk    (clk),
        .reset  (reset),
        .tick   (tick),
        .time_c (time_c)
    );

    logic tick_d;
    logic [31:0] last_time;

    always_ff @(posedge clk) begin
        if (reset) begin
            tick_d    <= 1'b0;
            last_time <= 32'd0;
        end else begin
            tick_d <= tick;

        if (tick_d) begin
            assert(time_c == last_time + 1)
                else $error("timestamp error: time_c=%0d last_time=%0d", time_c, last_time);
        end else begin
            assert(time_c == last_time)
                else $error("timestamp hold error: time_c=%0d last_time=%0d", time_c, last_time);
        end
        last_time <= time_c;
        end
    end

    // ---- stimulus ----
    initial begin
        reset = 1;
        repeat (3) @(posedge clk); 
        reset = 0;

        repeat (100) @(posedge clk);

        $finish;
    end

    initial begin
        $fsdbDumpfile("time.fsdb");
        $fsdbDumpvars(0, time_tb);  
    end

endmodule