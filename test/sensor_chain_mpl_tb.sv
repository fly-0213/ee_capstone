`timescale 1ns/1ps
`include "packet_defs.svh"

module sensor_chain_mpl_tb;

    logic clk;
    logic reset;

    logic mpl_start;
    logic [$clog2(SENS_NUM)-1:0] sens_id;

    // shared i2c wires
    logic sda_in;
    logic sda_oe;
    logic sda_out_low;
    logic scl;

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

    logic        mpl_busy;
    logic        mpl_data_valid;
    logic [19:0] mpl_pressure_raw;
    logic [11:0] mpl_temp_raw;
    logic        mpl_error;

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

    logic        sht_i2c_busy;
    logic        sht_i2c_done;
    logic [47:0] sht_i2c_rdata;
    logic        sht_i2c_ack_error;
    logic        sht_i2c_start;
    logic        sht_i2c_rw;
    logic [6:0]  sht_i2c_dev_addr;
    logic [2:0]  sht_i2c_num_bytes;
    logic [15:0] sht_i2c_wdata;

    logic        result_valid;
    logic [$clog2(SENS_NUM)-1:0] result_sensor_id;
    logic [DATA_W-1:0] result_data;
    logic        result_error;

    logic slave_drive_low;
    logic bus_sda;

    int test_pass;
    int test_fail;

    logic [3:0] prev_mpl_state;
    logic [3:0] prev_mas_state;
    logic       prev_mpl_i2c_busy;
    logic       prev_mpl_i2c_done;
    logic       prev_mpl_valid;
    logic       prev_mpl_error;
    logic       prev_result_valid;
    logic       prev_result_error;

    mpl3115_ctrl u_mpl (
        .clk          (clk),
        .reset        (reset),
        .start        (mpl_start),

        .i2c_busy     (mpl_i2c_busy),
        .i2c_done     (mpl_i2c_done),
        .i2c_rdata    (mpl_i2c_rdata),
        .i2c_ack_error(mpl_i2c_ack_error),

        .i2c_start    (mpl_i2c_start),
        .i2c_rw       (mpl_i2c_rw),
        .i2c_dev_addr (mpl_i2c_dev_addr),
        .i2c_reg_addr (mpl_i2c_reg_addr),
        .i2c_num_bytes(mpl_i2c_num_bytes),
        .i2c_wdata    (mpl_i2c_wdata),

        .busy         (mpl_busy),
        .data_valid   (mpl_data_valid),
        .pressure_raw (mpl_pressure_raw),
        .temp_raw     (mpl_temp_raw),
        .error        (mpl_error)
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

        .sht_data_valid(1'b0),
        .sht_error(1'b0),
        .sht_temp_raw(16'h0000),
        .sht_hum_raw(16'h0000),

        .mpl_data_valid(mpl_data_valid),
        .mpl_error(mpl_error),
        .mpl_pressure_raw(mpl_pressure_raw),
        .mpl_temp_raw(mpl_temp_raw),

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
            prev_mpl_state    <= u_mpl.state;
            prev_mas_state    <= u_mux.u_i2c_master.state;
            prev_mpl_i2c_busy <= mpl_i2c_busy;
            prev_mpl_i2c_done <= mpl_i2c_done;
            prev_mpl_valid    <= mpl_data_valid;
            prev_mpl_error    <= mpl_error;
            prev_result_valid <= result_valid;
            prev_result_error <= result_error;
        end else begin
            if (u_mpl.state != prev_mpl_state ||
                u_mux.u_i2c_master.state != prev_mas_state ||
                mpl_i2c_busy != prev_mpl_i2c_busy ||
                mpl_i2c_done != prev_mpl_i2c_done ||
                mpl_data_valid != prev_mpl_valid ||
                mpl_error != prev_mpl_error ||
                result_valid != prev_result_valid ||
                result_error != prev_result_error) begin
                $display("@@@[TRACE] t=%0t mpl_state=%0d mas_state=%0d mpl_i2c_busy=%0b mpl_i2c_done=%0b mpl_valid=%0b mpl_error=%0b result_valid=%0b result_error=%0b",
                         $time, u_mpl.state, u_mux.u_i2c_master.state,
                         mpl_i2c_busy, mpl_i2c_done, mpl_data_valid, mpl_error,
                         result_valid, result_error);
            end

            prev_mpl_state    <= u_mpl.state;
            prev_mas_state    <= u_mux.u_i2c_master.state;
            prev_mpl_i2c_busy <= mpl_i2c_busy;
            prev_mpl_i2c_done <= mpl_i2c_done;
            prev_mpl_valid    <= mpl_data_valid;
            prev_mpl_error    <= mpl_error;
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
            mpl_start       = 1'b0;
            sens_id         = S_MPL3115;
            slave_drive_low = 1'b0;

            ads_i2c_start     = 1'b0;
            ads_i2c_rw        = 1'b0;
            ads_i2c_dev_addr  = '0;
            ads_i2c_reg_addr  = '0;
            ads_i2c_num_bytes = '0;
            ads_i2c_wdata     = '0;

            sht_i2c_start     = 1'b0;
            sht_i2c_rw        = 1'b0;
            sht_i2c_dev_addr  = '0;
            sht_i2c_num_bytes = '0;
            sht_i2c_wdata     = '0;

            repeat (5) @(posedge clk);
            reset = 1'b0;
            repeat (10) @(posedge clk);
        end
    endtask

    task automatic pulse_mpl_start();
        begin
            $display("@@@[TB] pulse_mpl_start at t=%0t", $time);
            mpl_start = 1'b1;
            @(posedge clk);
            mpl_start = 1'b0;
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
    // TEST 1: normal MPL chain
    // =========================================================
    task automatic test_mpl_chain_normal();
        bit last_nack;
        logic [19:0] exp_pressure;
        logic [11:0] exp_temp;
        logic [DATA_W-1:0] exp_result;
        begin
            $display("\n================ TEST 1: MPL chain normal ================");

            // 5 bytes read back:
            // P_MSB=12, P_CSB=34, P_LSB=50, T_MSB=67, T_LSB=80
            // pressure_raw = {12,34,5} = 20'h12345
            // temp_raw     = {67,8}    = 12'h678
            exp_pressure = 20'h12345;
            exp_temp     = 12'h678;
            exp_result = {{(DATA_W-32){1'b0}}, exp_pressure, exp_temp};

            fork
                begin : NORMAL_PATH
                    fork
                        begin : SLAVE_THREAD
                            wait(mpl_i2c_busy == 1'b1);

                            // write CTRL1_CFG
                            wait_ack_phase_and_drive(1'b0); // ADDR_W
                            wait_ack_phase_and_drive(1'b0); // REG_CTRL_REG1
                            wait_ack_phase_and_drive(1'b0); // 0x28

                            // write PT_DATA_CFG
                            wait_ack_phase_and_drive(1'b0); // ADDR_W
                            wait_ack_phase_and_drive(1'b0); // REG_PT_DATA_CFG
                            wait_ack_phase_and_drive(1'b0); // 0x07

                            // write CTRL1_OST
                            wait_ack_phase_and_drive(1'b0); // ADDR_W
                            wait_ack_phase_and_drive(1'b0); // REG_CTRL_REG1
                            wait_ack_phase_and_drive(1'b0); // 0x2B

                            // read STATUS transaction:
                            // ADDR_W, REG_STATUS, repeated start, ADDR_R, 1 byte status
                            wait_ack_phase_and_drive(1'b0); // ADDR_W
                            wait_ack_phase_and_drive(1'b0); // REG_STATUS
                            wait_ack_phase_and_drive(1'b0); // ADDR_R

                            wait_read_start();
                            slave_send_byte(8'h08, last_nack); // PTDR=1
                            check(last_nack == 1'b1, "master NACK after MPL STATUS byte");

                            // read DATA transaction:
                            // ADDR_W, REG_OUT_P_MSB, repeated start, ADDR_R, 5 bytes
                            wait_ack_phase_and_drive(1'b0); // ADDR_W
                            wait_ack_phase_and_drive(1'b0); // REG_OUT_P_MSB
                            wait_ack_phase_and_drive(1'b0); // ADDR_R

                            wait_read_start();

                            slave_send_byte(8'h12, last_nack);
                            check(last_nack == 1'b0, "master ACK after MPL data byte0");

                            slave_send_byte(8'h34, last_nack);
                            check(last_nack == 1'b0, "master ACK after MPL data byte1");

                            slave_send_byte(8'h50, last_nack);
                            check(last_nack == 1'b0, "master ACK after MPL data byte2");

                            slave_send_byte(8'h67, last_nack);
                            check(last_nack == 1'b0, "master ACK after MPL data byte3");

                            slave_send_byte(8'h80, last_nack);
                            check(last_nack == 1'b1, "master NACK after MPL final data byte");
                        end

                        begin : CHECK_THREAD
                            pulse_mpl_start();

                            wait(mpl_i2c_busy == 1'b1);
                            $display("@@@[MILESTONE] MPL i2c_busy asserted at t=%0t", $time);

                            wait(mpl_data_valid == 1'b1);
                            $display("@@@[MILESTONE] MPL data_valid asserted at t=%0t", $time);

                            check(mpl_error == 1'b0, "MPL controller error remains 0");
                            check(mpl_pressure_raw == exp_pressure, "MPL pressure_raw correct");
                            check(mpl_temp_raw == exp_temp, "MPL temp_raw correct");

                            check(result_valid == 1'b1, "result_valid asserted");
                            check(result_sensor_id == S_MPL3115, "result_sensor_id correct");
                            check(result_error == 1'b0, "result_error remains 0");
                            check(result_data == exp_result, "result_data correct for MPL chain");
                        end
                    join
                end

                begin : TIMEOUT_THREAD
                    repeat (1200000) @(posedge clk);
                    $display("@@@[FAIL] TEST 1 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;
        end
    endtask

    // =========================================================
    // TEST 2: first config write NACK -> error path
    // =========================================================
    task automatic test_mpl_chain_cfg_nack();
        begin
            $display("\n================ TEST 2: MPL chain cfg NACK ================");

            fork
                begin : NORMAL_PATH
                    fork
                        begin : SLAVE_THREAD
                            wait(mpl_i2c_busy == 1'b1);
                            wait_ack_phase_and_drive(1'b1); // NACK on first ACK slot
                        end

                        begin : CHECK_THREAD
                            pulse_mpl_start();

                            wait(mpl_i2c_busy == 1'b1);
                            $display("@@@[MILESTONE] MPL i2c_busy asserted on cfg-NACK test at t=%0t", $time);

                            wait(mpl_error == 1'b1);
                            $display("@@@[MILESTONE] MPL error asserted after cfg-NACK at t=%0t", $time);

                            check(mpl_error == 1'b1, "MPL controller error asserted after NACK");
                            #1;
                            check(result_error == 1'b1, "result_error asserted after NACK");
                            check(result_sensor_id == S_MPL3115, "result_sensor_id remains MPL on error");
                        end
                    join
                end

                begin : TIMEOUT_THREAD
                    repeat (300000) @(posedge clk);
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
        test_mpl_chain_normal();

        apply_reset();
        test_mpl_chain_cfg_nack();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #100;
        $finish;
    end

endmodule
