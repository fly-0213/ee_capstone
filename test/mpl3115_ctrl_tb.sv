`timescale 1ns/1ps

module mpl3115_ctrl_tb;
    logic        clk;
    logic        reset;
    logic        start;

    // fake i2c return side
    logic        i2c_busy;
    logic        i2c_done;
    logic [39:0] i2c_rdata;
    logic        i2c_ack_error;

    // controller request side
    logic        i2c_start;
    logic        i2c_rw;
    logic [6:0]  i2c_dev_addr;
    logic [7:0]  i2c_reg_addr;
    logic [2:0]  i2c_num_bytes;
    logic [7:0]  i2c_wdata;

    // controller outputs
    logic        busy;
    logic        data_valid;
    logic [19:0] pressure_raw;
    logic [11:0] temp_raw;
    logic        error;

    int test_pass;
    int test_fail;

    mpl3115_ctrl dut (
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
        .pressure_raw (pressure_raw),
        .temp_raw     (temp_raw),
        .error        (error)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset || start || i2c_start || i2c_done || i2c_ack_error || busy || data_valid || error) begin
            $display("t=%0t reset=%0b start=%0b", $time, reset, start);
            $display("    state=%0d busy=%0b i2c_start=%0b i2c_rw=%0b dev=0x%02h reg=0x%02h num_bytes=%0d wdata=0x%02h | i2c_done=%0b ack_err=%0b rdata=0x%010h | data_valid=%0b pressure_raw=0x%05h temp_raw=0x%03h error=%0b status=0x%02h",
                     dut.state, busy, i2c_start, i2c_rw, i2c_dev_addr, i2c_reg_addr,
                     i2c_num_bytes, i2c_wdata, i2c_done, i2c_ack_error, i2c_rdata,
                     data_valid, pressure_raw, temp_raw, error, dut.status_reg);
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
            i2c_rdata     = 40'h0;
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

    task automatic fake_i2c_ok(input [39:0] ret_data);
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
            i2c_rdata     = 40'h0;

            repeat (3) @(posedge clk);

            i2c_busy      = 1'b0;
            i2c_ack_error = 1'b1;
            i2c_done      = 1'b1;
            @(posedge clk);

            i2c_done      = 1'b0;
            i2c_ack_error = 1'b0;
        end
    endtask

    task automatic check_write_ctrl1_cfg_req();
        begin
            check(i2c_start     == 1'b1,   "WRITE_CTRL1_CFG asserted i2c_start");
            check(i2c_rw        == 1'b0,   "WRITE_CTRL1_CFG rw = write");
            check(i2c_dev_addr  == 7'h60,  "WRITE_CTRL1_CFG dev addr = 0x60");
            check(i2c_reg_addr  == 8'h26,  "WRITE_CTRL1_CFG reg addr = CTRL_REG1");
            check(i2c_num_bytes == 3'd1,   "WRITE_CTRL1_CFG num_bytes = 1");
            check(i2c_wdata     == 8'h28,  "WRITE_CTRL1_CFG wdata = 0x28");
        end
    endtask

    task automatic check_write_pt_data_cfg_req();
        begin
            check(i2c_start     == 1'b1,   "WRITE_PT_DATA_CFG asserted i2c_start");
            check(i2c_rw        == 1'b0,   "WRITE_PT_DATA_CFG rw = write");
            check(i2c_dev_addr  == 7'h60,  "WRITE_PT_DATA_CFG dev addr = 0x60");
            check(i2c_reg_addr  == 8'h13,  "WRITE_PT_DATA_CFG reg addr = PT_DATA_CFG");
            check(i2c_num_bytes == 3'd1,   "WRITE_PT_DATA_CFG num_bytes = 1");
            check(i2c_wdata     == 8'h07,  "WRITE_PT_DATA_CFG wdata = 0x07");
        end
    endtask

    task automatic check_write_ctrl1_ost_req();
        begin
            check(i2c_start     == 1'b1,   "WRITE_CTRL1_OST asserted i2c_start");
            check(i2c_rw        == 1'b0,   "WRITE_CTRL1_OST rw = write");
            check(i2c_dev_addr  == 7'h60,  "WRITE_CTRL1_OST dev addr = 0x60");
            check(i2c_reg_addr  == 8'h26,  "WRITE_CTRL1_OST reg addr = CTRL_REG1");
            check(i2c_num_bytes == 3'd1,   "WRITE_CTRL1_OST num_bytes = 1");
            check(i2c_wdata     == 8'h2B,  "WRITE_CTRL1_OST wdata = 0x2B");
        end
    endtask

    task automatic check_read_status_req();
        begin
            check(i2c_start     == 1'b1,   "READ_STATUS asserted i2c_start");
            check(i2c_rw        == 1'b1,   "READ_STATUS rw = read");
            check(i2c_dev_addr  == 7'h60,  "READ_STATUS dev addr = 0x60");
            check(i2c_reg_addr  == 8'h00,  "READ_STATUS reg addr = STATUS");
            check(i2c_num_bytes == 3'd1,   "READ_STATUS num_bytes = 1");
        end
    endtask

    task automatic check_read_data_req();
        begin
            check(i2c_start     == 1'b1,   "READ_DATA asserted i2c_start");
            check(i2c_rw        == 1'b1,   "READ_DATA rw = read");
            check(i2c_dev_addr  == 7'h60,  "READ_DATA dev addr = 0x60");
            check(i2c_reg_addr  == 8'h01,  "READ_DATA reg addr = OUT_P_MSB");
            check(i2c_num_bytes == 3'd5,   "READ_DATA num_bytes = 5");
        end
    endtask

    // ---------------------------------------------------------
    // TEST 1: normal flow with one not-ready status poll then ready
    // ---------------------------------------------------------
    task automatic test_mpl3115_normal();
        begin
            $display("\n================ TEST 1: MPL3115 normal flow ================");

            // example 5-byte return frame:
            // [39:32] P_MSB = 0x12
            // [31:24] P_CSB = 0x34
            // [23:16] P_LSB = 0xA0
            // [15:8]  T_MSB = 0x56
            // [7:0]   T_LSB = 0x70
            //
            // expected:
            // pressure_raw = {0x12,0x34,0xA} = 20'h1234A
            // temp_raw     = {0x56,0x7}      = 12'h567

            fork
                begin : NORMAL_PATH
                    start_pulse();

                    @(posedge clk);
                    check(dut.state == dut.S_WRITE_CTRL1_CFG, "entered S_WRITE_CTRL1_CFG after start");
                    check_write_ctrl1_cfg_req();

                    fake_i2c_ok(40'h0);

                    @(posedge clk);
                    check(dut.state == dut.S_WRITE_PT_DATA_CFG, "entered S_WRITE_PT_DATA_CFG after ctrl1 cfg");
                    check_write_pt_data_cfg_req();

                    fake_i2c_ok(40'h0);

                    @(posedge clk);
                    check(dut.state == dut.S_WRITE_CTRL1_OST, "entered S_WRITE_CTRL1_OST after pt_data_cfg");
                    check_write_ctrl1_ost_req();

                    fake_i2c_ok(40'h0);

                    @(posedge clk);
                    check(dut.state == dut.S_READ_STATUS, "entered S_READ_STATUS after OST write");
                    check_read_status_req();

                    // first status poll: not ready
                    fake_i2c_ok(40'h0000000000);   // status = 0x00

                    @(posedge clk);
                    check(dut.state == dut.S_CHECK_STATUS, "entered S_CHECK_STATUS after first status read");

                    @(posedge clk);
                    check(dut.state == dut.S_READ_STATUS, "looped back to S_READ_STATUS when PTDR=0");
                    check_read_status_req();

                    // second status poll: ready
                    fake_i2c_ok(40'h0000000008);   // status = 0x08, PTDR=1

                    @(posedge clk);
                    check(dut.state == dut.S_CHECK_STATUS, "entered S_CHECK_STATUS after second status read");

                    @(posedge clk);
                    check(dut.state == dut.S_READ_DATA, "entered S_READ_DATA when PTDR=1");
                    check_read_data_req();

                    // read 5-byte data success
                    fake_i2c_ok(40'h12_34_A0_56_70);

                    @(posedge clk);
                    check(dut.state == dut.S_PARSE, "entered S_PARSE after successful data read");

                    @(posedge clk);
                    check(dut.state == dut.S_DONE, "entered S_DONE after parse");
                    check(data_valid    == 1'b1,      "data_valid asserted in S_DONE");
                    check(pressure_raw  == 20'h1234A, "pressure_raw parsed correctly");
                    check(temp_raw      == 12'h567,   "temp_raw parsed correctly");
                    check(error         == 1'b0,      "error remains 0 in normal flow");

                    @(posedge clk);
                    check(dut.state == dut.S_IDLE, "returned to S_IDLE after S_DONE");
                    check(busy      == 1'b0, "busy deasserted in S_IDLE");
                end

                begin : TIMEOUT_THREAD
                    repeat (2000) @(posedge clk);
                    $display("@@@[FAIL] TEST 1 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;
        end
    endtask

    // ---------------------------------------------------------
    // TEST 2: first write ACK error
    // ---------------------------------------------------------
    task automatic test_mpl3115_first_write_ack_error();
        begin
            $display("\n================ TEST 2: MPL3115 first write ACK error ================");

            fork
                begin : NORMAL_PATH
                    start_pulse();

                    @(posedge clk);
                    check(dut.state == dut.S_WRITE_CTRL1_CFG, "entered S_WRITE_CTRL1_CFG before first write error");
                    check_write_ctrl1_cfg_req();

                    fake_i2c_ack_error();

                    @(posedge clk);
                    check(dut.state == dut.S_ERROR, "entered S_ERROR after first write ack error");
                    check(error == 1'b1, "error asserted in S_ERROR after first write ack error");

                    @(posedge clk);
                    check(dut.state == dut.S_IDLE, "returned to S_IDLE after first write error and start low");
                    check(busy == 1'b0, "busy deasserted after first write error recovery");
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
    task automatic test_mpl3115_read_data_ack_error();
        begin
            $display("\n================ TEST 3: MPL3115 read data ACK error ================");

            fork
                begin : NORMAL_PATH
                    start_pulse();

                    @(posedge clk);
                    check(dut.state == dut.S_WRITE_CTRL1_CFG, "entered S_WRITE_CTRL1_CFG before read-data error");
                    check_write_ctrl1_cfg_req();
                    fake_i2c_ok(40'h0);

                    @(posedge clk);
                    check(dut.state == dut.S_WRITE_PT_DATA_CFG, "entered S_WRITE_PT_DATA_CFG before read-data error");
                    check_write_pt_data_cfg_req();
                    fake_i2c_ok(40'h0);

                    @(posedge clk);
                    check(dut.state == dut.S_WRITE_CTRL1_OST, "entered S_WRITE_CTRL1_OST before read-data error");
                    check_write_ctrl1_ost_req();
                    fake_i2c_ok(40'h0);

                    @(posedge clk);
                    check(dut.state == dut.S_READ_STATUS, "entered S_READ_STATUS before read-data error");
                    check_read_status_req();

                    // status says ready immediately
                    fake_i2c_ok(40'h0000000008);

                    @(posedge clk);
                    check(dut.state == dut.S_CHECK_STATUS, "entered S_CHECK_STATUS before read-data error");

                    @(posedge clk);
                    check(dut.state == dut.S_READ_DATA, "entered S_READ_DATA before read-data ack error");
                    check_read_data_req();

                    fake_i2c_ack_error();

                    @(posedge clk);
                    check(dut.state == dut.S_ERROR, "entered S_ERROR after read-data ack error");
                    check(error == 1'b1, "error asserted after read-data ack error");

                    @(posedge clk);
                    check(dut.state == dut.S_IDLE, "returned to S_IDLE after read-data error and start low");
                    check(busy == 1'b0, "busy deasserted after read-data error recovery");
                end

                begin : TIMEOUT_THREAD
                    repeat (2000) @(posedge clk);
                    $display("@@@[FAIL] TEST 3 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;
        end
    endtask

    // ---------------------------------------------------------
    // TEST 4: status polling loop works
    // ---------------------------------------------------------
    task automatic test_mpl3115_status_poll_loop();
        begin
            $display("\n================ TEST 4: MPL3115 status polling loop ================");

            fork
                begin : NORMAL_PATH
                    start_pulse();

                    @(posedge clk);
                    check(dut.state == dut.S_WRITE_CTRL1_CFG, "entered S_WRITE_CTRL1_CFG before status-loop test");
                    fake_i2c_ok(40'h0);

                    @(posedge clk);
                    check(dut.state == dut.S_WRITE_PT_DATA_CFG, "entered S_WRITE_PT_DATA_CFG before status-loop test");
                    fake_i2c_ok(40'h0);

                    @(posedge clk);
                    check(dut.state == dut.S_WRITE_CTRL1_OST, "entered S_WRITE_CTRL1_OST before status-loop test");
                    fake_i2c_ok(40'h0);

                    @(posedge clk);
                    check(dut.state == dut.S_READ_STATUS, "entered first S_READ_STATUS in status-loop test");
                    check_read_status_req();

                    // first not ready
                    fake_i2c_ok(40'h0000000000);

                    @(posedge clk);
                    check(dut.state == dut.S_CHECK_STATUS, "entered S_CHECK_STATUS after first status poll");

                    @(posedge clk);
                    check(dut.state == dut.S_READ_STATUS, "returned to S_READ_STATUS after PTDR=0");

                    // second not ready
                    fake_i2c_ok(40'h0000000000);

                    @(posedge clk);
                    check(dut.state == dut.S_CHECK_STATUS, "entered S_CHECK_STATUS after second status poll");

                    @(posedge clk);
                    check(dut.state == dut.S_READ_STATUS, "returned again to S_READ_STATUS after second PTDR=0");

                    // third ready
                    fake_i2c_ok(40'h0000000008);

                    @(posedge clk);
                    check(dut.state == dut.S_CHECK_STATUS, "entered S_CHECK_STATUS after third status poll");

                    @(posedge clk);
                    check(dut.state == dut.S_READ_DATA, "moved to S_READ_DATA when PTDR finally became 1");
                end

                begin : TIMEOUT_THREAD
                    repeat (2000) @(posedge clk);
                    $display("@@@[FAIL] TEST 4 TIMEOUT");
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
        test_mpl3115_normal();

        apply_reset();
        test_mpl3115_first_write_ack_error();

        apply_reset();
        test_mpl3115_read_data_ack_error();

        apply_reset();
        test_mpl3115_status_poll_loop();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #100;
        $finish;
    end

endmodule