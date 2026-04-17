`timescale 1ns/1ps
`include "packet_defs.svh"

module packetizer_tb;

    logic                   clk;
    logic                   reset;
    logic                   result_valid;
    logic                   result_error;
    logic [SENSOR_W-1:0]    sensor_id;
    logic [DATA_W-1:0]      sensor_data;
    logic [TS_W-1:0]        timestamp;
    logic                   packet_ready;

    logic [PACK_W-1:0]      packet_out;
    logic                   packet_valid;

    int test_pass;
    int test_fail;

    packet_t exp_pkt;
    packet_t got_pkt;

    packetizer dut (
        .clk         (clk),
        .reset       (reset),
        .result_valid(result_valid),
        .result_error(result_error),
        .sensor_id   (sensor_id),
        .sensor_data (sensor_data),
        .timestamp   (timestamp),
        .packet_ready(packet_ready),
        .packet_out  (packet_out),
        .packet_valid(packet_valid)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    logic prev_packet_valid;

    always @(posedge clk) begin
        if (reset) begin
            prev_packet_valid <= packet_valid;
        end else begin
            if (packet_valid != prev_packet_valid || result_valid || result_error) begin
                $display("@@@[TRACE] t=%0t result_valid=%0b result_error=%0b sensor_id=%0d sensor_data=0x%0h timestamp=0x%0h ready=%0b | packet_valid=%0b packet_out=0x%0h",
                         $time, result_valid, result_error, sensor_id, sensor_data, timestamp,
                         packet_ready, packet_valid, packet_out);
            end
            prev_packet_valid <= packet_valid;
        end
    end


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
            reset        = 1'b1;
            result_valid = 1'b0;
            result_error = 1'b0;
            sensor_id    = '0;
            sensor_data  = '0;
            timestamp    = '0;
            packet_ready = 1'b0;

            repeat (5) @(posedge clk);
            reset = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic load_inputs(
        input logic                  in_result_valid,
        input logic                  in_result_error,
        input logic [SENSOR_W-1:0]   in_sensor_id,
        input logic [DATA_W-1:0]     in_sensor_data,
        input logic [TS_W-1:0]       in_timestamp,
        input logic                  in_packet_ready
    );
        begin
            result_valid = in_result_valid;
            result_error = in_result_error;
            sensor_id    = in_sensor_id;
            sensor_data  = in_sensor_data;
            timestamp    = in_timestamp;
            packet_ready = in_packet_ready;
        end
    endtask

    task automatic build_expected_packet(
        input logic [SENSOR_W-1:0] in_sensor_id,
        input logic [DATA_W-1:0]   in_sensor_data,
        input logic [TS_W-1:0]     in_timestamp,
        input logic                in_error
    );
        begin
            exp_pkt.head   = HEAD_MAGIC;
            exp_pkt.sensor = in_sensor_id;
            exp_pkt.ts     = in_timestamp;
            exp_pkt.data   = in_sensor_data;
            exp_pkt.flag   = '0;
            exp_pkt.flag[0]= in_error;
            exp_pkt.crc    = '0;
        end
    endtask

    task automatic capture_packet();
        begin
            got_pkt = packet_out;
        end
    endtask

    task automatic check_packet_fields(input string tag);
        begin
            capture_packet();
            check(got_pkt.head   == exp_pkt.head,   {tag, " head correct"});
            check(got_pkt.sensor == exp_pkt.sensor, {tag, " sensor field correct"});
            check(got_pkt.ts     == exp_pkt.ts,     {tag, " timestamp field correct"});
            check(got_pkt.data   == exp_pkt.data,   {tag, " data field correct"});
            check(got_pkt.flag   == exp_pkt.flag,   {tag, " flag field correct"});
            check(got_pkt.crc    == exp_pkt.crc,    {tag, " crc field correct"});
        end
    endtask

    // =========================================================
    // TEST 1: normal valid packet
    // =========================================================
    task automatic test_normal_valid_packet();
        begin
            $display("\n================ TEST 1: normal valid packet ================");

            build_expected_packet(S_ADS1115, 32'h0000_1234, 16'h00A5, 1'b0);

            load_inputs(
                1'b1,                 // result_valid
                1'b0,                 // result_error
                S_ADS1115,
                32'h0000_1234,
                16'h00A5,
                1'b1                  // packet_ready
            );

            @(posedge clk);
            #1;

            check(packet_valid == 1'b1, "packet_valid asserted for normal valid packet");
            check_packet_fields("normal valid");

            // next cycle should drop packet_valid
            load_inputs(1'b0, 1'b0, '0, '0, '0, 1'b1);
            @(posedge clk);
            #1;
            check(packet_valid == 1'b0, "packet_valid drops after one cycle");
        end
    endtask

    // =========================================================
    // TEST 2: error packet
    // =========================================================
    task automatic test_error_packet();
        begin
            $display("\n================ TEST 2: error packet ================");

            build_expected_packet(S_SHT30, 32'h6677_8899, 16'h0123, 1'b1);

            load_inputs(
                1'b0,                 // result_valid
                1'b1,                 // result_error
                S_SHT30,
                32'h6677_8899,
                16'h0123,
                1'b1
            );

            @(posedge clk);
            #1;

            check(packet_valid == 1'b1, "packet_valid asserted for error packet");
            check_packet_fields("error packet");
            check(got_pkt.flag[0] == 1'b1, "flag[0] marks error packet");

            load_inputs(1'b0, 1'b0, '0, '0, '0, 1'b1);
            @(posedge clk);
            #1;
            check(packet_valid == 1'b0, "packet_valid drops after error packet pulse");
        end
    endtask

    // =========================================================
    // TEST 3: packet_ready=0 blocks packet
    // =========================================================
    task automatic test_ready_low_blocks_packet();
        begin
            $display("\n================ TEST 3: ready low blocks packet ================");

            load_inputs(
                1'b1,
                1'b0,
                S_MPL3115,
                32'h1234_5678,
                16'h0F0F,
                1'b0
            );

            @(posedge clk);
            #1;

            check(packet_valid == 1'b0, "packet_valid stays low when packet_ready=0");
        end
    endtask

    // =========================================================
    // TEST 4: both result_valid and result_error high
    // packet_fire still sends, error bit should be 1
    // =========================================================
    task automatic test_valid_and_error_both_high();
        begin
            $display("\n================ TEST 4: valid and error both high ================");

            build_expected_packet(S_MPL3115, 32'h1234_5678, 16'h00FF, 1'b1);

            load_inputs(
                1'b1,
                1'b1,
                S_MPL3115,
                32'h1234_5678,
                16'h00FF,
                1'b1
            );

            @(posedge clk);
            #1;

            check(packet_valid == 1'b1, "packet_valid asserted when valid and error both high");
            check_packet_fields("valid+error packet");
            check(got_pkt.flag[0] == 1'b1, "flag[0] still indicates error");
        end
    endtask

    // =========================================================
    // TEST 5: reset clears outputs
    // =========================================================
    task automatic test_reset_behavior();
        begin
            $display("\n================ TEST 5: reset behavior ================");

            apply_reset();
            #1;

            check(packet_valid == 1'b0, "packet_valid cleared by reset");
            check(packet_out == '0,      "packet_out cleared by reset");
        end
    endtask

    // =========================================================
    // Main
    // =========================================================
    initial begin
        test_pass = 0;
        test_fail = 0;

        apply_reset();
        test_normal_valid_packet();

        apply_reset();
        test_error_packet();

        apply_reset();
        test_ready_low_blocks_packet();

        apply_reset();
        test_valid_and_error_both_high();

        test_reset_behavior();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #100;
        $finish;
    end

endmodule
