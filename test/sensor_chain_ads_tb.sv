`timescale 1ns/1ps
`include "packet_defs.svh"

module sensor_chain_ads_tb;

    logic clk;
    logic reset;

    logic ads_start;
    logic [$clog2(SENS_NUM)-1:0] sens_id;

    // shared i2c wires
    logic sda_in;
    logic sda_oe;
    logic sda_out_low;
    logic scl;

    // ADS controller <-> mux wires
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

    // unused SHT/MPL ports
    logic        sht_i2c_busy;
    logic        sht_i2c_done;
    logic [47:0] sht_i2c_rdata;
    logic        sht_i2c_ack_error;
    logic        sht_i2c_start;
    logic        sht_i2c_rw;
    logic [6:0]  sht_i2c_dev_addr;
    logic [2:0]  sht_i2c_num_bytes;
    logic [15:0] sht_i2c_wdata;

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

    // result mux outputs
    logic        result_valid;
    logic [$clog2(SENS_NUM)-1:0] result_sensor_id;
    logic [DATA_W-1:0] result_data;
    logic        result_error;

    // fake open-drain slave
    logic slave_drive_low;
    logic bus_sda;

    int test_pass;
    int test_fail;

    ads1115_ctrl u_ads (
        .clk          (clk),
        .reset        (reset),
        .start        (ads_start),

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

        .sht_data_valid(1'b0),
        .sht_error(1'b0),
        .sht_temp_raw(16'h0000),
        .sht_hum_raw(16'h0000),

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

    // =========================================================
    // Concise trace: only state changes
    // =========================================================
    logic [2:0] prev_ads_state;
    logic [3:0] prev_mas_state;
    logic       prev_ads_i2c_busy;
    logic       prev_ads_i2c_done;
    logic       prev_ads_valid;
    logic       prev_ads_error;
    logic       prev_result_valid;
    logic       prev_result_error;

    always @(posedge clk) begin
        if (reset) begin
            prev_ads_state    <= u_ads.state;
            prev_mas_state    <= u_mux.u_i2c_master.state;
            prev_ads_i2c_busy <= ads_i2c_busy;
            prev_ads_i2c_done <= ads_i2c_done;
            prev_ads_valid    <= ads_data_valid;
            prev_ads_error    <= ads_error;
            prev_result_valid <= result_valid;
            prev_result_error <= result_error;
        end else begin
            if (u_ads.state != prev_ads_state ||
                u_mux.u_i2c_master.state != prev_mas_state ||
                ads_i2c_busy != prev_ads_i2c_busy ||
                ads_i2c_done != prev_ads_i2c_done ||
                ads_data_valid != prev_ads_valid ||
                ads_error != prev_ads_error ||
                result_valid != prev_result_valid ||
                result_error != prev_result_error) begin
                $display("@@@[TRACE] t=%0t ads_state=%0d mas_state=%0d ads_i2c_busy=%0b ads_i2c_done=%0b ads_valid=%0b ads_error=%0b result_valid=%0b result_error=%0b",
                         $time, u_ads.state, u_mux.u_i2c_master.state,
                         ads_i2c_busy, ads_i2c_done, ads_data_valid, ads_error,
                         result_valid, result_error);
            end

            prev_ads_state    <= u_ads.state;
            prev_mas_state    <= u_mux.u_i2c_master.state;
            prev_ads_i2c_busy <= ads_i2c_busy;
            prev_ads_i2c_done <= ads_i2c_done;
            prev_ads_valid    <= ads_data_valid;
            prev_ads_error    <= ads_error;
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
            ads_start       = 1'b0;
            sens_id         = S_ADS1115;
            slave_drive_low = 1'b0;

            sht_i2c_start     = 1'b0;
            sht_i2c_rw        = 1'b0;
            sht_i2c_dev_addr  = '0;
            sht_i2c_num_bytes = '0;
            sht_i2c_wdata     = '0;

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

    task automatic pulse_ads_start();
        begin
            $display("@@@[TB] pulse_ads_start at t=%0t", $time);
            ads_start = 1'b1;
            @(posedge clk);
            ads_start = 1'b0;
        end
    endtask

    task automatic slave_ack();
        begin
            slave_drive_low = 1'b1;
            @(posedge scl);
            @(negedge scl);
            slave_drive_low = 1'b0;
        end
    endtask

    task automatic slave_nack();
        begin
            slave_drive_low = 1'b0;
            @(posedge scl);
            @(negedge scl);
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
            // wait for read transaction active
            wait(u_mux.u_i2c_master.state == u_mux.u_i2c_master.S_READ_BYTE);
        end
    endtask

    task automatic ack_ads_read_preamble();
        begin
            // ADS read uses a combined transaction:
            // ADDR_W + REG_CONVERSION + RESTART + ADDR_R, then read bytes.
            wait_ack_phase_and_drive(1'b0); // ADDR_W ack
            wait_ack_phase_and_drive(1'b0); // REG_CONVERSION ack
            wait_ack_phase_and_drive(1'b0); // ADDR_R ack
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

    // =========================================================
    // TEST 1: normal ADS chain
    // =========================================================
    task automatic test_ads_chain_normal();
        bit last_nack;
        logic [DATA_W-1:0] exp_result;
        begin
            $display("\n================ TEST 1: ADS chain normal ================");
            exp_result = {{(DATA_W-16){1'b0}}, 16'h1234};

            fork
                begin : SLAVE_THREAD
                    // first write transaction: 4 ACKs
                    wait(ads_i2c_busy == 1'b1);
                    wait_ack_phase_and_drive(1'b0); // ADDR_W ack
                    wait_ack_phase_and_drive(1'b0); // REG_CONFIG ack
                    wait_ack_phase_and_drive(1'b0); // CFG_HI ack
                    wait_ack_phase_and_drive(1'b0); // CFG_LO ack

                    // wait until controller enters conversion wait
                    wait(u_ads.state == u_ads.S_WAIT_CONV);
                    $display("@@@[MILESTONE] ADS entered S_WAIT_CONV at t=%0t", $time);

                    // fast-forward wait counter
                    force u_ads.conv_wait_cnt = u_ads.CONV_WAIT_CYCLES;
                    @(posedge clk);
                    release u_ads.conv_wait_cnt;

                    // second transaction: write addr/reg then read 2 bytes
                    ack_ads_read_preamble();
                    wait_read_start();
                    slave_send_byte(8'h12, last_nack);
                    check(last_nack == 1'b0, "master ACK after ADS read byte0");

                    slave_send_byte(8'h34, last_nack);
                    check(last_nack == 1'b1, "master NACK after ADS final read byte");
                end

                begin : CHECK_THREAD
                    pulse_ads_start();

                    wait(ads_i2c_busy == 1'b1);
                    $display("@@@[MILESTONE] ADS i2c_busy asserted at t=%0t", $time);

                    wait(ads_data_valid == 1'b1);
                    $display("@@@[MILESTONE] ADS data_valid asserted at t=%0t", $time);

                    check(ads_error == 1'b0, "ADS controller error remains 0");
                    check(ads_data_out == 16'h1234, "ADS controller data_out correct");
                    check(result_valid == 1'b1, "result_valid asserted");
                    check(result_sensor_id == S_ADS1115, "result_sensor_id correct");
                    check(result_error == 1'b0, "result_error remains 0");
                    check(result_data == exp_result, "result_data correct for ADS chain");
                end

                begin : TIMEOUT_THREAD
                    repeat (800000) @(posedge clk);
                    $display("@@@[FAIL] TEST 1 TIMEOUT");
                    test_fail++;
                end
            join_any
            disable fork;
        end
    endtask

    // =========================================================
    // TEST 2: config write NACK -> error path
    // =========================================================
    task automatic test_ads_chain_cfg_nack();
        begin
            $display("\n================ TEST 2: ADS chain config NACK ================");

            fork
                begin : SLAVE_THREAD
                    wait(ads_i2c_busy == 1'b1);
                    wait_ack_phase_and_drive(1'b1);
                end

                begin : CHECK_THREAD
                    pulse_ads_start();

                    wait(ads_i2c_busy == 1'b1);
                    $display("@@@[MILESTONE] ADS i2c_busy asserted on cfg-NACK test at t=%0t", $time);

                    wait(ads_error == 1'b1);
                    $display("@@@[MILESTONE] ADS error asserted after cfg-NACK at t=%0t", $time);

                    check(ads_error == 1'b1, "ADS controller error asserted after NACK");
                    check(result_error == 1'b1, "result_error asserted after NACK");
                    check(result_sensor_id == S_ADS1115, "result_sensor_id remains ADS on error");
                end

                begin : TIMEOUT_THREAD
                    repeat (150000) @(posedge clk);
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
        test_ads_chain_normal();

        apply_reset();
        test_ads_chain_cfg_nack();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #100;
        $finish;
    end

endmodule
