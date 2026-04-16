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
    always #5 clk = ~clk;   // 100MHz

    // =========================================================
    // Simple open-drain slave side
    // master drives:
    //   0 -> sda_oe=1 and sda_out_low=1
    //   1 -> sda_oe=0 (release)
    //
    // slave_drive_low=1 means slave pulls SDA low
    // =========================================================
    logic slave_drive_low;
    logic bus_sda;

    always_comb begin
        logic master_drive_low;
        master_drive_low = sda_oe && sda_out_low;
        bus_sda = (master_drive_low || slave_drive_low) ? 1'b0 : 1'b1;
        sda_in  = bus_sda;
    end

    
    int test_pass;
    int test_fail;

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
            reset         = 1'b1;
            start         = 1'b0;
            rw            = 1'b0;
            dev_addr      = '0;
            reg_addr      = '0;
            num_bytes     = '0;
            wdata         = '0;
            use_reg_addr  = 1'b0;
            slave_drive_low = 1'b0;

            repeat (5) @(posedge clk);
            reset = 1'b0;

            repeat (2) wait_tick();
        end
    endtask

    // 给一个“只维持一个 tick”的 start pulse
    task automatic start_pulse();
        begin
            start = 1'b1;
            wait_tick();
            start = 1'b0;
        end
    endtask

    task automatic wait_done_tick();
        begin
            wait(done === 1'b1);
            @(posedge clk);
        end
    endtask

    task automatic wait_idle_tick();
        begin
            wait(busy === 1'b0 && done === 1'b0);
            @(posedge clk);
        end
    endtask

    // 检查 master 发出的一个 byte
    task automatic expect_master_byte(input [7:0] exp_byte, input string tag);
        int i;
        logic bit_seen;
        begin
            for (i = 7; i >= 0; i--) begin
                @(posedge scl);
                // master 写 0: sda_oe=1,sda_out_low=1
                // master 写 1: sda_oe=0
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

    // slave 在 ACK 位给 ACK/NACK
    task automatic slave_ack(input bit nack);
        begin
            @(negedge scl);
            if (nack)
                slave_drive_low = 1'b0; // NACK = release high
            else
                slave_drive_low = 1'b1; // ACK  = pull low

            @(posedge scl);  // master samples here
            @(negedge scl);
            slave_drive_low = 1'b0;
        end
    endtask

    // slave 发送一个读字节
    task automatic slave_send_byte(
        input [7:0] data_byte,
        output bit master_sent_nack
    );
        int i;
        begin
            for (i = 7; i >= 0; i--) begin
                @(negedge scl);
                slave_drive_low = (data_byte[i] == 1'b0);
                @(posedge scl); // master samples
            end

            // 第9位：master ACK/NACK
            @(negedge scl);
            slave_drive_low = 1'b0; // release
            @(posedge scl);
            master_sent_nack = (bus_sda == 1'b1); // 1 means NACK
            @(negedge scl);
        end
    endtask

    // =========================================================
    // Test 1: write, use_reg_addr=1, num_bytes=2
    // sequence: START + ADDR_W + REG + DATA_HI + DATA_LO + STOP
    // =========================================================
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

            check(done == 1'b1, "done asserted at end of write");
            check(busy == 1'b0, "busy deasserted when write finishes");
            check(ack_error == 1'b0, "ack_error remains 0 on normal write");

            // done 在下一次 tick 应该回到 0
            wait_tick();
            check(done == 1'b0, "done cleared after one tick window");
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
                begin : SLAVE_THREAD
                    wait(busy === 1'b1);

                    expect_master_byte({7'h44,1'b0}, "ADDR_W");
                    slave_ack(1'b0);

                    expect_master_byte(8'h10, "REG_ADDR");
                    slave_ack(1'b0);

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

            check(ack_error == 1'b0, "ack_error remains 0 on normal read");
            check(busy == 1'b0, "busy deasserted after read");

            // 注意：如果这里失败，很可能就是你 rx_shift / rdata 那个最后一位的问题
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
                begin : SLAVE_THREAD
                    wait(busy === 1'b1);

                    expect_master_byte({7'h5A,1'b1}, "ADDR_R_ONLY");
                    slave_ack(1'b0);

                    slave_send_byte(8'h3C, last_nack);
                    check(last_nack == 1'b1, "master NACK after single read byte");
                end

                begin : MASTER_THREAD
                    start_pulse();
                    wait_done_tick();
                end
            join

            check(ack_error == 1'b0, "ack_error = 0 on no-reg read");
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
                begin : SLAVE_THREAD
                    wait(busy === 1'b1);

                    expect_master_byte({7'h22,1'b0}, "ADDR_W");
                    slave_ack(1'b1); // NACK here
                end

                begin : MASTER_THREAD
                    start_pulse();
                end
            join

            // 等待进入 error / busy 拉低
            repeat (5) wait_tick();

            check(ack_error == 1'b1, "ack_error asserted after NACK");
            check(busy == 1'b0, "busy deasserted after NACK/error path");
            check(done == 1'b0, "done should not assert on error path");
        end
    endtask

    // =========================================================
    // Test 5: start kept high too long
    // 这个测试是为了证明当前 design 对 start 的要求是“pulse”
    // 如果 start 一直维持高，回到 IDLE 后会重启 transaction
    // =========================================================
    task automatic test_start_level_sensitive();
        int seen_done;
        begin
            $display("\n================ TEST 5: START held high ================");

            rw           = 1'b0;
            dev_addr     = 7'h30;
            reg_addr     = 8'h02;
            num_bytes    = 3'd1;
            wdata        = 16'h0055;
            use_reg_addr = 1'b1;

            seen_done = 0;

            fork
                begin : SLAVE_THREAD
                    // 准备连续应答两次 transaction
                    repeat (2) begin
                        wait(busy === 1'b1);

                        expect_master_byte({7'h30,1'b0}, "ADDR_W");
                        slave_ack(1'b0);

                        expect_master_byte(8'h02, "REG_ADDR");
                        slave_ack(1'b0);

                        expect_master_byte(8'h55, "WDATA");
                        slave_ack(1'b0);

                        wait(busy === 1'b0);
                    end
                end

                begin : MASTER_THREAD
                    start = 1'b1;
                    repeat (200) begin
                        wait_tick();
                        if (done) seen_done++;
                    end
                    start = 1'b0;
                end
            join_any
            disable fork;

            // 如果 seen_done >= 2，说明 start 高电平真的会触发多次
            if (seen_done >= 2) begin
                $display("[INFO] start held high caused multiple transactions -> current design is level-sensitive");
                test_pass++;
            end else begin
                $display("[INFO] start held high did NOT retrigger within observation window");
                // 不强制判 fail，因为仿真窗口也会影响
            end
        end
    endtask

    // =========================================================
    // Main
    // =========================================================
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

        test_start_level_sensitive();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d  FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #100;
        $finish;
    end

endmodule