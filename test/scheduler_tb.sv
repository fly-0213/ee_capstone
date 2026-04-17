`timescale 1ns/1ps

module scheduler_tb;

    localparam int SENS_NUM = 3;

    logic clk;
    logic reset;
    logic start_pulse;
    logic stop_pulse;
    logic result_valid;
    logic result_error;

    logic sens_req;
    logic [$clog2(SENS_NUM)-1:0] sens_id;

    int test_pass;
    int test_fail;

    logic prev_sens_req;
    logic [$clog2(SENS_NUM)-1:0] prev_sens_id;
    logic [1:0] prev_state;

    scheduler #(.SENS_NUM(SENS_NUM)) dut (
        .clk(clk),
        .reset(reset),
        .start_pulse(start_pulse),
        .stop_pulse(stop_pulse),
        .result_valid(result_valid),
        .result_error(result_error),
        .sens_req(sens_req),
        .sens_id(sens_id)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset) begin
            prev_sens_req <= sens_req;
            prev_sens_id  <= sens_id;
            prev_state    <= dut.state;
        end else begin
            if (sens_req != prev_sens_req ||
                sens_id  != prev_sens_id  ||
                dut.state != prev_state) begin
                $display("@@@[TRACE] t=%0t state=%0d cur_id=%0d sens_id=%0d sens_req=%0b stop_pending=%0b result_valid=%0b result_error=%0b",
                         $time, dut.state, dut.cur_id, sens_id, sens_req, dut.stop_pending,
                         result_valid, result_error);
            end

            prev_sens_req <= sens_req;
            prev_sens_id  <= sens_id;
            prev_state    <= dut.state;
        end
    end

   
    task automatic check(input bit cond, input string msg);
        begin
            if (cond) begin
                $display("@@@[PASS] %s", msg);
                test_pass++;
            end else begin
                $display("@@@[FAIL] %s", msg);
                test_fail++;
            end
        end
    endtask

    task automatic apply_reset();
        begin
            reset        = 1'b1;
            start_pulse  = 1'b0;
            stop_pulse   = 1'b0;
            result_valid = 1'b0;
            result_error = 1'b0;

            repeat (5) @(posedge clk);
            reset = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic pulse_start();
        begin
            $display("@@@[TB] pulse_start at t=%0t", $time);
            start_pulse = 1'b1;
            @(posedge clk);
            #1;
            start_pulse = 1'b0;
        end
    endtask

    task automatic pulse_stop();
        begin
            $display("@@@[TB] pulse_stop at t=%0t", $time);
            stop_pulse = 1'b1;
            @(posedge clk);
            #1;
            stop_pulse = 1'b0;
        end
    endtask

    task automatic pulse_result_valid();
        begin
            $display("@@@[TB] pulse_result_valid at t=%0t", $time);
            result_valid = 1'b1;
            @(posedge clk);
            #1;
            result_valid = 1'b0;
        end
    endtask

    task automatic pulse_result_error();
        begin
            $display("@@@[TB] pulse_result_error at t=%0t", $time);
            result_error = 1'b1;
            @(posedge clk);
            #1;
            result_error = 1'b0;
        end
    endtask

    task automatic wait_for_req_and_check_id(
        input logic [$clog2(SENS_NUM)-1:0] exp_id,
        input string msg
    );
        begin
            wait(sens_req == 1'b1);
            check(sens_id == exp_id, msg);
            @(posedge clk);
        end
    endtask

    task automatic check_req_one_pulse(input string msg);
        begin
            #1;
            check(sens_req == 1'b0, msg);
        end
    endtask

    // =========================================================
    // TEST 1
    // start -> first issue
    // =========================================================
    task automatic test_start_first_issue();
        begin
            $display("\n================ TEST 1: start -> first issue ================");

            pulse_start();

            wait(sens_req == 1'b1);
            check(dut.state == dut.S_WAIT, "scheduler enters WAIT after first issue");
            check(sens_id == 0, "first issued sensor is 0");
            @(posedge clk);
            check_req_one_pulse("sens_req is only one clock pulse on first issue");
        end
    endtask

    // =========================================================
    // TEST 2
    // round robin by result_valid
    // expected: 0 -> 1 -> 2 -> 0
    // =========================================================
    task automatic test_round_robin_valid();
        begin
            $display("\n================ TEST 2: round robin with result_valid ================");

            pulse_start();

            wait_for_req_and_check_id(0, "round 1 sensor id = 0");
            check(dut.state == dut.S_WAIT, "state is WAIT after issuing sensor 0");
            check_req_one_pulse("sens_req cleared after issuing sensor 0");

            pulse_result_valid();
            wait_for_req_and_check_id(1, "round 2 sensor id = 1");
            check_req_one_pulse("sens_req cleared after issuing sensor 1");

            pulse_result_valid();
            wait_for_req_and_check_id(2, "round 3 sensor id = 2");
            check_req_one_pulse("sens_req cleared after issuing sensor 2");

            pulse_result_valid();
            wait_for_req_and_check_id(0, "round 4 sensor id wraps back to 0");
            check_req_one_pulse("sens_req cleared after issuing wrapped sensor 0");
        end
    endtask

    // =========================================================
    // TEST 3
    // result_error should also count as done
    // =========================================================
    task automatic test_error_as_done();
        begin
            $display("\n================ TEST 3: result_error acts as sens_done ================");

            pulse_start();

            wait_for_req_and_check_id(0, "first issue sensor id = 0");
            pulse_result_error();

            wait_for_req_and_check_id(1, "scheduler advances on result_error");
            check_req_one_pulse("sens_req cleared after issuing next sensor after error");
        end
    endtask

    // =========================================================
    // TEST 4
    // no done -> should stay in WAIT and not advance
    // =========================================================
    task automatic test_hold_in_wait_without_done();
        begin
            begin
                $display("\n================ TEST 4: hold in WAIT without done ================");

                pulse_start();

                wait_for_req_and_check_id(0, "first issue sensor id = 0");
                check(dut.state == dut.S_WAIT, "state enters WAIT after first issue");

                repeat (10) @(posedge clk);

                check(dut.state == dut.S_WAIT, "scheduler stays in WAIT without sens_done");
                check(sens_req == 1'b0, "scheduler does not re-issue without sens_done");
                check(sens_id == 0, "sens_id stays stable while waiting");
            end
        end
    endtask

    // =========================================================
    // TEST 5
    // stop_pulse should finish current sensor then stop
    // =========================================================
    task automatic test_safe_stop();
        begin
            $display("\n================ TEST 5: safe stop after current sensor ================");

            pulse_start();

            // issue sensor 0
            wait_for_req_and_check_id(0, "issued sensor 0 before stop");
            check(dut.state == dut.S_WAIT, "state in WAIT for current sensor before stop");

            // ask stop while waiting
            pulse_stop();

            // should still be waiting for current sensor, not jump immediately
            repeat (2) @(posedge clk);
            check(dut.state == dut.S_WAIT, "still WAIT after stop request before current sensor finishes");

            // current sensor finishes
            pulse_result_valid();

            // should go idle instead of issuing next sensor
            repeat (2) @(posedge clk);
            check(dut.state == dut.S_IDLE, "scheduler returns to IDLE after current sensor finishes and stop pending");
            check(sens_req == 1'b0, "no new sens_req after safe stop");
        end
    endtask

    // =========================================================
    // TEST 6
    // stop during next WAIT should also work
    // =========================================================
    task automatic test_stop_after_one_advance();
        begin
            $display("\n================ TEST 6: stop after one advance ================");

            pulse_start();

            wait_for_req_and_check_id(0, "first issue sensor 0");
            pulse_result_valid();

            wait_for_req_and_check_id(1, "advanced to sensor 1");

            pulse_stop();

            repeat (2) @(posedge clk);
            check(dut.state == dut.S_WAIT, "still WAIT on sensor 1 after stop request");

            pulse_result_error();

            repeat (2) @(posedge clk);
            check(dut.state == dut.S_IDLE, "returns to IDLE after sensor 1 completes with stop pending");
            check(sens_req == 1'b0, "no extra request after stop on second sensor");
        end
    endtask

    // =========================================================
    // main
    // =========================================================
    initial begin
        test_pass = 0;
        test_fail = 0;

        apply_reset();
        test_start_first_issue();

        apply_reset();
        test_round_robin_valid();

        apply_reset();
        test_error_as_done();

        apply_reset();
        test_hold_in_wait_without_done();

        apply_reset();
        test_safe_stop();

        apply_reset();
        test_stop_after_one_advance();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #100;
        $finish;
    end

endmodule
