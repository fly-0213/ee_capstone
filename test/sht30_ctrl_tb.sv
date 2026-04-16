`timescale 1ns/1ps

module sht30_ctrl_tb;
    logic        clk;
    logic        reset;
    logic        start;

    // fake i2c return side
    logic        i2c_busy;
    logic        i2c_done;
    logic [47:0] i2c_rdata;
    logic        i2c_ack_error;

    // controller request side
    logic        i2c_start;
    logic        i2c_rw;
    logic [6:0]  i2c_dev_addr;
    logic [15:0] i2c_wdata;
    logic [2:0]  i2c_num_bytes;

    // controller outputs
    logic        busy;
    logic        data_valid;
    logic [15:0] temp_raw;
    logic [15:0] hum_raw;
    logic        error;

    int test_pass;
    int test_fail;

    sht30_ctrl dut (
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
        .i2c_wdata    (i2c_wdata),
        .i2c_num_bytes(i2c_num_bytes),

        .busy         (busy),
        .data_valid   (data_valid),
        .temp_raw     (temp_raw),
        .hum_raw      (hum_raw),
        .error        (error)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset || start || i2c_start || i2c_done || i2c_ack_error || busy || data_valid || error) begin
            $display("t=%0t reset=%0b start=%0b", $time, reset, start);
            $display("    state=%0d busy=%0b i2c_start=%0b i2c_rw=%0b dev=0x%02h num_bytes=%0d wdata=0x%04h | i2c_done=%0b ack_err=%0b rdata=0x%012h | data_valid=%0b temp_raw=0x%04h hum_raw=0x%04h error=%0b wait_cnt=%0d",
                     dut.state, busy, i2c_start, i2c_rw, i2c_dev_addr, i2c_num_bytes, i2c_wdata,
                     i2c_done, i2c_ack_error, i2c_rdata,
                     data_valid, temp_raw, hum_raw, error, dut.meas_wait_cnt);
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
            i2c_rdata     = 48'h0;
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

    task automatic fake_i2c_ok(input [47:0] ret_data);
        begin
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
            i2c_rdata     = 48'h0;

            repeat (3) @(posedge clk);

            i2c_busy      = 1'b0;
            i2c_ack_error = 1'b1;
            i2c_done      = 1'b1;
            @(posedge clk);

            i2c_done      = 1'b0;
            i2c_ack_error = 1'b0;
        end
    endtask

    task automatic check_send_cmd_req();
        begin
            check(i2c_start     == 1'b1,   "SEND_CMD asserted i2c_start");
            check(i2c_rw        == 1'b0,   "SEND_CMD rw = write");
            check(i2c_dev_addr  == 7'h44,  "SEND_CMD dev addr = 0x44");
            check(i2c_num_bytes == 3'd2,   "SEND_CMD num_bytes = 2");
            check(i2c_wdata     == 16'h2400, "SEND_CMD wdata = 0x2400");
        end
    endtask

    task automatic check_read_data_req();
        begin
            check(i2c_start     == 1'b1,  "READ_DATA asserted i2c_start");
            check(i2c_rw        == 1'b1,  "READ_DATA rw = read");
            check(i2c_dev_addr  == 7'h44, "READ_DATA dev addr = 0x44");
            check(i2c_num_bytes == 3'd6,  "READ_DATA num_bytes = 6");
        end
    endtask

    // ---------------------------------------------------------
    // TEST 1: normal flow
    // ---------------------------------------------------------
    task automatic test_sht30_normal();
        begin
            $display("\n================ TEST 1: SHT30 normal flow ================");

            // example return data:
            // [47:40] Temp MSB = 0x66
            // [39:32] Temp LSB = 0x80
            // [31:24] Temp CRC = 0xAA
            // [23:16] RH   MSB = 0x99
            // [15:8]  RH   LSB = 0xA0
            // [7:0]   RH   CRC = 0x55
            //
            // expected:
            // temp_raw = 16'h6680
            // hum_raw  = 16'h99A0

            fork
                begin : NORMAL_PATH
                    start_pulse();

                    @(posedge clk);
                    check(dut.state == dut.S_SEND_CMD, "entered S_SEND_CMD after start");
                    check_send_cmd_req();

                    // command write success
                    fake_i2c_ok(48'h0);

                    @(posedge clk);
                    check(dut.state == dut.S_WAIT_MEAS, "entered S_WAIT_MEAS after command done");
                    check(busy == 1'b1, "busy stays high during measurement wait");

                    // fast-forward measurement wait
                    force dut.meas_wait_cnt = dut.MEAS_WAIT_CYCLES;
                    @(posedge clk);
                    release dut.meas_wait_cnt;

                    @(posedge clk);
                    check(dut.state == dut.S_READ_DATA, "entered S_READ_DATA after wait count done");
                    check_read_data_req();

                    // read 6 bytes success
                    fake_i2c_ok(48'h66_80_AA_99_A0_55);

                    @(posedge clk);
                    check(dut.state == dut.S_PARSE, "entered S_PARSE after successful read");

                    @(posedge clk);
                    check(dut.state == dut.S_DONE, "entered S_DONE after parse");
                    check(data_valid == 1'b1, "data_valid asserted in S_DONE");
                    check(temp_raw   == 16'h6680, "temp_raw parsed correctly");
                    check(hum_raw    == 16'h99A0, "hum_raw parsed correctly");
                    check(error      == 1'b0, "error remains 0 in normal flow");

                    @(posedge clk);
                    check(dut.state == dut.S_IDLE, "returned to S_IDLE after S_DONE");
                    check(busy      == 1'b0, "busy deasserted in S_IDLE");
                end

                begin : TIMEOUT_THREAD
                    repeat (1200) @(posedge clk);
                    $display("@@@[FAIL] TEST 1 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;
        end
    endtask

    // ---------------------------------------------------------
    // TEST 2: command write ACK error
    // ---------------------------------------------------------
    task automatic test_sht30_cmd_ack_error();
        begin
            $display("\n================ TEST 2: SHT30 command ACK error ================");

            fork
                begin : NORMAL_PATH
                    start_pulse();

                    @(posedge clk);
                    check(dut.state == dut.S_SEND_CMD, "entered S_SEND_CMD before cmd error");
                    check_send_cmd_req();

                    fake_i2c_ack_error();

                    @(posedge clk);
                    check(dut.state == dut.S_ERROR, "entered S_ERROR after command ack error");
                    check(error == 1'b1, "error asserted in S_ERROR after command ack error");

                    @(posedge clk);
                    check(dut.state == dut.S_IDLE, "returned to S_IDLE after command error and start low");
                    check(busy == 1'b0, "busy deasserted after command error recovery");
                end

                begin : TIMEOUT_THREAD
                    repeat (1200) @(posedge clk);
                    $display("@@@[FAIL] TEST 2 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;
        end
    endtask

    // ---------------------------------------------------------
    // TEST 3: read data ACK error
    // ---------------------------------------------------------
    task automatic test_sht30_read_ack_error();
        begin
            $display("\n================ TEST 3: SHT30 read ACK error ================");

            fork
                begin : NORMAL_PATH
                    start_pulse();

                    @(posedge clk);
                    check(dut.state == dut.S_SEND_CMD, "entered S_SEND_CMD before read error");
                    check_send_cmd_req();

                    // command write success
                    fake_i2c_ok(48'h0);

                    @(posedge clk);
                    check(dut.state == dut.S_WAIT_MEAS, "entered S_WAIT_MEAS before read error");

                    // fast-forward measurement wait
                    force dut.meas_wait_cnt = dut.MEAS_WAIT_CYCLES;
                    @(posedge clk);
                    release dut.meas_wait_cnt;

                    @(posedge clk);
                    check(dut.state == dut.S_READ_DATA, "entered S_READ_DATA before read ack error");
                    check_read_data_req();

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
                    repeat (1200) @(posedge clk);
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
        test_sht30_normal();

        apply_reset();
        test_sht30_cmd_ack_error();

        apply_reset();
        test_sht30_read_ack_error();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #100;
        $finish;
    end

endmodule