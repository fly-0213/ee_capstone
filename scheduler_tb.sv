`timescale 1ns/1ps

module scheduler_tb;
    localparam int SENS_NUM = 4;
    logic clk;
    logic reset;
    logic start_pulse;
    logic stop_pulse;

    // handshake with sensor interface (mocked here)
    logic sens_valid;
    //logic sens_busy;
    logic sens_req;
    logic [$clog2(SENS_NUM)-1:0] sens_id;

    scheduler #(.SENS_NUM(SENS_NUM)) dut (
        .clk(clk),
        .reset(reset),
        .start_pulse(start_pulse),
        .stop_pulse(stop_pulse),
        .sens_valid(sens_valid),
        //.sens_busy(sens_busy),
        .sens_req(sens_req),
        .sens_id(sens_id)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("scheduler_tb.vcd");
        $dumpvars(0, scheduler_tb);
    end

    initial begin
        reset       = 1;
        start_pulse = 0;
        stop_pulse  = 0;

        sens_valid  = 0;
        sens_busy   = 0;

        // hold reset for a few cycles
        repeat (5) @(posedge clk);
        reset = 0;

        // wait a bit, then "UI click Start"
        repeat (3) @(posedge clk);
        pulse_start();

        // let it poll for a while
        repeat (80) @(posedge clk);

        // "UI click Stop" 
        pulse_stop();

        // run a bit more to observe it stopping
        repeat (30) @(posedge clk);

        $display("@@@TB finished. Check waveform scheduler_tb.vcd");
        $finish;
    end

    task automatic pulse_start();
        begin
            @(posedge clk);
            start_pulse <= 1'b1;
            @(posedge clk);
            start_pulse <= 1'b0;
        end
    endtask

    task automatic pulse_stop();
        begin
            @(posedge clk);
            stop_pulse <= 1'b1;
            @(posedge clk);
            stop_pulse <= 1'b0;
        end
    endtask

    // -------------------------
    // Mock sensor interface behavior
    //
    // Semantics:
    // - When DUT raises sens_req (1-cycle pulse), capture current sens_id
    // - Raise sens_busy for a few cycles
    // - After a sensor-dependent delay, raise sens_valid for 1 cycle
    //
    // This makes polling visible & deterministic in waveform.
    // -------------------------
    logic pending;
    logic [$clog2(SENS_NUM)-1:0] pending_id;
    int countdown;

    // choose different delays per sensor to make waveform obvious
    function automatic int delay_for_id(input logic [$clog2(SENS_NUM)-1:0] id);
        case (id)
            0: delay_for_id = 2;
            1: delay_for_id = 4;
            2: delay_for_id = 3;
            3: delay_for_id = 5;
            default: delay_for_id = 3;
        endcase
    endfunction

    always_ff @(posedge clk) begin
        if (reset) begin
            pending     <= 1'b0;
            pending_id  <= '0;
            countdown   <= 0;
            //sens_busy   <= 1'b0;
            sens_valid  <= 1'b0;
        end else begin
            // default: valid is a pulse
            sens_valid <= 1'b0;

            // accept a new request only if nothing pending
            if (sens_req && !pending) begin
                pending    <= 1'b1;
                pending_id <= sens_id;
                countdown  <= delay_for_id(sens_id);
                sens_busy  <= 1'b1;
            end

            // progress the pending transaction
            if (pending) begin
                if (countdown > 0) begin
                    countdown <= countdown - 1;
                end else begin
                    // done: drop busy, pulse valid
                    sens_busy  <= 1'b0;
                    sens_valid <= 1'b1;
                    pending    <= 1'b0;
                end
            end
        end
    end

    // -------------------------
    // Simple sanity checks
    // -------------------------

    always_ff @(posedge clk) begin
        if (!reset) begin
            if (sens_req) begin
                // next cycle it should be 0 (because DUT sets default sens_req<=0 each cycle)
            end
        end
    end

    logic sens_req_d;
    always_ff @(posedge clk) begin
        if (reset) sens_req_d <= 1'b0;
        else       sens_req_d <= sens_req;
    end

    always_ff @(posedge clk) begin
        if (!reset) begin
            if (sens_req && sens_req_d) begin
                $error("sens_req stayed high for >1 cycle (not a pulse).");
            end
        end
    end

endmodule