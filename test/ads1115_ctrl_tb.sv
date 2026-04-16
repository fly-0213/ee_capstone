`timescale 1ns/1ps

module ads1115_ctrl_tb;
    logic        clk;
    logic        reset;
    logic        start;

    logic        i2c_busy;
    logic        i2c_done;
    logic [15:0] i2c_rdata;
    logic        i2c_ack_error;

    logic        i2c_start;
    logic        i2c_rw;
    logic [6:0]  i2c_dev_addr;
    logic [7:0]  i2c_reg_addr;
    logic [1:0]  i2c_num_bytes;
    logic [15:0] i2c_wdata;

    logic        busy;
    logic        data_valid;
    logic [15:0] data_out;
    logic        error;

    int test_pass;
    int test_fail;

    ads1115_ctrl dut (
        .clk          (clk),
        .reset        (reset),
        .start        (start),

        .i2c_busy     (i2c_busy),
        .i2c_done     (i2c_done),
        .i2c_rdata    (i2c_rdata),
        .i2c_ack_error(i2c_ack_error),

        .i2c_start    (i2c_start),
        .i2c_rw       (i2c_rw),
        .i2c_dev_addr (i2c_dev_addr),
        .i2c_reg_addr (i2c_reg_addr),
        .i2c_num_bytes(i2c_num_bytes),
        .i2c_wdata    (i2c_wdata),

        .busy         (busy),
        .data_valid   (data_valid),
        .data_out     (data_out),
        .error        (error)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset || start || i2c_start || i2c_done || i2c_ack_error || busy || data_valid || error) begin
            $display("t=%0t reset=%0b start=%0b", $time, reset, start);
            $display("    state=%0d busy=%0b i2c_start=%0b i2c_rw=%0b dev=0x%02h reg=0x%02h num_bytes=%0d wdata=0x%04h | i2c_done=%0b ack_err=%0b rdata=0x%04h | data_valid=%0b data_out=0x%04h error=%0b wait_cnt=%0d",
                    dut.state, busy, i2c_start, i2c_rw, i2c_dev_addr, i2c_reg_addr,
                    i2c_num_bytes, i2c_wdata, i2c_done, i2c_ack_error, i2c_rdata,
                    data_valid, data_out, error, dut.conv_wait_cnt);
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

    task automatic apply_reset();
        begin
            reset         = 1'b1;
            start         = 1'b0;
            i2c_busy      = 1'b0;
            i2c_done      = 1'b0;
            i2c_rdata     = 16'h0000;
            i2c_ack_error = 1'b0;

            repeat (5) @(posedge clk);
            reset = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic start_pulse();
        begin
            $display("@@@[TB] start pulse at t=%0t", $time);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
        end
    endtask

    task automatic fake_i2c_ok(input [15:0] ret_data);
        begin
            // simulate one completed i2c transaction
            i2c_busy      = 1'b1;
            i2c_done      = 1'b0;
            i2c_ack_error = 1'b0;
            i2c_rdata     = ret_data;

            repeat (3) @(posedge clk);

            i2c_busy      = 1'b0;
            i2c_done      = 1'b1;
            @(posedge clk);

            i2c_done      = 1'b0;
        end
    endtask

    task automatic fake_i2c_ack_error();
        begin
            i2c_busy      = 1'b1;
            i2c_done      = 1'b0;
            i2c_ack_error = 1'b0;
            i2c_rdata     = 16'h0000;

            repeat (3) @(posedge clk);

            i2c_busy      = 1'b0;
            i2c_ack_error = 1'b1;
            i2c_done      = 1'b1;
            @(posedge clk);

            i2c_done      = 1'b0;
            i2c_ack_error = 1'b0;
        end
    endtask

    task automatic check_write_cfg_req();
        begin
            check(i2c_start     == 1'b1,  "WRITE_CFG asserted i2c_start");
            check(i2c_rw        == 1'b0,  "WRITE_CFG rw = write");
            check(i2c_dev_addr  == 7'h48, "WRITE_CFG dev addr = 0x48");
            check(i2c_reg_addr  == 8'h01, "WRITE_CFG reg addr = CONFIG");
            check(i2c_num_bytes == 2'd2,  "WRITE_CFG num_bytes = 2");
            check(i2c_wdata     == 16'hC383, "WRITE_CFG wdata = 0xC383");
        end
    endtask

    task automatic check_read_conv_req();
        begin
            check(i2c_start     == 1'b1,  "READ_CONV asserted i2c_start");
            check(i2c_rw        == 1'b1,  "READ_CONV rw = read");
            check(i2c_dev_addr  == 7'h48, "READ_CONV dev addr = 0x48");
            check(i2c_reg_addr  == 8'h00, "READ_CONV reg addr = CONVERSION");
            check(i2c_num_bytes == 2'd2,  "READ_CONV num_bytes = 2");
        end
    endtask

    // ---------------------------------------------------------
    // TEST 1: normal flow
    // ---------------------------------------------------------
    task automatic test_ads1115_normal();
        begin
            $display("\n================ TEST 1: ADS1115 normal flow ================");

            fork
                begin : NORMAL_PATH
                    // kick off
                    start_pulse();

                    // one cycle later controller should be in WRITE_CFG
                    @(posedge clk);
                    check(dut.state == dut.S_WRITE_CFG, "entered S_WRITE_CFG after start");
                    check_write_cfg_req();

                    // fake write config done
                    fake_i2c_ok(16'h0000);

                    // should move into wait conversion
                    @(posedge clk);
                    check(dut.state == dut.S_WAIT_CONV, "entered S_WAIT_CONV after config write done");
                    check(busy == 1'b1, "busy stays high during conversion wait");

                    // shorten wait by force for simulation
                    force dut.conv_wait_cnt = dut.CONV_WAIT_CYCLES;
                    @(posedge clk);
                    release dut.conv_wait_cnt;

                    // next should issue read conversion
                    @(posedge clk);
                    check(dut.state == dut.S_READ_CONV, "entered S_READ_CONV after wait count done");
                    check_read_conv_req();

                    // fake read done with sample data
                    fake_i2c_ok(16'h1234);

                    // should go to DONE then IDLE
                    @(posedge clk);
                    check(dut.state == dut.S_DONE, "entered S_DONE after read done");
                    check(data_valid == 1'b1, "data_valid asserted in S_DONE");
                    check(data_out   == 16'h1234, "data_out latched correctly");
                    check(error      == 1'b0, "error remains 0 in normal flow");

                    @(posedge clk);
                    check(dut.state == dut.S_IDLE, "returned to S_IDLE after S_DONE");
                    check(busy      == 1'b0, "busy deasserted in S_IDLE");
                end

                begin : TIMEOUT_THREAD
                    repeat (1000) @(posedge clk);
                    $display("@@@[FAIL] TEST 1 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;
        end
    endtask

    // ---------------------------------------------------------
    // TEST 2: config write ACK error
    // ---------------------------------------------------------
    task automatic test_ads1115_cfg_ack_error();
        begin
            $display("\n================ TEST 2: ADS1115 config write ACK error ================");

            fork
                begin : NORMAL_PATH
                    start_pulse();

                    @(posedge clk);
                    check(dut.state == dut.S_WRITE_CFG, "entered S_WRITE_CFG before cfg error");
                    check_write_cfg_req();

                    fake_i2c_ack_error();

                    @(posedge clk);
                    check(dut.state == dut.S_ERROR, "entered S_ERROR after cfg write ack error");
                    check(error == 1'b1, "error asserted in S_ERROR");

                    // controller only leaves S_ERROR when start=0
                    @(posedge clk);
                    check(dut.state == dut.S_IDLE, "returned to S_IDLE after cfg error and start low");
                    check(busy == 1'b0, "busy deasserted after cfg error recovery");
                end

                begin : TIMEOUT_THREAD
                    repeat (1000) @(posedge clk);
                    $display("@@@[FAIL] TEST 2 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;
        end
    endtask

    // ---------------------------------------------------------
    // TEST 3: read conversion ACK error
    // ---------------------------------------------------------
    task automatic test_ads1115_read_ack_error();
        begin
            $display("\n================ TEST 3: ADS1115 read conversion ACK error ================");

            fork
                begin : NORMAL_PATH
                    start_pulse();

                    @(posedge clk);
                    check(dut.state == dut.S_WRITE_CFG, "entered S_WRITE_CFG before read error");
                    check_write_cfg_req();

                    // config write succeeds
                    fake_i2c_ok(16'h0000);

                    @(posedge clk);
                    check(dut.state == dut.S_WAIT_CONV, "entered S_WAIT_CONV before read error");

                    // fast-forward conversion wait
                    force dut.conv_wait_cnt = dut.CONV_WAIT_CYCLES;
                    @(posedge clk);
                    release dut.conv_wait_cnt;

                    @(posedge clk);
                    check(dut.state == dut.S_READ_CONV, "entered S_READ_CONV before read ack error");
                    check_read_conv_req();

                    // read transaction fails
                    fake_i2c_ack_error();

                    @(posedge clk);
                    check(dut.state == dut.S_ERROR, "entered S_ERROR after read ack error");
                    check(error == 1'b1, "error asserted on read ack error");

                    @(posedge clk);
                    check(dut.state == dut.S_IDLE, "returned to S_IDLE after read error and start low");
                    check(busy == 1'b0, "busy deasserted after read error recovery");
                end

                begin : TIMEOUT_THREAD
                    repeat (1000) @(posedge clk);
                    $display("@@@[FAIL] TEST 3 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;
        end
    endtask

    // ---------------------------------------------------------
    // Main
    // ---------------------------------------------------------
    initial begin
        test_pass = 0;
        test_fail = 0;

        apply_reset();
        test_ads1115_normal();

        apply_reset();
        test_ads1115_cfg_ack_error();

        apply_reset();
        test_ads1115_read_ack_error();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #100;
        $finish;
    end

endmodule