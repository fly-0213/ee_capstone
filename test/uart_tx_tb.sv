`timescale 1ns/1ps
`include "packet_defs.svh"

module uart_tx_tb;

    localparam int CLKS_PER_BIT_TB = 4;

    logic       clk;
    logic       reset;
    logic       tx_valid;
    logic [7:0] tx_data;

    logic       tx_serial;
    logic       tx_busy;
    logic       tx_done;
    logic       tx_ready;

    int test_pass;
    int test_fail;

    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT_TB)
    ) dut (
        .clk      (clk),
        .reset    (reset),
        .tx_valid (tx_valid),
        .tx_data  (tx_data),
        .tx_serial(tx_serial),
        .tx_busy  (tx_busy),
        .tx_done  (tx_done),
        .tx_ready (tx_ready)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    logic prev_tx_serial;
    logic prev_tx_busy;
    logic prev_tx_done;
    logic prev_tx_ready;
    logic [1:0] prev_state;
    logic [2:0] prev_bit_count;
    logic [$clog2(CLKS_PER_BIT_TB+1)-1:0] prev_clk_count;

    always @(posedge clk) begin
        if (reset) begin
            prev_tx_serial <= tx_serial;
            prev_tx_busy   <= tx_busy;
            prev_tx_done   <= tx_done;
            prev_tx_ready  <= tx_ready;
            prev_state     <= dut.state;
            prev_bit_count <= dut.bit_count;
            prev_clk_count <= dut.clk_count;
        end else begin
            if (tx_valid ||
                tx_serial != prev_tx_serial ||
                tx_busy   != prev_tx_busy   ||
                tx_done   != prev_tx_done   ||
                tx_ready  != prev_tx_ready  ||
                dut.state != prev_state     ||
                dut.bit_count != prev_bit_count ||
                dut.clk_count != prev_clk_count) begin
                $display("@@@[TRACE] t=%0t tx_valid=%0b tx_data=0x%02h | tx_serial=%0b tx_busy=%0b tx_done=%0b tx_ready=%0b state=%0d bit_count=%0d clk_count=%0d",
                         $time, tx_valid, tx_data, tx_serial, tx_busy, tx_done, tx_ready,
                         dut.state, dut.bit_count, dut.clk_count);
            end

            prev_tx_serial <= tx_serial;
            prev_tx_busy   <= tx_busy;
            prev_tx_done   <= tx_done;
            prev_tx_ready  <= tx_ready;
            prev_state     <= dut.state;
            prev_bit_count <= dut.bit_count;
            prev_clk_count <= dut.clk_count;
        end
    end

    // =========================================================
    // Helpers
    // =========================================================
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
            reset    = 1'b1;
            tx_valid = 1'b0;
            tx_data  = 8'h00;

            repeat (5) @(posedge clk);
            reset = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic pulse_tx_valid(input [7:0] data_byte);
        begin
            tx_data  = data_byte;
            tx_valid = 1'b1;
            @(posedge clk);
            tx_valid = 1'b0;
            tx_data  = 8'h00;
        end
    endtask

    task automatic expect_bit_for_clks(
        input logic exp_bit,
        input string tag
    );
        int i;
        begin
            for (i = 0; i < CLKS_PER_BIT_TB; i++) begin
                @(posedge clk);
                check(tx_serial == exp_bit, tag);
            end
        end
    endtask

    // =========================================================
    // TEST 1: reset behavior
    // =========================================================
    task automatic test_reset_behavior();
        begin
            $display("\n================ TEST 1: reset behavior ================");
            apply_reset();

            check(tx_serial == 1'b1, "tx_serial idle high after reset");
            check(tx_busy   == 1'b0, "tx_busy low after reset");
            check(tx_done   == 1'b0, "tx_done low after reset");
            check(tx_ready  == 1'b1, "tx_ready high after reset");
            check(dut.state == dut.S_IDLE, "state is S_IDLE after reset");
        end
    endtask

    // =========================================================
    // TEST 2: transmit one byte, check full frame
    // UART frame = start(0) + 8 data bits LSB-first + stop(1)
    // =========================================================
    task automatic test_one_byte_frame();
        reg [7:0] data_byte;
        int i;
        begin
            $display("\n================ TEST 2: one byte frame ================");

            apply_reset();
            data_byte = 8'hA5; // 1010_0101
                              // LSB-first: 1,0,1,0,0,1,0,1

            pulse_tx_valid(data_byte);

            // after accepting tx_valid, should become busy / not ready
            check(tx_busy  == 1'b1 || dut.state != dut.S_IDLE, "UART starts transmission after tx_valid");
            check(tx_ready == 1'b0 || dut.state != dut.S_IDLE, "tx_ready drops once transmission starts");

            // START bit
            expect_bit_for_clks(1'b0, "start bit held low");

            // DATA bits LSB-first
            for (i = 0; i < 8; i++) begin
                expect_bit_for_clks(data_byte[i], $sformatf("data bit[%0d] correct", i));
            end

            // STOP bit
            expect_bit_for_clks(1'b1, "stop bit held high");

            // completion
            check(tx_done == 1'b1, "tx_done asserted after stop bit");
            @(posedge clk);
            check(tx_done == 1'b0, "tx_done is one-cycle pulse");
            check(tx_busy == 1'b0, "tx_busy low after frame complete");
            check(tx_ready == 1'b1, "tx_ready high after frame complete");
            check(tx_serial == 1'b1, "tx_serial returns to idle high");
        end
    endtask

    // =========================================================
    // TEST 3: tx_valid during busy is ignored
    // =========================================================
    task automatic test_ignore_tx_valid_while_busy();
        begin
            $display("\n================ TEST 3: ignore tx_valid while busy ================");

            apply_reset();

            // start first byte
            pulse_tx_valid(8'h3C);

            // wait until definitely busy
            repeat (2) @(posedge clk);
            check(tx_busy == 1'b1, "UART busy during active frame");

            // pulse another tx_valid while busy
            pulse_tx_valid(8'hF0);

            // finish the original frame
            wait(tx_done == 1'b1);
            @(posedge clk);

            // after original frame is done, UART should be idle, not automatically sending second byte
            check(tx_busy == 1'b0, "UART returns idle after first frame");
            check(dut.state == dut.S_IDLE, "state back to IDLE after first frame");
            check(tx_serial == 1'b1, "tx_serial idle high after first frame");
        end
    endtask

    // =========================================================
    // TEST 4: tx_ready meaning
    // =========================================================
    task automatic test_tx_ready_behavior();
        begin
            $display("\n================ TEST 4: tx_ready behavior ================");

            apply_reset();
            check(tx_ready == 1'b1, "tx_ready high in IDLE");

            pulse_tx_valid(8'h55);
            repeat (1) @(posedge clk);

            check(tx_ready == 1'b0, "tx_ready low while frame is being sent");

            wait(tx_done == 1'b1);
            @(posedge clk);

            check(tx_ready == 1'b1, "tx_ready high again after frame done");
        end
    endtask

    // =========================================================
    // TEST 5: bit duration exactness on one sample bit
    // Here we explicitly check that start bit lasts exactly CLKS_PER_BIT_TB clocks
    // by looking at state/serial transition timing.
    // =========================================================
    task automatic test_start_bit_duration();
        int count_low;
        begin
            $display("\n================ TEST 5: start bit duration ================");

            apply_reset();

            pulse_tx_valid(8'h00);

            count_low = 0;

            // count how many clk cycles tx_serial stays low in START state
            while (dut.state == dut.S_START) begin
                @(posedge clk);
                if (tx_serial == 1'b0)
                    count_low++;
            end

            check(count_low == CLKS_PER_BIT_TB, "start bit lasts exactly CLKS_PER_BIT clocks");
        end
    endtask

    // =========================================================
    // Main
    // =========================================================
    initial begin
        test_pass = 0;
        test_fail = 0;

        test_reset_behavior();
        test_one_byte_frame();
        test_ignore_tx_valid_while_busy();
        test_tx_ready_behavior();
        test_start_bit_duration();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #100;
        $finish;
    end

endmodule