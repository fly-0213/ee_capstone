`timescale 1ns/1ps
module i2c_master_tb;

    logic        clk;
    logic        reset;

    logic        start;
    logic        rw;
    logic [6:0]  dev_addr;
    logic [7:0]  reg_addr;
    logic [2:0]  num_bytes;
    logic [15:0] wdata;
    logic        use_reg_addr;

    logic [47:0] rdata;
    logic        busy;
    logic        done;
    logic        ack_error;

    logic        sda_in;
    logic        sda_oe;
    logic        sda_out_low;
    logic        scl;

    logic        slave_drive_low;
    logic        bus_sda;

    int test_pass;
    int test_fail;

    i2c_master dut (
        .clk         (clk),
        .reset       (reset),
        .start       (start),
        .rw          (rw),
        .dev_addr    (dev_addr),
        .reg_addr    (reg_addr),
        .num_bytes   (num_bytes),
        .wdata       (wdata),
        .use_reg_addr(use_reg_addr),
        .rdata       (rdata),
        .busy        (busy),
        .done        (done),
        .ack_error   (ack_error),
        .sda_in      (sda_in),
        .sda_oe      (sda_oe),
        .sda_out_low (sda_out_low),
        .scl         (scl)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---------------------------------------------------------
    // Open-drain SDA model
    // ---------------------------------------------------------
    always_comb begin
        logic master_drive_low;
        master_drive_low = sda_oe && sda_out_low;
        bus_sda = (master_drive_low || slave_drive_low) ? 1'b0 : 1'b1;
        sda_in  = bus_sda;
    end

    // ---------------------------------------------------------
    // Debug print
    // ---------------------------------------------------------
    always @(posedge dut.tick) begin
        if (reset || start || busy || done || ack_error || dut.state != 0) begin
            $display("t=%0t reset=%0b start=%0b state=%0d phase=%0d sub=%0d w_bit_cnt=%0d byt_cnt=%0d busy=%0b done=%0b ack_error=%0b scl=%0b sda_oe=%0b sda_in=%0b",
                     $time, reset, start, dut.state, dut.phase, dut.subphase,
                     dut.w_bit_cnt, dut.byt_cnt,
                     busy, done, ack_error, scl, sda_oe, sda_in);
        end
    end

    // ---------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------
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

    task automatic wait_tick();
        @(posedge dut.tick);
    endtask

    task automatic apply_reset();
        begin
            reset           = 1'b1;
            start           = 1'b0;
            rw              = 1'b0;
            dev_addr        = '0;
            reg_addr        = '0;
            num_bytes       = '0;
            wdata           = '0;
            use_reg_addr    = 1'b0;
            slave_drive_low = 1'b0;

            repeat (5) @(posedge clk);
            reset = 1'b0;

            repeat (2) wait_tick();
        end
    endtask

    task automatic start_pulse();
        begin
            $display("@@@[TB] before start_pulse: t=%0t start=%0b state=%0d", $time, start, dut.state);
            start = 1'b1;
            $display("@@@[TB] start set to 1: t=%0t", $time);

            // 先保留 1 个 tick；如果还是对不齐，再改成 repeat (2)
            wait_tick();

            $display("@@@[TB] after one tick with start=1: t=%0t state=%0d busy=%0b done=%0b",
                     $time, dut.state, busy, done);

            start = 1'b0;
            $display("@@@[TB] start cleared to 0: t=%0t", $time);
        end
    endtask

    task automatic wait_done_tick();
        begin
            wait(done === 1'b1);
            wait_tick();
        end
    endtask

    // ---------------------------------------------------------
    // Observe one byte driven by master
    // ---------------------------------------------------------
    task automatic expect_master_byte(input [7:0] exp_byte, input string tag);
        int i;
        logic bit_seen;
        begin
            for (i = 7; i >= 0; i--) begin
                @(posedge scl);
                bit_seen = (sda_oe == 1'b0) ? 1'b1 : 1'b0;

                if (bit_seen !== exp_byte[i]) begin
                    $display("@@@[FAIL] %s bit[%0d] exp=%0b got=%0b time=%0t",
                             tag, i, exp_byte[i], bit_seen, $time);
                    test_fail++;
                end

                @(negedge scl);
            end

            $display("@@@[INFO] Master byte observed for %s = 0x%02h", tag, exp_byte);
        end
    endtask

    // ---------------------------------------------------------
    // Slave ACK / NACK
    // ---------------------------------------------------------
    task automatic slave_ack(input bit nack);
        bit saw_ack_posedge;
        begin
            saw_ack_posedge = 0;
            $display("@@@[TB] slave_ack start, nack=%0b, time=%0t", nack, $time);

            if (nack)
                slave_drive_low = 1'b0;   // NACK = release
            else
                slave_drive_low = 1'b1;   // ACK  = pull low

            $display("@@@[TB] ACK drive prepared, bus_sda=%0b, time=%0t", bus_sda, $time);

            fork
                begin
                    @(posedge scl);
                    saw_ack_posedge = 1;
                    $display("@@@[TB] saw posedge scl during ACK, bus_sda=%0b, time=%0t", bus_sda, $time);
                end
                begin
                    repeat (5000) @(posedge clk);
                    $display("@@@[FAIL] timeout waiting for ACK posedge scl, time=%0t", $time);
                    test_fail++;
                end
            join_any
            disable fork;

            if (saw_ack_posedge) begin
                @(negedge scl);
                $display("@@@[TB] saw negedge scl end ACK, time=%0t", $time);
            end

            slave_drive_low = 1'b0;
        end
    endtask

    task automatic slave_send_byte(
        input [7:0] data_byte,
        output bit master_sent_nack
    );
        int i;
        begin
            $display("@@@[TB] slave_send_byte start, data=0x%02h, time=%0t", data_byte, $time);

            slave_drive_low = (data_byte[7] == 1'b0);
            $display("@@@[TB] drive read bit[7]=%0b at t=%0t", data_byte[7], $time);

            // bit[7] ~ bit[1]
            for (i = 7; i > 0; i--) begin
                @(posedge scl);   // master samples current bit
                @(negedge scl);   // next bit setup window
                slave_drive_low = (data_byte[i-1] == 1'b0);
                $display("@@@[TB] drive read bit[%0d]=%0b at t=%0t", i-1, data_byte[i-1], $time);
            end

            @(posedge scl);

            @(negedge scl);
            slave_drive_low = 1'b0;
            $display("@@@[TB] release SDA for master's ACK/NACK at t=%0t bus_sda=%0b", $time, bus_sda);

            @(posedge scl);
            master_sent_nack = (bus_sda == 1'b1);
            $display("@@@[TB] observed master's ACK/NACK: bus_sda=%0b master_sent_nack=%0b at t=%0t",
                    bus_sda, master_sent_nack, $time);

            @(negedge scl);
            slave_drive_low = 1'b0;
        end
    endtask

    task automatic wait_repeated_start_complete();
        begin
            $display("@@@[TB] wait repeated start begin at t=%0t", $time);

            @(posedge scl);
            $display("@@@[TB] saw repeated-start scl posedge at t=%0t", $time);

            @(negedge scl);
            $display("@@@[TB] repeated start complete, back to scl low at t=%0t", $time);
        end
    endtask

    // ---------------------------------------------------------
    // TEST 1 only: write with reg, 2 bytes
    // ---------------------------------------------------------
    task automatic test_write_with_reg_2bytes();
        begin
            $display("\n================ TEST 1: WRITE with REG, 2 bytes ================");

            rw           = 1'b0;
            dev_addr     = 7'h48;
            reg_addr     = 8'h01;
            num_bytes    = 3'd2;
            wdata        = 16'hC383;
            use_reg_addr = 1'b1;

            fork
                begin : NORMAL_PATH
                    fork
                        begin : SLAVE_THREAD
                            wait(busy === 1'b1);

                            expect_master_byte({7'h48,1'b0}, "ADDR_W");
                            slave_ack(1'b0);

                            expect_master_byte(8'h01, "REG_ADDR");
                            slave_ack(1'b0);

                            expect_master_byte(8'hC3, "WDATA[15:8]");
                            slave_ack(1'b0);

                            expect_master_byte(8'h83, "WDATA[7:0]");
                            slave_ack(1'b0);
                        end

                        begin : MASTER_THREAD
                            start_pulse();
                            wait_done_tick();
                        end
                    join
                end

                begin : TIMEOUT_THREAD
                    repeat (200000) @(posedge clk);
                    $display("@@@[FAIL] TEST 1 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;

            check(busy == 1'b0, "busy deasserted when write finishes");
            check(ack_error == 1'b0, "ack_error remains 0 on normal write");
        end
    endtask

    // =========================================================
    // Test 2: read, use_reg_addr=1, num_bytes=2
    // sequence: START + ADDR_W + REG + RESTART + ADDR_R + READ2
    // expected rdata[47:32] = 16'hABCD
    // =========================================================
    task automatic test_read_with_reg_2bytes();
        bit last_nack;
        begin
            $display("\n================ TEST 2: READ with REG, 2 bytes ================");

            rw           = 1'b1;
            dev_addr     = 7'h44;
            reg_addr     = 8'h10;
            num_bytes    = 3'd2;
            wdata        = 16'h0000;
            use_reg_addr = 1'b1;

            fork
                begin : NORMAL_PATH
                    fork
                        begin : SLAVE_THREAD
                            wait(busy === 1'b1);

                            expect_master_byte({7'h44,1'b0}, "ADDR_W");
                            slave_ack(1'b0);

                            expect_master_byte(8'h10, "REG_ADDR");
                            slave_ack(1'b0);

                            wait_repeated_start_complete();

                            expect_master_byte({7'h44,1'b1}, "ADDR_R");
                            slave_ack(1'b0);

                            slave_send_byte(8'hAB, last_nack);
                            check(last_nack == 1'b0, "master ACK after read byte 0");

                            slave_send_byte(8'hCD, last_nack);
                            check(last_nack == 1'b1, "master NACK after final read byte");
                        end

                        begin : MASTER_THREAD
                            start_pulse();
                            wait_done_tick();
                        end
                    join
                end
                begin : TIMEOUT_THREAD
                    repeat (200000) @(posedge clk);
                    $display("@@@[FAIL] TEST TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;

            check(ack_error == 1'b0, "ack_error remains 0 on normal read");
            check(busy == 1'b0, "busy deasserted after read");

            check(rdata[47:40] == 8'hAB, "read byte0 stored in rdata[47:40]");
            check(rdata[39:32] == 8'hCD, "read byte1 stored in rdata[39:32]");
        end
    endtask

    // =========================================================
    // Test 3: read, use_reg_addr=0, num_bytes=1
    // sequence: START + ADDR_R + READ1
    // =========================================================
    task automatic test_read_no_reg_1byte();
        bit last_nack;
        begin
            $display("\n================ TEST 3: READ no REG, 1 byte ================");

            rw           = 1'b1;
            dev_addr     = 7'h5A;
            reg_addr     = 8'h00;
            num_bytes    = 3'd1;
            wdata        = 16'h0000;
            use_reg_addr = 1'b0;

            fork
                begin : NORMAL_PATH
                    fork
                        begin : SLAVE_THREAD
                            wait(busy === 1'b1);

                            expect_master_byte({7'h5A,1'b1}, "ADDR_R_ONLY");
                            slave_ack(1'b0);

                            slave_send_byte(8'h3C, last_nack);
                            $display("@@@[TB] last_nack = %0b at t=%0t", last_nack, $time);
                            check(last_nack == 1'b1, "master NACK after single read byte");
                        end

                        begin : MASTER_THREAD
                            start_pulse();
                            wait_done_tick();
                        end
                    join
                end

                begin : TIMEOUT_THREAD
                    repeat (200000) @(posedge clk);
                    $display("@@@[FAIL] TEST TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;

            check(ack_error == 1'b0, "ack_error = 0 on no-reg read");
            $display("@@@[TB] rdata[47:40] = 0x%02h at t=%0t", rdata[47:40], $time);
            check(rdata[47:40] == 8'h3C, "single read byte stored in rdata[47:40]");
        end
    endtask

    // =========================================================
    // Test 4: NACK on address phase
    // should go to error, busy drops, done should not assert
    // =========================================================
    task automatic test_nack_error();
        begin
            $display("\n================ TEST 4: NACK / ack_error ================");
            rw           = 1'b0;
            dev_addr     = 7'h22;
            reg_addr     = 8'h01;
            num_bytes    = 3'd1;
            wdata        = 16'h00AA;
            use_reg_addr = 1'b1;

            fork
                begin : NORMAL_PATH
                    fork
                        begin : SLAVE_THREAD
                            wait(busy === 1'b1);

                            expect_master_byte({7'h22,1'b0}, "ADDR_W");
                            slave_ack(1'b1); // NACK
                        end

                        begin : MASTER_THREAD
                            start_pulse();
                            wait(ack_error === 1'b1 || busy === 1'b0);
                        end
                    join
                end

                begin : TIMEOUT_THREAD
                    repeat (200000) @(posedge clk);
                    $display("@@@[FAIL] TEST 4 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;

            check(ack_error == 1'b1, "ack_error asserted after NACK");

            wait(busy === 1'b0);
            wait_tick();

            check(busy == 1'b0, "busy deasserted after NACK/error path");
            check(done == 1'b0, "done should not assert on error path");
        end
    endtask

    task automatic test_start_level_sensitive_success();
        int seen_done;
        begin
            $display("\n================ TEST 5A: START held high on success path ================");

            rw           = 1'b0;
            dev_addr     = 7'h30;
            reg_addr     = 8'h02;
            num_bytes    = 3'd1;
            wdata        = 16'h0055;
            use_reg_addr = 1'b1;

            seen_done = 0;

            fork
                begin : NORMAL_PATH
                    fork
                        begin : SLAVE_THREAD
                            repeat (2) begin
                                wait(busy === 1'b1);

                                expect_master_byte({7'h30,1'b0}, "ADDR_W");
                                slave_ack(1'b0);

                                expect_master_byte(8'h02, "REG_ADDR");
                                slave_ack(1'b0);

                                expect_master_byte(8'h55, "WDATA");
                                slave_ack(1'b0);

                                wait(done === 1'b1 || busy === 1'b0);
                                wait_tick();
                            end
                        end

                        begin : MASTER_THREAD
                            start = 1'b1;
                            while (seen_done < 2) begin
                                wait_tick();
                                if (done)
                                    seen_done++;
                            end

                            $display("@@@[TB] seen_done reached %0d at t=%0t", seen_done, $time);
                            start = 1'b0; 
                            repeat (3) wait_tick();
                        end
                    join
                end

                begin : TIMEOUT_THREAD
                    repeat (300000) @(posedge clk);
                    $display("@@@[FAIL] TEST 5A TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;

            $display("@@@[TB] seen_done = %0d", seen_done);

            if (seen_done >= 2) begin
                $display("@@@[INFO] start held high caused retrigger -> current design is level-sensitive");
                test_pass++;
            end else begin
                $display("@@@[FAIL] start held high did NOT retrigger within observation window");
                test_fail++;
            end
        end
    endtask

    task automatic test_start_stuck_in_error();
        begin
            $display("\n================ TEST 5B: START held high in error path ================");

            rw           = 1'b0;
            dev_addr     = 7'h22;
            reg_addr     = 8'h01;
            num_bytes    = 3'd1;
            wdata        = 16'h00AA;
            use_reg_addr = 1'b1;

            fork
                begin : NORMAL_PATH
                    fork
                        begin : SLAVE_THREAD
                            wait(busy === 1'b1);

                            expect_master_byte({7'h22,1'b0}, "ADDR_W");
                            slave_ack(1'b1); // force NACK
                        end

                        begin : MASTER_THREAD
                            $display("@@@[TB] hold start high into error path at t=%0t", $time);
                            start = 1'b1;

                            wait(dut.state == 4'd9 || ack_error == 1'b1);
                            wait_tick();

                            $display("@@@[TB] in error state with start still high: state=%0d busy=%0b ack_error=%0b t=%0t",
                                    dut.state, busy, ack_error, $time);

                            repeat (5) wait_tick();

                            start = 1'b0;
                            $display("@@@[TB] release start low at t=%0t", $time);

                            repeat (3) wait_tick();
                        end
                    join
                end

                begin : TIMEOUT_THREAD
                    repeat (200000) @(posedge clk);
                    $display("@@@[FAIL] TEST 5B TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;

            check(busy == 1'b0, "busy deasserted in error path");
            check(dut.state == 4'd0, "DUT returned to IDLE after start released");
        end
    endtask

    // ---------------------------------------------------------
    // Main
    // ---------------------------------------------------------
    initial begin
        test_pass = 0;
        test_fail = 0;

        apply_reset();
        test_write_with_reg_2bytes();

        apply_reset();
        test_read_with_reg_2bytes();

        apply_reset();
        test_read_no_reg_1byte();

        apply_reset();
        test_nack_error();

        apply_reset();
        test_start_level_sensitive_success();

        apply_reset();
        test_start_stuck_in_error();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d  FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #100;
        $finish;
    end

endmodule