`timescale 1ns/1ps
`include "packet_defs.svh"

module sensor_chain_sht_tb;

    logic clk;
    logic reset;

    logic sht_start;
    logic [$clog2(SENS_NUM)-1:0] sens_id;

    // shared i2c wires
    logic sda_in;
    logic sda_oe;
    logic sda_out_low;
    logic scl;

    logic        sht_i2c_start;
    logic        sht_i2c_rw;
    logic [6:0]  sht_i2c_dev_addr;
    logic [2:0]  sht_i2c_num_bytes;
    logic [15:0] sht_i2c_wdata;

    logic        sht_i2c_busy;
    logic        sht_i2c_done;
    logic [47:0] sht_i2c_rdata;
    logic        sht_i2c_ack_error;

    logic        sht_busy;
    logic        sht_data_valid;
    logic [15:0] sht_temp_raw;
    logic [15:0] sht_hum_raw;
    logic        sht_error;

    logic        ads_i2c_busy;
    logic        ads_i2c_done;
    logic [15:0] ads_i2c_rdata;
    logic        ads_i2c_ack_error;
    logic        ads_i2c_start;
    logic        ads_i2c_rw;
    logic [6:0]  ads_i2c_dev_addr;
    logic [7:0]  ads_i2c_reg_addr;
    logic [1:0]  ads_i2c_num_bytes;
    logic [15:0] ads_i2c_wdata;

    logic        mpl_i2c_busy;
    logic        mpl_i2c_done;
    logic [39:0] mpl_i2c_rdata;
    logic        mpl_i2c_ack_error;
    logic        mpl_i2c_start;
    logic        mpl_i2c_rw;
    logic [6:0]  mpl_i2c_dev_addr;
    logic [7:0]  mpl_i2c_reg_addr;
    logic [2:0]  mpl_i2c_num_bytes;
    logic [7:0]  mpl_i2c_wdata;

    logic        result_valid;
    logic [$clog2(SENS_NUM)-1:0] result_sensor_id;
    logic [DATA_W-1:0] result_data;
    logic        result_error;

    logic slave_drive_low;
    logic bus_sda;

    int test_pass;
    int test_fail;

    // concise trace
    logic [3:0] prev_sht_state;
    logic [3:0] prev_mas_state;
    logic       prev_sht_i2c_busy;
    logic       prev_sht_i2c_done;
    logic       prev_sht_valid;
    logic       prev_sht_error;
    logic       prev_result_valid;
    logic       prev_result_error;

    sht30_ctrl u_sht (
        .clk          (clk),
        .reset        (reset),
        .start        (sht_start),

        .i2c_busy     (sht_i2c_busy),
        .i2c_done     (sht_i2c_done),
        .i2c_rdata    (sht_i2c_rdata),
        .i2c_ack_error(sht_i2c_ack_error),

        .i2c_start    (sht_i2c_start),
        .i2c_rw       (sht_i2c_rw),
        .i2c_dev_addr (sht_i2c_dev_addr),
        .i2c_wdata    (sht_i2c_wdata),
        .i2c_num_bytes(sht_i2c_num_bytes),

        .busy         (sht_busy),
        .data_valid   (sht_data_valid),
        .temp_raw     (sht_temp_raw),
        .hum_raw      (sht_hum_raw),
        .error        (sht_error)
    );

    sensor_i2c_mux u_mux (
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

    sensor_result_mux u_result_mux (
        .sens_id(sens_id),

        .ads_data_valid(1'b0),
        .ads_error(1'b0),
        .ads_data_out(16'h0000),

        .sht_data_valid(sht_data_valid),
        .sht_error(sht_error),
        .sht_temp_raw(sht_temp_raw),
        .sht_hum_raw(sht_hum_raw),

        .mpl_data_valid(1'b0),
        .mpl_error(1'b0),
        .mpl_temp_raw(20'h00000),
        .mpl_pressure_raw(12'h000),

        .result_valid(result_valid),
        .result_sensor_id(result_sensor_id),
        .result_data(result_data),
        .result_error(result_error)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    always_comb begin
        logic master_drive_low;
        master_drive_low = sda_oe && sda_out_low;
        bus_sda = (master_drive_low || slave_drive_low) ? 1'b0 : 1'b1;
        sda_in  = bus_sda;
    end

    always @(posedge clk) begin
        if (reset) begin
            prev_sht_state    <= u_sht.state;
            prev_mas_state    <= u_mux.u_i2c_master.state;
            prev_sht_i2c_busy <= sht_i2c_busy;
            prev_sht_i2c_done <= sht_i2c_done;
            prev_sht_valid    <= sht_data_valid;
            prev_sht_error    <= sht_error;
            prev_result_valid <= result_valid;
            prev_result_error <= result_error;
        end else begin
            if (u_sht.state != prev_sht_state ||
                u_mux.u_i2c_master.state != prev_mas_state ||
                sht_i2c_busy != prev_sht_i2c_busy ||
                sht_i2c_done != prev_sht_i2c_done ||
                sht_data_valid != prev_sht_valid ||
                sht_error != prev_sht_error ||
                result_valid != prev_result_valid ||
                result_error != prev_result_error) begin
                $display("@@@[TRACE] t=%0t sht_state=%0d mas_state=%0d sht_i2c_busy=%0b sht_i2c_done=%0b sht_valid=%0b sht_error=%0b result_valid=%0b result_error=%0b",
                         $time, u_sht.state, u_mux.u_i2c_master.state,
                         sht_i2c_busy, sht_i2c_done, sht_data_valid, sht_error,
                         result_valid, result_error);
            end

            prev_sht_state    <= u_sht.state;
            prev_mas_state    <= u_mux.u_i2c_master.state;
            prev_sht_i2c_busy <= sht_i2c_busy;
            prev_sht_i2c_done <= sht_i2c_done;
            prev_sht_valid    <= sht_data_valid;
            prev_sht_error    <= sht_error;
            prev_result_valid <= result_valid;
            prev_result_error <= result_error;
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
            reset           = 1'b1;
            sht_start       = 1'b0;
            sens_id         = S_SHT30;
            slave_drive_low = 1'b0;

            ads_i2c_start     = 1'b0;
            ads_i2c_rw        = 1'b0;
            ads_i2c_dev_addr  = '0;
            ads_i2c_reg_addr  = '0;
            ads_i2c_num_bytes = '0;
            ads_i2c_wdata     = '0;

            mpl_i2c_start     = 1'b0;
            mpl_i2c_rw        = 1'b0;
            mpl_i2c_dev_addr  = '0;
            mpl_i2c_reg_addr  = '0;
            mpl_i2c_num_bytes = '0;
            mpl_i2c_wdata     = '0;

            repeat (5) @(posedge clk);
            reset = 1'b0;
            repeat (10) @(posedge clk);
        end
    endtask

    task automatic pulse_sht_start();
        begin
            $display("@@@[TB] pulse_sht_start at t=%0t", $time);
            sht_start = 1'b1;
            @(posedge clk);
            sht_start = 1'b0;
        end
    endtask

    task automatic wait_ack_phase_and_drive(input bit nack);
        begin
            wait(u_mux.u_i2c_master.state == u_mux.u_i2c_master.S_GET_ACK &&
                 u_mux.u_i2c_master.subphase == u_mux.u_i2c_master.SUB_0);

            if (nack)
                slave_drive_low = 1'b0;
            else
                slave_drive_low = 1'b1;

            @(posedge scl);
            @(negedge scl);

            slave_drive_low = 1'b0;
        end
    endtask

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

            slave_drive_low = 1'b0;

            @(posedge scl);
            master_sent_nack = (bus_sda == 1'b1);

            @(negedge scl);
            slave_drive_low = 1'b0;
        end
    endtask

    task automatic wait_read_start();
        begin
            wait(u_mux.u_i2c_master.state == u_mux.u_i2c_master.S_READ_BYTE);
        end
    endtask

    // =========================================================
    // TEST 1: normal SHT chain
    // =========================================================
    task automatic test_sht_chain_normal();
        bit last_nack;
        logic [DATA_W-1:0] exp_result;
        begin
            $display("\n================ TEST 1: SHT chain normal ================");
            exp_result = {{(DATA_W-32){1'b0}}, 16'h6677, 16'h8899};

            fork
                begin : NORMAL_PATH
                    fork
                        begin : SLAVE_THREAD
                            // first transaction: SEND_CMD = 2 bytes -> 3 ACKs total
                            wait(sht_i2c_busy == 1'b1);
                            wait_ack_phase_and_drive(1'b0); // ADDR_W ack
                            wait_ack_phase_and_drive(1'b0); // CMD[15:8] ack
                            wait_ack_phase_and_drive(1'b0); // CMD[7:0] ack

                            wait(u_sht.state == u_sht.S_WAIT_MEAS);
                            $display("@@@[MILESTONE] SHT entered S_WAIT_MEAS at t=%0t", $time);

                            // fast-forward measurement wait
                            force u_sht.meas_wait_cnt = u_sht.MEAS_WAIT_CYCLES;
                            @(posedge clk);
                            release u_sht.meas_wait_cnt;

                            // second transaction: pure read of 6 bytes
                            // one ACK first for ADDR_R
                            wait_ack_phase_and_drive(1'b0); // ADDR_R ack

                            wait_read_start();

                            // 6 bytes total:
                            // temp_msb temp_lsb temp_crc rh_msb rh_lsb rh_crc
                            slave_send_byte(8'h66, last_nack);
                            check(last_nack == 1'b0, "master ACK after SHT read byte0");

                            slave_send_byte(8'h77, last_nack);
                            check(last_nack == 1'b0, "master ACK after SHT read byte1");

                            slave_send_byte(8'hAA, last_nack);
                            check(last_nack == 1'b0, "master ACK after SHT read byte2");

                            slave_send_byte(8'h88, last_nack);
                            check(last_nack == 1'b0, "master ACK after SHT read byte3");

                            slave_send_byte(8'h99, last_nack);
                            check(last_nack == 1'b0, "master ACK after SHT read byte4");

                            slave_send_byte(8'hBB, last_nack);
                            check(last_nack == 1'b1, "master NACK after SHT final read byte");
                        end

                        begin : CHECK_THREAD
                            pulse_sht_start();

                            wait(sht_i2c_busy == 1'b1);
                            $display("@@@[MILESTONE] SHT i2c_busy asserted at t=%0t", $time);

                            wait(sht_data_valid == 1'b1);
                            $display("@@@[MILESTONE] SHT data_valid asserted at t=%0t", $time);

                            check(sht_error == 1'b0, "SHT controller error remains 0");
                            check(sht_temp_raw == 16'h6677, "SHT temp_raw correct");
                            check(sht_hum_raw  == 16'h8899, "SHT hum_raw correct");

                            check(result_valid == 1'b1, "result_valid asserted");
                            check(result_sensor_id == S_SHT30, "result_sensor_id correct");
                            check(result_error == 1'b0, "result_error remains 0");
                            check(result_data == exp_result, "result_data correct for SHT chain");
                        end
                    join
                end

                begin : TIMEOUT_THREAD
                    repeat (500000) @(posedge clk);
                    $display("@@@[FAIL] TEST 1 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;
        end
    endtask

    // =========================================================
    // TEST 2: command write NACK -> error path
    // =========================================================
    task automatic test_sht_chain_cmd_nack();
        begin
            $display("\n================ TEST 2: SHT chain cmd NACK ================");

            fork
                begin : NORMAL_PATH
                    fork
                        begin : SLAVE_THREAD
                            wait(sht_i2c_busy == 1'b1);
                            wait_ack_phase_and_drive(1'b1); // NACK on first ACK slot
                        end

                        begin : CHECK_THREAD
                            pulse_sht_start();

                            wait(sht_i2c_busy == 1'b1);
                            $display("@@@[MILESTONE] SHT i2c_busy asserted on cmd-NACK test at t=%0t", $time);

                            wait(sht_error == 1'b1);
                            $display("@@@[MILESTONE] SHT error asserted after cmd-NACK at t=%0t", $time);

                            check(sht_error == 1'b1, "SHT controller error asserted after NACK");
                            #1;
                            check(result_error == 1'b1, "result_error asserted after NACK");
                            check(result_sensor_id == S_SHT30, "result_sensor_id remains SHT on error");
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
        end
    endtask

    // =========================================================
    // Main
    // =========================================================
    initial begin
        test_pass = 0;
        test_fail = 0;

        apply_reset();
        test_sht_chain_normal();

        apply_reset();
        test_sht_chain_cmd_nack();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #100;
        $finish;
    end

endmodule
