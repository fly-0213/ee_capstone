`timescale 1ns/1ps
`include "packet_defs.svh"

module packetizer_tb;
    logic                    clk;
    logic                    reset;
    logic                    sample_valid;
    logic [SENSOR_W-1:0]     sensor_id;
    logic [DATA_W-1:0]       sensor_data;
    logic [TS_W-1:0]         timestamp;
    logic                    packet_ready;

    logic [PACK_W-1:0]       packet_out;
    logic                    packet_valid;

    packet_t expected_pkt;

    packetizer dut (
        .clk         (clk),
        .reset       (reset),
        .sample_valid(sample_valid),
        .sensor_id   (sensor_id),
        .sensor_data (sensor_data),
        .timestamp   (timestamp),
        .packet_ready(packet_ready),
        .packet_out  (packet_out),
        .packet_valid(packet_valid)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;   // 10 ns period
    end

    // -----------------------------
    // Task: compare packet output
    // -----------------------------
    task automatic check_packet(
        input logic [SENSOR_W-1:0] exp_sensor,
        input logic [DATA_W-1:0]   exp_data,
        input logic [TS_W-1:0]     exp_ts
    );
    begin
        expected_pkt.head   = HEAD_MAGIC;
        expected_pkt.sensor = exp_sensor;
        expected_pkt.ts     = exp_ts;
        expected_pkt.data   = exp_data;
        expected_pkt.flag   = '0;
        expected_pkt.crc    = '0;

        if (packet_valid !== 1'b1) begin
            $display("ERROR @ %0t: packet_valid is not 1 when expected", $time);
            $fatal;
        end

        if (packet_out !== expected_pkt) begin
            $display("ERROR @ %0t: packet_out mismatch", $time);
            $display("Expected = %h", expected_pkt);
            $display("Got      = %h", packet_out);
            $fatal;
        end else begin
            $display("PASS  @ %0t: packet matched. packet_out = %h", $time, packet_out);
        end
    end
    endtask

    initial begin
        $display("==== Start packetizer testbench ====");

        // init
        reset        = 1'b1;
        sample_valid = 1'b0;
        sensor_id    = '0;
        sensor_data  = '0;
        timestamp    = '0;
        packet_ready = 1'b1;   // currently unused by DUT

        // hold reset for a couple cycles
        repeat (2) @(posedge clk);

        // check reset outputs
        if (packet_out !== '0 || packet_valid !== 1'b0) begin
            $display("ERROR @ %0t: reset state incorrect", $time);
            $display("packet_out   = %h", packet_out);
            $display("packet_valid = %b", packet_valid);
            $fatal;
        end else begin
            $display("PASS  @ %0t: reset state correct", $time);
        end

        // release reset
        reset = 1'b0;
        @(posedge clk);

        // -------------------------------------------------
        // Test 1: send one valid sample
        // -------------------------------------------------
        sensor_id    = S_TEMP;
        sensor_data  = 52'h0000_0000_12345;
        timestamp    = 32'h1234_5678;
        sample_valid = 1'b1;

        @(posedge clk);
        #1;
        check_packet(S_TEMP, 52'h0000_0000_12345, 32'h1234_5678);

        // deassert valid
        sample_valid = 1'b0;
        @(posedge clk);
        #1;

        if (packet_valid !== 1'b0) begin
            $display("ERROR @ %0t: packet_valid should deassert when sample_valid=0", $time);
            $fatal;
        end else begin
            $display("PASS  @ %0t: packet_valid deasserted correctly", $time);
        end

        // packet_out should hold previous value
        if (packet_out !== expected_pkt) begin
            $display("ERROR @ %0t: packet_out did not hold previous packet", $time);
            $fatal;
        end else begin
            $display("PASS  @ %0t: packet_out held previous value correctly", $time);
        end

        // -------------------------------------------------
        // Test 2: send another valid sample
        // -------------------------------------------------
        sensor_id    = S_LIGHT;
        sensor_data  = 52'h0000_0000_ABCDE;
        timestamp    = 32'hCAFE_BABE;
        sample_valid = 1'b1;

        @(posedge clk);
        #1;
        check_packet(S_LIGHT, 52'h0000_0000_ABCDE, 32'hCAFE_BABE);

        // -------------------------------------------------
        // Test 3: packet_ready toggles (should not matter yet)
        // -------------------------------------------------
        sample_valid = 1'b0;
        packet_ready = 1'b0;
        @(posedge clk);
        #1;

        if (packet_valid !== 1'b0) begin
            $display("ERROR @ %0t: packet_valid should be 0 here", $time);
            $fatal;
        end else begin
            $display("PASS  @ %0t: packet_ready currently has no effect, as expected", $time);
        end

        // -------------------------------------------------
        // Test 4: one more packet with different sensor
        // -------------------------------------------------
        packet_ready = 1'b1;
        sensor_id    = S_HUMN;
        sensor_data  = 52'h0000_0000_0F0F0;
        timestamp    = 32'h0000_00AA;
        sample_valid = 1'b1;

        @(posedge clk);
        #1;
        check_packet(S_HUMN, 52'h0000_0000_0F0F0, 32'h0000_00AA);

        // finish
        sample_valid = 1'b0;
        @(posedge clk);

        $display("==== All packetizer tests passed ====");
        $finish;
    end

endmodule