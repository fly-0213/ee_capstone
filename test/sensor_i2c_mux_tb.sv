`timescale 1ns/1ps
`include "packet_defs.svh"

module sensor_i2c_mux_tb;
    logic clk;
    logic reset;

    logic [$clog2(SENS_NUM)-1:0] sens_id;

    logic sda_in;
    logic sda_oe;
    logic sda_out_low;
    logic scl;

    // ADS request side
    logic        ads_i2c_start;
    logic        ads_i2c_rw;
    logic [6:0]  ads_i2c_dev_addr;
    logic [7:0]  ads_i2c_reg_addr;
    logic [1:0]  ads_i2c_num_bytes;
    logic [15:0] ads_i2c_wdata;

    logic        ads_i2c_busy;
    logic        ads_i2c_done;
    logic [15:0] ads_i2c_rdata;
    logic        ads_i2c_ack_error;

    // SHT request side
    logic        sht_i2c_start;
    logic        sht_i2c_rw;
    logic [6:0]  sht_i2c_dev_addr;
    logic [2:0]  sht_i2c_num_bytes;
    logic [15:0] sht_i2c_wdata;

    logic        sht_i2c_busy;
    logic        sht_i2c_done;
    logic [47:0] sht_i2c_rdata;
    logic        sht_i2c_ack_error;

    // MPL request side
    logic        mpl_i2c_start;
    logic        mpl_i2c_rw;
    logic [6:0]  mpl_i2c_dev_addr;
    logic [7:0]  mpl_i2c_reg_addr;
    logic [2:0]  mpl_i2c_num_bytes;
    logic [7:0]  mpl_i2c_wdata;

    logic        mpl_i2c_busy;
    logic        mpl_i2c_done;
    logic [39:0] mpl_i2c_rdata;
    logic        mpl_i2c_ack_error;

    int test_pass;
    int test_fail;

    sensor_i2c_mux dut (
        .clk(clk),
        .reset(reset),
        .sens_id(sens_id),

        .sda_in(sda_in),
        .sda_oe(sda_oe),
        .sda_out_low(sda_out_low),
        .scl(scl),

        .ads_i2c_start(ads_i2c_start),
        .ads_i2c_rw(ads_i2c_rw),
        .ads_i2c_dev_addr(ads_i2c_dev_addr),
        .ads_i2c_reg_addr(ads_i2c_reg_addr),
        .ads_i2c_num_bytes(ads_i2c_num_bytes),
        .ads_i2c_wdata(ads_i2c_wdata),

        .ads_i2c_busy(ads_i2c_busy),
        .ads_i2c_done(ads_i2c_done),
        .ads_i2c_rdata(ads_i2c_rdata),
        .ads_i2c_ack_error(ads_i2c_ack_error),

        .sht_i2c_busy(sht_i2c_busy),
        .sht_i2c_done(sht_i2c_done),
        .sht_i2c_rdata(sht_i2c_rdata),
        .sht_i2c_ack_error(sht_i2c_ack_error),

        .sht_i2c_start(sht_i2c_start),
        .sht_i2c_rw(sht_i2c_rw),
        .sht_i2c_dev_addr(sht_i2c_dev_addr),
        .sht_i2c_num_bytes(sht_i2c_num_bytes),
        .sht_i2c_wdata(sht_i2c_wdata),

        .mpl_i2c_busy(mpl_i2c_busy),
        .mpl_i2c_done(mpl_i2c_done),
        .mpl_i2c_rdata(mpl_i2c_rdata),
        .mpl_i2c_ack_error(mpl_i2c_ack_error),

        .mpl_i2c_start(mpl_i2c_start),
        .mpl_i2c_rw(mpl_i2c_rw),
        .mpl_i2c_dev_addr(mpl_i2c_dev_addr),
        .mpl_i2c_reg_addr(mpl_i2c_reg_addr),
        .mpl_i2c_num_bytes(mpl_i2c_num_bytes),
        .mpl_i2c_wdata(mpl_i2c_wdata)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    logic slave_drive_low;
    logic bus_sda;

    always_comb begin
        logic master_drive_low;
        master_drive_low = sda_oe && sda_out_low;
        bus_sda = (master_drive_low || slave_drive_low) ? 1'b0 : 1'b1;
        sda_in  = bus_sda;
    end

    always @(posedge dut.u_i2c_master.tick) begin
        if (reset || dut.u_i2c_master.busy || dut.u_i2c_master.done || dut.u_i2c_master.ack_error) begin
            $display("t=%0t sens_id=%0d mas_state=%0d busy=%0b done=%0b ack_err=%0b sda_oe=%0b sda_in=%0b scl=%0b",
                     $time, sens_id, dut.u_i2c_master.state,
                     dut.u_i2c_master.busy, dut.u_i2c_master.done, dut.u_i2c_master.ack_error,
                     sda_oe, sda_in, scl);
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
        @(posedge dut.u_i2c_master.tick);
    endtask

    task automatic apply_reset();
        begin
            reset            = 1'b1;
            sens_id          = '0;

            ads_i2c_start    = 1'b0;
            ads_i2c_rw       = 1'b0;
            ads_i2c_dev_addr = '0;
            ads_i2c_reg_addr = '0;
            ads_i2c_num_bytes= '0;
            ads_i2c_wdata    = '0;

            sht_i2c_start    = 1'b0;
            sht_i2c_rw       = 1'b0;
            sht_i2c_dev_addr = '0;
            sht_i2c_num_bytes= '0;
            sht_i2c_wdata    = '0;

            mpl_i2c_start    = 1'b0;
            mpl_i2c_rw       = 1'b0;
            mpl_i2c_dev_addr = '0;
            mpl_i2c_reg_addr = '0;
            mpl_i2c_num_bytes= '0;
            mpl_i2c_wdata    = '0;

            slave_drive_low  = 1'b0;

            repeat (5) @(posedge clk);
            reset = 1'b0;
            repeat (2) wait_tick();
        end
    endtask

    task automatic pulse_ads_start();
        begin
            ads_i2c_start = 1'b1;
            wait_tick();
            ads_i2c_start = 1'b0;
        end
    endtask

    task automatic pulse_sht_start();
        begin
            sht_i2c_start = 1'b1;
            wait_tick();
            sht_i2c_start = 1'b0;
        end
    endtask

    task automatic pulse_mpl_start();
        begin
            mpl_i2c_start = 1'b1;
            wait_tick();
            mpl_i2c_start = 1'b0;
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

            if (nack)
                slave_drive_low = 1'b0;   // NACK = release
            else
                slave_drive_low = 1'b1;   // ACK = pull low

            fork
                begin
                    @(posedge scl);
                    saw_ack_posedge = 1;
                end
                begin
                    repeat (5000) @(posedge clk);
                    $display("@@@[FAIL] timeout waiting for ACK posedge scl, time=%0t", $time);
                    test_fail++;
                end
            join_any
            disable fork;

            if (saw_ack_posedge)
                @(negedge scl);

            slave_drive_low = 1'b0;
        end
    endtask

    // ---------------------------------------------------------
    // Slave sends one read byte
    // ---------------------------------------------------------
    task automatic slave_send_byte(
        input [7:0] data_byte,
        output bit master_sent_nack
    );
        int i;
        begin
            slave_drive_low = (data_byte[7] == 1'b0);

            for (i = 7; i > 0; i--) begin
                @(posedge scl);
                @(negedge scl);
                slave_drive_low = (data_byte[i-1] == 1'b0);
            end

            @(posedge scl);
            @(negedge scl);

            // release SDA for master's ACK/NACK
            slave_drive_low = 1'b0;

            @(posedge scl);
            master_sent_nack = (bus_sda == 1'b1);

            @(negedge scl);
            slave_drive_low = 1'b0;
        end
    endtask

    task automatic wait_repeated_start_complete();
        begin
            @(posedge scl);
            @(negedge scl);
        end
    endtask

    // ---------------------------------------------------------
    // TEST 1: ADS route (write with reg addr)
    // ---------------------------------------------------------
    task automatic test_ads_route();
        begin
            $display("\n================ TEST 1: ADS route ================");

            sens_id           = S_ADS1115;
            ads_i2c_rw        = 1'b0;
            ads_i2c_dev_addr  = 7'h48;
            ads_i2c_reg_addr  = 8'h01;
            ads_i2c_num_bytes = 2'd2;
            ads_i2c_wdata     = 16'hC383;

            fork
                begin : NORMAL_PATH
                    fork
                        begin : SLAVE_THREAD
                            wait(ads_i2c_busy === 1'b1);

                            expect_master_byte(8'h90, "ADS ADDR_W");
                            slave_ack(1'b0);

                            expect_master_byte(8'h01, "ADS REG");
                            slave_ack(1'b0);

                            expect_master_byte(8'hC3, "ADS DATA_HI");
                            slave_ack(1'b0);

                            expect_master_byte(8'h83, "ADS DATA_LO");
                            slave_ack(1'b0);
                        end

                        begin : MASTER_THREAD
                            pulse_ads_start();
                            wait(ads_i2c_done === 1'b1);
                            wait_tick();
                        end
                    join
                end

                begin : TIMEOUT_THREAD
                    repeat (250000) @(posedge clk);
                    $display("@@@[FAIL] TEST 1 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;

            check(ads_i2c_ack_error == 1'b0, "ADS ack_error remains 0");
            check(ads_i2c_busy      == 1'b0, "ADS busy deasserted after transaction");

            check(sht_i2c_busy      == 1'b0, "SHT busy not affected during ADS route");
            check(sht_i2c_done      == 1'b0, "SHT done not affected during ADS route");
            check(mpl_i2c_busy      == 1'b0, "MPL busy not affected during ADS route");
            check(mpl_i2c_done      == 1'b0, "MPL done not affected during ADS route");
        end
    endtask

    // ---------------------------------------------------------
    // TEST 2: SHT route (write command, no reg addr)
    // ---------------------------------------------------------
    task automatic test_sht_route();
        begin
            $display("\n================ TEST 2: SHT route ================");

            sens_id           = S_SHT30;
            sht_i2c_rw        = 1'b0;
            sht_i2c_dev_addr  = 7'h44;
            sht_i2c_num_bytes = 3'd2;
            sht_i2c_wdata     = 16'h2400;

            fork
                begin : NORMAL_PATH
                    fork
                        begin : SLAVE_THREAD
                            wait(sht_i2c_busy === 1'b1);

                            // use_reg_addr=0, so only ADDR_W + data bytes
                            expect_master_byte(8'h88, "SHT ADDR_W");
                            slave_ack(1'b0);

                            expect_master_byte(8'h24, "SHT CMD_HI");
                            slave_ack(1'b0);

                            expect_master_byte(8'h00, "SHT CMD_LO");
                            slave_ack(1'b0);
                        end

                        begin : MASTER_THREAD
                            pulse_sht_start();
                            wait(sht_i2c_done === 1'b1);
                            wait_tick();
                        end
                    join
                end

                begin : TIMEOUT_THREAD
                    repeat (250000) @(posedge clk);
                    $display("@@@[FAIL] TEST 2 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;

            check(sht_i2c_ack_error == 1'b0, "SHT ack_error remains 0");
            check(sht_i2c_busy      == 1'b0, "SHT busy deasserted after transaction");

            check(ads_i2c_busy      == 1'b0, "ADS busy not affected during SHT route");
            check(ads_i2c_done      == 1'b0, "ADS done not affected during SHT route");
            check(mpl_i2c_busy      == 1'b0, "MPL busy not affected during SHT route");
            check(mpl_i2c_done      == 1'b0, "MPL done not affected during SHT route");
        end
    endtask

    // ---------------------------------------------------------
    // TEST 3: MPL route (read 5 bytes with reg addr)
    // ---------------------------------------------------------
    task automatic test_mpl_route();
        bit last_nack;
        logic [39:0] exp_data;
        begin
            $display("\n================ TEST 3: MPL route ================");

            exp_data = 40'h12_34_A0_56_70;

            sens_id           = S_MPL3115;
            mpl_i2c_rw        = 1'b1;
            mpl_i2c_dev_addr  = 7'h60;
            mpl_i2c_reg_addr  = 8'h01;
            mpl_i2c_num_bytes = 3'd5;
            mpl_i2c_wdata     = 8'h00;

            fork
                begin : NORMAL_PATH
                    fork
                        begin : SLAVE_THREAD
                            wait(mpl_i2c_busy === 1'b1);

                            // write phase with reg addr
                            expect_master_byte(8'hC0, "MPL ADDR_W");
                            slave_ack(1'b0);

                            expect_master_byte(8'h01, "MPL REG");
                            slave_ack(1'b0);

                            // repeated start
                            wait_repeated_start_complete();

                            // read phase
                            expect_master_byte(8'hC1, "MPL ADDR_R");
                            slave_ack(1'b0);

                            slave_send_byte(8'h12, last_nack);
                            check(last_nack == 1'b0, "master ACK after MPL read byte 0");

                            slave_send_byte(8'h34, last_nack);
                            check(last_nack == 1'b0, "master ACK after MPL read byte 1");

                            slave_send_byte(8'hA0, last_nack);
                            check(last_nack == 1'b0, "master ACK after MPL read byte 2");

                            slave_send_byte(8'h56, last_nack);
                            check(last_nack == 1'b0, "master ACK after MPL read byte 3");

                            slave_send_byte(8'h70, last_nack);
                            check(last_nack == 1'b1, "master NACK after MPL final read byte");
                        end

                        begin : MASTER_THREAD
                            pulse_mpl_start();
                            wait(mpl_i2c_done === 1'b1);
                            wait_tick();
                        end
                    join
                end

                begin : TIMEOUT_THREAD
                    repeat (400000) @(posedge clk);
                    $display("@@@[FAIL] TEST 3 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;

            check(mpl_i2c_ack_error == 1'b0, "MPL ack_error remains 0");
            check(mpl_i2c_busy      == 1'b0, "MPL busy deasserted after transaction");
            check(mpl_i2c_rdata     == exp_data, "MPL 40-bit rdata returned correctly");

            check(ads_i2c_busy      == 1'b0, "ADS busy not affected during MPL route");
            check(ads_i2c_done      == 1'b0, "ADS done not affected during MPL route");
            check(sht_i2c_busy      == 1'b0, "SHT busy not affected during MPL route");
            check(sht_i2c_done      == 1'b0, "SHT done not affected during MPL route");
        end
    endtask

    // ---------------------------------------------------------
    // Main
    // ---------------------------------------------------------
    initial begin
        test_pass = 0;
        test_fail = 0;

        apply_reset();
        test_ads_route();

        apply_reset();
        test_sht_route();

        apply_reset();
        test_mpl_route();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #100;
        $finish;
    end

endmodule