`timescale 1ns/1ps

module uart_tx_tb;

    localparam int CLKS_PER_BIT = 4;

    logic       clk;
    logic       reset;
    logic       tx_valid;
    logic [7:0] tx_data;

    logic       tx_serial;
    logic       tx_busy;
    logic       tx_done;

    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) dut (
        .clk      (clk),
        .reset    (reset),
        .tx_valid (tx_valid),
        .tx_data  (tx_data),
        .tx_serial(tx_serial),
        .tx_busy  (tx_busy),
        .tx_done  (tx_done)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("uart_tx_tb.vcd");
        $dumpvars(0, uart_tx_tb);
    end

    task automatic send_byte(input logic [7:0] data);
    begin
        @(negedge clk);
        tx_valid = 1'b1;
        tx_data  = data;

        @(negedge clk);
        tx_valid = 1'b0;
        tx_data  = '0;
    end
    endtask


    task automatic check_uart_bit(
        input logic expected_bit,
        input string bit_name
    );
        integer k;
    begin
        while (tx_serial !== expected_bit) begin
            @(posedge clk);
            #1;
        end

        for (k = 0; k < CLKS_PER_BIT; k = k + 1) begin
            if (tx_serial !== expected_bit) begin
                $display("@@@ERROR @ %0t: %s mismatch", $time, bit_name);
                $display("@@@Expected tx_serial = %b", expected_bit);
                $display("@@@Got               = %b", tx_serial);
                $fatal;
            end

            if (k < CLKS_PER_BIT-1) begin
                @(posedge clk);
                #1;
            end
        end

        $display("@@@PASS  @ %0t: %s correct (%b)", $time, bit_name, expected_bit);
    end
    endtask

    integer i;
    logic [7:0] test_byte;

    initial begin
        // init
        reset    = 1'b1;
        tx_valid = 1'b0;
        tx_data  = 8'h00;

        $display("==== Start uart_tx testbench ====");

        // hold reset
        repeat (3) @(posedge clk);
        #1;

        // check reset / idle
        if (tx_serial !== 1'b1 || tx_busy !== 1'b0 || tx_done !== 1'b0) begin
            $display("@@@ERROR @ %0t: reset state incorrect", $time);
            $display("@@@tx_serial = %b", tx_serial);
            $display("@@@tx_busy   = %b", tx_busy);
            $display("@@@tx_done   = %b", tx_done);
            $fatal;
        end else begin
            $display("@@@PASS  @ %0t: reset/idle state correct", $time);
        end

        // release reset
        @(negedge clk);
        reset = 1'b0;

        // -------------------------------------------------
        // Test 1: send one byte
        // choose a byte with mixed bits to check LSB-first
        // Example: 8'hA5 = 1010_0101
        // LSB-first order = 1,0,1,0,0,1,0,1
        // -------------------------------------------------
        test_byte = 8'hA5;
        send_byte(test_byte);

        // after request accepted, UART should become busy
        @(posedge clk);
        #1;
        if (tx_busy !== 1'b1) begin
            $display("@@@ERROR @ %0t: tx_busy should go high after tx_valid", $time);
            $fatal;
        end else begin
            $display("@@@PASS  @ %0t: tx_busy asserted", $time);
        end

        // start bit
        check_uart_bit(1'b0, "START bit");

        // 8 data bits, LSB first
        for (i = 0; i < 8; i = i + 1) begin
            check_uart_bit(test_byte[i], $sformatf("DATA bit %0d", i));
        end

        // stop bit
        check_uart_bit(1'b1, "STOP bit");

        // after stop completes, tx_done should pulse and tx_busy should drop
        @(posedge clk);
        #1;
        if (tx_done !== 1'b1) begin
            $display("@@@ERROR @ %0t: tx_done should pulse after stop bit", $time);
            $fatal;
        end else begin
            $display("@@@PASS  @ %0t: tx_done pulsed correctly", $time);
        end

        if (tx_busy !== 1'b0) begin
            $display("@@@ERROR @ %0t: tx_busy should deassert after transmission", $time);
            $fatal;
        end else begin
            $display("@@@PASS  @ %0t: tx_busy deasserted correctly", $time);
        end

        // next cycle tx_done should go low again
        @(posedge clk);
        #1;
        if (tx_done !== 1'b0) begin
            $display("@@@ERROR @ %0t: tx_done should be a one-cycle pulse", $time);
            $fatal;
        end else begin
            $display("@@@PASS  @ %0t: tx_done pulse width correct", $time);
        end

        // idle line should return high
        if (tx_serial !== 1'b1) begin
            $display("@@@ERROR @ %0t: tx_serial should return to idle high", $time);
            $fatal;
        end else begin
            $display("@@@PASS  @ %0t: tx_serial returned to idle high", $time);
        end

        $display("==== All uart_tx tests passed ====");
        $finish;
    end

endmodule