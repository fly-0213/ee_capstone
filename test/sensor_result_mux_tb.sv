`timescale 1ns/1ps
`include "packet_defs.svh"

module sensor_result_mux_tb;
    logic [$clog2(SENS_NUM)-1:0] sens_id;

    logic        ads_data_valid;
    logic        ads_error;
    logic [15:0] ads_data_out;

    logic        sht_data_valid;
    logic        sht_error;
    logic [15:0] sht_temp_raw;
    logic [15:0] sht_hum_raw;

    logic        mpl_data_valid;
    logic        mpl_error;
    logic [19:0] mpl_temp_raw;
    logic [11:0] mpl_pressure_raw;

    logic        result_valid;
    logic [$clog2(SENS_NUM)-1:0] result_sensor_id;
    logic [DATA_W-1:0] result_data;
    logic        result_error;

    int test_pass;
    int test_fail;

    sensor_result_mux dut (
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
        .mpl_temp_raw(mpl_temp_raw),
        .mpl_pressure_raw(mpl_pressure_raw),

        .result_valid(result_valid),
        .result_sensor_id(result_sensor_id),
        .result_data(result_data),
        .result_error(result_error)
    );

    task automatic check(input bit cond, input string msg);
        begin
            if (cond) begin
                $display("@@@[PASS] %s", msg);
                test_pass++;
            end
            else begin
                $display("@@@[FAIL] %s", msg);
                test_fail++;
            end
        end
    endtask

    task automatic clear_inputs();
        begin
            sens_id           = '0;

            ads_data_valid    = 1'b0;
            ads_error         = 1'b0;
            ads_data_out      = 16'h0000;

            sht_data_valid    = 1'b0;
            sht_error         = 1'b0;
            sht_temp_raw      = 16'h0000;
            sht_hum_raw       = 16'h0000;

            mpl_data_valid    = 1'b0;
            mpl_error         = 1'b0;
            mpl_temp_raw      = 20'h00000;
            mpl_pressure_raw  = 12'h000;

            #1;
        end
    endtask

    // ---------------------------------------------------------
    // TEST 1: ADS route
    // ---------------------------------------------------------
    task automatic test_ads_result();
        logic [DATA_W-1:0] exp_data;
        begin
            $display("\n================ TEST 1: sensor_result_mux ADS ================");

            clear_inputs();

            sens_id        = S_ADS1115;
            ads_data_valid = 1'b1;
            ads_error      = 1'b0;
            ads_data_out   = 16'h1234;

            exp_data = {{(DATA_W-16){1'b0}}, 16'h1234};

            #1;

            check(result_sensor_id == S_ADS1115, "ADS result_sensor_id correct");
            check(result_valid == 1'b1, "ADS result_valid correct");
            check(result_error == 1'b0, "ADS result_error correct");
            check(result_data == exp_data, "ADS result_data zero-extended correctly");
        end
    endtask

    // ---------------------------------------------------------
    // TEST 2: SHT route
    // ---------------------------------------------------------
    task automatic test_sht_result();
        logic [DATA_W-1:0] exp_data;
        begin
            $display("\n================ TEST 2: sensor_result_mux SHT ================");

            clear_inputs();

            sens_id        = S_SHT30;
            sht_data_valid = 1'b1;
            sht_error      = 1'b1;
            sht_temp_raw   = 16'h6680;
            sht_hum_raw    = 16'h99A0;

            exp_data = {{(DATA_W-32){1'b0}}, 16'h6680, 16'h99A0};

            #1;

            check(result_sensor_id == S_SHT30, "SHT result_sensor_id correct");
            check(result_valid == 1'b1, "SHT result_valid correct");
            check(result_error == 1'b1, "SHT result_error correct");
            check(result_data == exp_data, "SHT result_data packed correctly");
        end
    endtask

    // ---------------------------------------------------------
    // TEST 3: MPL route
    // ---------------------------------------------------------
    task automatic test_mpl_result();
        logic [DATA_W-1:0] exp_data;
        begin
            $display("\n================ TEST 3: sensor_result_mux MPL ================");

            clear_inputs();

            sens_id           = S_MPL3115;
            mpl_data_valid    = 1'b1;
            mpl_error         = 1'b0;
            mpl_temp_raw      = 20'hABCDE;
            mpl_pressure_raw  = 12'h789;

            exp_data = {{(DATA_W-32){1'b0}}, 20'hABCDE, 12'h789};

            #1;

            check(result_sensor_id == S_MPL3115, "MPL result_sensor_id correct");
            check(result_valid == 1'b1, "MPL result_valid correct");
            check(result_error == 1'b0, "MPL result_error correct");
            check(result_data == exp_data, "MPL result_data packed correctly");
        end
    endtask

    // ---------------------------------------------------------
    // TEST 4: only selected sensor should matter
    // ---------------------------------------------------------
    task automatic test_only_selected_sensor_matters();
        logic [DATA_W-1:0] exp_data;
        begin
            $display("\n================ TEST 4: only selected sensor matters ================");

            clear_inputs();

            // set all three to conflicting values
            ads_data_valid    = 1'b1;
            ads_error         = 1'b1;
            ads_data_out      = 16'hAAAA;

            sht_data_valid    = 1'b1;
            sht_error         = 1'b0;
            sht_temp_raw      = 16'hBBBB;
            sht_hum_raw       = 16'hCCCC;

            mpl_data_valid    = 1'b1;
            mpl_error         = 1'b1;
            mpl_temp_raw      = 20'hDDDDD;
            mpl_pressure_raw  = 12'hEEE;

            // select SHT only
            sens_id  = S_SHT30;
            exp_data = {{(DATA_W-32){1'b0}}, 16'hBBBB, 16'hCCCC};

            #1;

            check(result_sensor_id == S_SHT30, "selected sensor id remains SHT");
            check(result_valid == 1'b1, "only selected SHT valid used");
            check(result_error == 1'b0, "only selected SHT error used");
            check(result_data == exp_data, "only selected SHT data used");
        end
    endtask

    // ---------------------------------------------------------
    // TEST 5: zero outputs when selected valid is low
    // ---------------------------------------------------------
    task automatic test_selected_valid_low();
        logic [DATA_W-1:0] exp_data;
        begin
            $display("\n================ TEST 5: selected valid low ================");

            clear_inputs();

            sens_id         = S_ADS1115;
            ads_data_valid  = 1'b0;
            ads_error       = 1'b1;
            ads_data_out    = 16'hDEAD;

            exp_data = {{(DATA_W-16){1'b0}}, 16'hDEAD};

            #1;

            check(result_sensor_id == S_ADS1115, "selected sensor id remains ADS");
            check(result_valid == 1'b0, "result_valid follows selected ADS valid");
            check(result_error == 1'b1, "result_error still follows selected ADS error");
            check(result_data == exp_data, "result_data still reflects selected ADS data");
        end
    endtask

    // ---------------------------------------------------------
    // Main
    // ---------------------------------------------------------
    initial begin
        test_pass = 0;
        test_fail = 0;

        test_ads_result();
        test_sht_result();
        test_mpl_result();
        test_only_selected_sensor_matters();
        test_selected_valid_low();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #10;
        $finish;
    end

endmodule