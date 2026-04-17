`timescale 1ns/1ps
`include "packet_defs.svh"

module sensor_scheduler_os_chain_tb;

    logic clk;
    logic reset;

    logic start_pulse;
    logic stop_pulse;

    logic sens_req;
    logic [$clog2(SENS_NUM)-1:0] sens_id;

    // shared i2c wires
    logic sda_in;
    logic sda_oe;
    logic sda_out_low;
    logic scl;

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

    logic        ads_busy;
    logic        ads_data_valid;
    logic [15:0] ads_data_out;
    logic        ads_error;

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

    logic        result_valid;
    logic [$clog2(SENS_NUM)-1:0] result_sensor_id;
    logic [DATA_W-1:0] result_data;
    logic        result_error;

    // scheduler feedback
    logic sched_result_valid;
    logic sched_result_error;

    // fake open-drain slave
    logic slave_drive_low;
    logic bus_sda;

    int test_pass;
    int test_fail;
    int complete_count;

    // sens_id stability check
    logic trans_active;
    logic [$clog2(SENS_NUM)-1:0] locked_sens_id;

    // concise trace
    logic [1:0] prev_sched_state;
    logic [2:0] prev_ads_state;
    logic [3:0] prev_sht_state;
    logic [3:0] prev_mpl_state;
    logic [3:0] prev_mas_state;
    logic prev_result_valid;
    logic prev_result_error;
    logic [$clog2(SENS_NUM)-1:0] prev_sens_id;

    scheduler_os #(.SENS_NUM(3)) u_sched_os (
        .clk(clk),
        .reset(reset),
        .start_pulse(start_pulse),
        .stop_pulse(stop_pulse),
        .result_valid(sched_result_valid),
        .result_error(sched_result_error),
        .sens_req(sens_req),
        .sens_id(sens_id)
    );

    assign sched_result_valid = result_valid;
    assign sched_result_error = result_error;

    ads1115_ctrl u_ads (
        .clk          (clk),
        .reset        (reset),
        .start        (sens_req && (sens_id == S_ADS1115)),

        .i2c_busy     (ads_i2c_busy),
        .i2c_done     (ads_i2c_done),
        .i2c_rdata    (ads_i2c_rdata),
        .i2c_ack_error(ads_i2c_ack_error),

        .i2c_start    (ads_i2c_start),
        .i2c_rw       (ads_i2c_rw),
        .i2c_dev_addr (ads_i2c_dev_addr),
        .i2c_reg_addr (ads_i2c_reg_addr),
        .i2c_num_bytes(ads_i2c_num_bytes),
        .i2c_wdata    (ads_i2c_wdata),

        .busy         (ads_busy),
        .data_valid   (ads_data_valid),
        .data_out     (ads_data_out),
        .error        (ads_error)
    );

    sht30_ctrl u_sht (
        .clk          (clk),
        .reset        (reset),
        .start        (sens_req && (sens_id == S_SHT30)),

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

    mpl3115_ctrl u_mpl (
        .clk          (clk),
        .reset        (reset),
        .start        (sens_req && (sens_id == S_MPL3115)),

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

        .ads_data_valid(ads_data_valid),
        .ads_error(ads_error),
        .ads_data_out(ads_data_out),

        .sht_data_valid(sht_data_valid),
        .sht_error(sht_error),
        .sht_temp_raw(sht_temp_raw),
        .sht_hum_raw(sht_hum_raw),

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
            prev_sched_state  <= u_sched_os.state;
            prev_ads_state    <= u_ads.state;
            prev_sht_state    <= u_sht.state;
            prev_mpl_state    <= u_mpl.state;
            prev_mas_state    <= u_mux.u_i2c_master.state;
            prev_result_valid <= result_valid;
            prev_result_error <= result_error;
            prev_sens_id      <= sens_id;
        end else begin
            if (u_sched_os.state != prev_sched_state ||
                u_ads.state   != prev_ads_state   ||
                u_sht.state   != prev_sht_state   ||
                u_mpl.state   != prev_mpl_state   ||
                u_mux.u_i2c_master.state != prev_mas_state ||
                result_valid != prev_result_valid ||
                result_error != prev_result_error ||
                sens_id != prev_sens_id) begin
                $display("@@@[TRACE] t=%0t sched=%0d sens_id=%0d ads=%0d sht=%0d mpl=%0d mas=%0d result_valid=%0b result_error=%0b",
                         $time,
                         u_sched_os.state, sens_id,
                         u_ads.state, u_sht.state, u_mpl.state,
                         u_mux.u_i2c_master.state,
                         result_valid, result_error);
            end

            prev_sched_state  <= u_sched_os.state;
            prev_ads_state    <= u_ads.state;
            prev_sht_state    <= u_sht.state;
            prev_mpl_state    <= u_mpl.state;
            prev_mas_state    <= u_mux.u_i2c_master.state;
            prev_result_valid <= result_valid;
            prev_result_error <= result_error;
            prev_sens_id      <= sens_id;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            trans_active   <= 1'b0;
            locked_sens_id <= '0;
        end else begin
            if (!trans_active && u_mux.mas_busy) begin
                trans_active   <= 1'b1;
                locked_sens_id <= sens_id;
            end else if (trans_active) begin
                if (sens_id != locked_sens_id) begin
                    $display("@@@[FAIL] sens_id changed during active transaction: old=%0d new=%0d t=%0t",
                             locked_sens_id, sens_id, $time);
                    test_fail++;
                    trans_active <= 1'b0;
                end else if (!u_mux.mas_busy &&
                             u_mux.u_i2c_master.state == u_mux.u_i2c_master.S_IDLE) begin
                    trans_active <= 1'b0;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            complete_count <= 0;
        end else if (result_valid || result_error) begin
            complete_count <= complete_count + 1;
            $display("@@@[MILESTONE] completion #%0d sensor=%0d valid=%0b error=%0b data=0x%0h t=%0t",
                     complete_count + 1, result_sensor_id, result_valid, result_error, result_data, $time);
        end
    end

    // =========================================================
    // helpers
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
            start_pulse     = 1'b0;
            stop_pulse      = 1'b0;
            slave_drive_low = 1'b0;

            repeat (5) @(posedge clk);
            reset = 1'b0;
            repeat (10) @(posedge clk);
        end
    endtask

    task automatic pulse_start();
        begin
            $display("@@@[TB] pulse_start at t=%0t", $time);
            start_pulse = 1'b1;
            @(posedge clk);
            #1;
            start_pulse = 1'b0;
        end
    endtask

    task automatic pulse_stop();
        begin
            $display("@@@[TB] pulse_stop at t=%0t", $time);
            stop_pulse = 1'b1;
            @(posedge clk);
            #1;
            stop_pulse = 1'b0;
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

    task automatic wait_master_idle();
        begin
            wait(u_mux.u_i2c_master.state == u_mux.u_i2c_master.S_IDLE &&
                 u_mux.mas_busy == 1'b0);
            @(posedge clk);
        end
    endtask

    // =========================================================
    // slave sequences
    // =========================================================
    task automatic run_ads_once();
        bit last_nack;
        begin
            wait(ads_i2c_busy == 1'b1);

            // write config
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);

            wait(u_ads.state == u_ads.S_WAIT_CONV);
            force u_ads.conv_wait_cnt = u_ads.CONV_WAIT_CYCLES;
            @(posedge clk);
            release u_ads.conv_wait_cnt;

            // read conversion
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);

            wait_read_start();

            slave_send_byte(8'h12, last_nack);
            check(last_nack == 1'b0, "master ACK after ADS byte0");

            slave_send_byte(8'h34, last_nack);
            check(last_nack == 1'b1, "master NACK after ADS final byte");
        end
    endtask

    task automatic run_sht_once();
        bit last_nack;
        begin
            wait(sht_i2c_busy == 1'b1);

            // send command
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);

            wait(u_sht.state == u_sht.S_WAIT_MEAS);
            force u_sht.meas_wait_cnt = u_sht.MEAS_WAIT_CYCLES;
            @(posedge clk);
            release u_sht.meas_wait_cnt;

            // pure read
            wait_ack_phase_and_drive(1'b0);
            wait_read_start();

            slave_send_byte(8'h66, last_nack);
            check(last_nack == 1'b0, "master ACK after SHT byte0");

            slave_send_byte(8'h77, last_nack);
            check(last_nack == 1'b0, "master ACK after SHT byte1");

            slave_send_byte(8'hAA, last_nack);
            check(last_nack == 1'b0, "master ACK after SHT byte2");

            slave_send_byte(8'h88, last_nack);
            check(last_nack == 1'b0, "master ACK after SHT byte3");

            slave_send_byte(8'h99, last_nack);
            check(last_nack == 1'b0, "master ACK after SHT byte4");

            slave_send_byte(8'hBB, last_nack);
            check(last_nack == 1'b1, "master NACK after SHT final byte");
        end
    endtask

    task automatic run_mpl_once();
        bit last_nack;
        begin
            wait(mpl_i2c_busy == 1'b1);

            // write CTRL1_CFG
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);

            // write PT_DATA_CFG
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);

            // write CTRL1_OST
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);

            // read STATUS
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);

            wait_read_start();
            slave_send_byte(8'h08, last_nack);
            check(last_nack == 1'b1, "master NACK after MPL STATUS byte");

            // read DATA
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);

            wait_read_start();

            slave_send_byte(8'h12, last_nack);
            check(last_nack == 1'b0, "master ACK after MPL byte0");

            slave_send_byte(8'h34, last_nack);
            check(last_nack == 1'b0, "master ACK after MPL byte1");

            slave_send_byte(8'h50, last_nack);
            check(last_nack == 1'b0, "master ACK after MPL byte2");

            slave_send_byte(8'h67, last_nack);
            check(last_nack == 1'b0, "master ACK after MPL byte3");

            slave_send_byte(8'h80, last_nack);
            check(last_nack == 1'b1, "master NACK after MPL final byte");
        end
    endtask

    // =========================================================
    // TEST 1: one-shot round
    // =========================================================
    task automatic test_one_shot_round();
        logic [DATA_W-1:0] exp_ads;
        logic [DATA_W-1:0] exp_sht;
        logic [DATA_W-1:0] exp_mpl;
        begin
            $display("\n================ TEST 1: one-shot round ================");

            exp_ads = {{(DATA_W-16){1'b0}}, 16'h1234};
            exp_sht = {{(DATA_W-32){1'b0}}, 16'h6677, 16'h8899};
            exp_mpl = {{(DATA_W-32){1'b0}}, 20'h12345, 12'h678};

            fork
                begin : NORMAL_PATH
                    fork
                        begin : SLAVE_THREAD
                            run_ads_once();
                            wait_master_idle();

                            run_sht_once();
                            wait_master_idle();

                            run_mpl_once();
                            wait_master_idle();
                        end

                        begin : CHECK_THREAD
                            pulse_start();

                            // ADS
                            wait(result_valid == 1'b1 && result_sensor_id == S_ADS1115);
                            check(result_error == 1'b0, "ADS result_error remains 0");
                            check(result_data == exp_ads, "ADS result_data correct");
                            @(posedge clk);

                            // SHT
                            wait(result_valid == 1'b1 && result_sensor_id == S_SHT30);
                            check(result_error == 1'b0, "SHT result_error remains 0");
                            check(result_data == exp_sht, "SHT result_data correct");
                            @(posedge clk);

                            // MPL
                            wait(result_valid == 1'b1 && result_sensor_id == S_MPL3115);
                            check(result_error == 1'b0, "MPL result_error remains 0");
                            check(result_data == exp_mpl, "MPL result_data correct");
                            @(posedge clk);

                            // after final sensor, one-shot scheduler should go IDLE and stop
                            repeat (20) @(posedge clk);
                            check(u_sched_os.state == u_sched_os.S_IDLE, "scheduler returns to IDLE after one-shot round");
                            check(sens_req == 1'b0, "no extra sens_req after one-shot round");
                        end
                    join
                end

                begin : TIMEOUT_THREAD
                    repeat (2000000) @(posedge clk);
                    $display("@@@[FAIL] TEST 1 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;

            check(complete_count == 3, "exactly 3 completions observed in one-shot round");
        end
    endtask

    // =========================================================
    // TEST 2: stop during one-shot still safe
    // =========================================================
    task automatic test_safe_stop_mid_round();
        begin
            $display("\n================ TEST 2: safe stop mid-round ================");

            fork
                begin : NORMAL_PATH
                    fork
                        begin : SLAVE_THREAD
                            run_ads_once();
                            wait_master_idle();
                        end

                        begin : CHECK_THREAD
                            pulse_start();

                            wait(ads_i2c_busy == 1'b1);
                            pulse_stop();

                            wait(result_valid == 1'b1 && result_sensor_id == S_ADS1115);
                            check(result_error == 1'b0, "ADS still completes after stop request");

                            repeat (20) @(posedge clk);
                            check(u_sched_os.state == u_sched_os.S_IDLE, "scheduler returns to IDLE after stop");
                            check(sens_req == 1'b0, "no next sensor request after stop");
                        end
                    join
                end

                begin : TIMEOUT_THREAD
                    repeat (800000) @(posedge clk);
                    $display("@@@[FAIL] TEST 2 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;
        end
    endtask

    // =========================================================
    // main
    // =========================================================
    initial begin
        test_pass = 0;
        test_fail = 0;

        apply_reset();
        test_one_shot_round();

        apply_reset();
        test_safe_stop_mid_round();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #100;
        $finish;
    end

endmodule
