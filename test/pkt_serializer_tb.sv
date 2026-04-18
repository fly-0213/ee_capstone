`timescale 1ns/1ps
`include "packet_defs.svh"

module pkt_serializer_tb;

    logic              clk;
    logic              reset;
    logic              pkt_valid;
    logic [PACK_W-1:0] packet_in;
    logic              pkt_ready;
    logic              uart_ready;

    logic [7:0]        byte_out;
    logic              pkt_done;
    logic              byte_valid;
    logic              busy;

    int test_pass;
    int test_fail;

    packet_t pkt0, pkt1;
    logic [PACK_W-1:0] bits0, bits1;

    localparam int NBYTES = PACK_W/8;

    pkt_serializer dut (
        .clk       (clk),
        .reset     (reset),
        .pkt_valid (pkt_valid),
        .packet_in (packet_in),
        .pkt_ready (pkt_ready),
        .uart_ready(uart_ready),
        .byte_out  (byte_out),
        .pkt_done  (pkt_done),
        .byte_valid(byte_valid),
        .busy      (busy)
    );

    // =========================================================
    // Clock
    // =========================================================
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // =========================================================
    // Concise trace
    // =========================================================
    logic prev_pkt_ready;
    logic prev_busy;
    logic prev_byte_valid;
    logic prev_pkt_done;
    logic [1:0] prev_state;
    logic [$clog2(NBYTES)-1:0] prev_byte_count;

    always @(posedge clk) begin
        if (reset) begin
            prev_pkt_ready  <= pkt_ready;
            prev_busy       <= busy;
            prev_byte_valid <= byte_valid;
            prev_pkt_done   <= pkt_done;
            prev_state      <= dut.state;
            prev_byte_count <= dut.byte_count;
        end else begin
            if (pkt_valid || uart_ready ||
                pkt_ready  != prev_pkt_ready  ||
                busy       != prev_busy       ||
                byte_valid != prev_byte_valid ||
                pkt_done   != prev_pkt_done   ||
                dut.state  != prev_state      ||
                dut.byte_count != prev_byte_count) begin
                $display("@@@[TRACE] t=%0t pkt_valid=%0b pkt_ready=%0b uart_ready=%0b busy=%0b state=%0d byte_count=%0d byte_valid=%0b byte_out=0x%02h pkt_done=%0b",
                         $time, pkt_valid, pkt_ready, uart_ready, busy, dut.state,
                         dut.byte_count, byte_valid, byte_out, pkt_done);
            end

            prev_pkt_ready  <= pkt_ready;
            prev_busy       <= busy;
            prev_byte_valid <= byte_valid;
            prev_pkt_done   <= pkt_done;
            prev_state      <= dut.state;
            prev_byte_count <= dut.byte_count;
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
            reset     = 1'b1;
            pkt_valid = 1'b0;
            packet_in = '0;
            uart_ready= 1'b0;

            repeat (5) @(posedge clk);
            reset = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic build_pkt(
        output packet_t pkt,
        output logic [PACK_W-1:0] bits,
        input logic [SENSOR_W-1:0] in_sensor,
        input logic [TS_W-1:0]     in_ts,
        input logic [DATA_W-1:0]   in_data,
        input logic [FLAG_W-1:0]   in_flag,
        input logic [CRC_W-1:0]    in_crc
    );
        begin
            pkt.head   = HEAD_MAGIC;
            pkt.sensor = in_sensor;
            pkt.ts     = in_ts;
            pkt.data   = in_data;
            pkt.flag   = in_flag;
            pkt.crc    = in_crc;
            bits       = pkt;
        end
    endtask

    task automatic drive_pkt_valid_hold(input [PACK_W-1:0] pkt_bits, input int ncycles);
        int i;
        begin
            packet_in = pkt_bits;
            pkt_valid = 1'b1;
            for (i = 0; i < ncycles; i++) begin
                @(posedge clk);
            end
            #1;
            pkt_valid = 1'b0;
            packet_in = '0;
        end
    endtask

    task automatic drive_one_handshake_pkt(input [PACK_W-1:0] pkt_bits);
        begin
            packet_in = pkt_bits;
            pkt_valid = 1'b1;
            @(posedge clk);
            #1;
            pkt_valid = 1'b0;
            packet_in = '0;
        end
    endtask

    task automatic check_byte_sequence(
        input [PACK_W-1:0] pkt_bits,
        input string tag
    );
        int i;
        logic [7:0] exp_byte;
        begin
            for (i = 0; i < NBYTES; i++) begin
                @(posedge clk);
                #1;
                wait(byte_valid == 1'b1);
                exp_byte = pkt_bits[(PACK_W-1) - 8*i -: 8];
                check(byte_out == exp_byte, {tag, " byte ", $sformatf("%0d", i), " correct"});
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

            check(pkt_ready   == 1'b1, "pkt_ready high in IDLE after reset");
            check(busy        == 1'b0, "busy low after reset");
            check(byte_valid  == 1'b0, "byte_valid low after reset");
            check(pkt_done    == 1'b0, "pkt_done low after reset");
            check(byte_out    == '0,   "byte_out reset to 0");
            check(dut.state   == dut.S_IDLE, "state is S_IDLE after reset");
        end
    endtask

    // =========================================================
    // TEST 2: normal packet send, uart_ready always 1
    // =========================================================
    task automatic test_normal_send();
        begin
            $display("\n================ TEST 2: normal send ================");
            apply_reset();

            uart_ready = 1'b1;

            fork
                begin : DRIVE_THREAD
                    drive_one_handshake_pkt(bits0);
                end
                begin : CHECK_THREAD
                    wait(busy == 1'b1);
                    check(pkt_ready == 1'b0, "pkt_ready low while sending");
                    check_byte_sequence(bits0, "normal send");
                    wait(pkt_done == 1'b1);
                    check(pkt_done == 1'b1, "pkt_done asserted on final byte");
                    @(posedge clk);
                    check(busy == 1'b0, "busy low after finishing packet");
                    check(pkt_ready == 1'b1, "pkt_ready high after finishing packet");
                end
            join
        end
    endtask

    // =========================================================
    // TEST 3: pause when uart_ready=0
    // =========================================================
    task automatic test_pause_on_uart_not_ready();
        logic [7:0] first_byte;
        begin
            $display("\n================ TEST 3: pause on uart_ready=0 ================");
            apply_reset();

            first_byte = bits0[(PACK_W-1) -: 8];

            uart_ready = 1'b1;
            drive_one_handshake_pkt(bits0);

            wait(byte_valid == 1'b1);
            check(byte_out == first_byte, "first byte sent before pause");

            // stall uart
            uart_ready = 1'b0;
            repeat (5) @(posedge clk);

            check(byte_valid == 1'b0, "byte_valid stays low while uart_ready=0");
            check(busy == 1'b1, "busy remains high while paused");

            // resume
            uart_ready = 1'b1;
            wait(pkt_done == 1'b1);
            check(pkt_done == 1'b1, "pkt_done eventually asserted after resume");
        end
    endtask

    // =========================================================
    // TEST 4: pkt_valid held high before serializer ready
    // standard ready/valid behavior
    // =========================================================
    task automatic test_input_handshake_hold_valid();
        begin
            $display("\n================ TEST 4: input handshake hold-valid ================");
            apply_reset();

            // first packet starts
            uart_ready = 1'b1;
            drive_one_handshake_pkt(bits0);

            wait(busy == 1'b1);
            check(pkt_ready == 1'b0, "pkt_ready low while first packet is active");

            // while busy, keep pkt_valid high with a new packet
            packet_in = bits1;
            pkt_valid = 1'b1;

            // serializer should ignore until it comes back to IDLE
            repeat (NBYTES/2) @(posedge clk);
            check(busy == 1'b1, "still busy during first packet");
            check(pkt_ready == 1'b0, "pkt_ready still low during first packet");

            // hold valid until first packet completes and second packet is accepted
            wait(pkt_done == 1'b1);
            @(posedge clk);

            // keep holding one more cycle so second handshake can occur in IDLE
            @(posedge clk);

            pkt_valid = 1'b0;
            packet_in = '0;

            wait(busy == 1'b1);
            check(dut.pkt_mem == bits1, "second packet loaded after pkt_ready returned high");
        end
    endtask

    // =========================================================
    // TEST 5: busy state ignores one-cycle pkt_valid pulse
    // when not ready
    // =========================================================
    task automatic test_busy_ignores_non_handshaked_pulse();
        begin
            $display("\n================ TEST 5: busy ignores non-handshaked pulse ================");
            apply_reset();

            uart_ready = 1'b1;
            drive_one_handshake_pkt(bits0);

            wait(busy == 1'b1);

            // one-cycle pulse while busy: should NOT be accepted
            packet_in = bits1;
            pkt_valid = 1'b1;
            @(posedge clk);
            #1;
            pkt_valid = 1'b0;
            packet_in = '0;

            // finish current packet
            wait(pkt_done == 1'b1);
            @(posedge clk);

            check(busy == 1'b0, "back to idle after first packet");
            check(pkt_ready == 1'b1, "pkt_ready high after first packet");
            check(dut.pkt_mem != bits1, "non-handshaked pulse was not incorrectly loaded");
        end
    endtask

    // =========================================================
    // TEST 6: exact number of byte_valid pulses
    // =========================================================
    task automatic test_exact_byte_count();
        int count_bytes;
        begin
            $display("\n================ TEST 6: exact byte count ================");
            apply_reset();

            uart_ready = 1'b1;
            count_bytes = 0;

            fork
                begin
                    drive_one_handshake_pkt(bits0);
                end
                begin
                    while (!pkt_done) begin
                        @(posedge clk);
                        if (byte_valid)
                            count_bytes++;
                    end
                end
            join

            check(count_bytes == NBYTES, "exactly PACK_W/8 byte_valid pulses observed");
        end
    endtask

    // =========================================================
    // Build packets
    // =========================================================
    initial begin
        build_pkt(pkt0, bits0, S_ADS1115, 16'h00A5, 32'h1234_5678, 4'h0, 4'h0);
        build_pkt(pkt1, bits1, S_MPL3115, 16'h00F0, 32'h89AB_CDEF, 4'h1, 4'h0);
    end

    // =========================================================
    // Main
    // =========================================================
    initial begin
        test_pass = 0;
        test_fail = 0;

        test_reset_behavior();
        test_normal_send();
        test_pause_on_uart_not_ready();
        test_input_handshake_hold_valid();
        test_busy_ignores_non_handshaked_pulse();
        test_exact_byte_count();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #100;
        $finish;
    end

endmodule
