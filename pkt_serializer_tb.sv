`timescale 1ns/1ps
`include "packet_defs.svh"

module pkt_serializer_tb;

    logic              clk;
    logic              reset;
    logic              pkt_valid;
    logic [PACK_W-1:0] packet_in;
    logic              uart_ready;

    logic [7:0]        byte_out;
    logic              pkt_done;
    logic              byte_valid;

    localparam int NUM_BYTES = PACK_W / 8;

    logic [PACK_W-1:0] test_pkt;
    logic [7:0]        expected_byte;

    pkt_serializer dut (
        .clk       (clk),
        .reset     (reset),
        .pkt_valid (pkt_valid),
        .packet_in (packet_in),
        .uart_ready(uart_ready),
        .byte_out  (byte_out),
        .pkt_done  (pkt_done),
        .byte_valid(byte_valid)
    );

    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("pkt_serializer_tb.vcd");
        $dumpvars(0, pkt_serializer_tb);
    end

    task automatic send_packet(input logic [PACK_W-1:0] pkt);
    begin
        @(negedge clk);
        pkt_valid  = 1'b1;
        packet_in  = pkt;

        @(negedge clk);
        pkt_valid  = 1'b0;
        packet_in  = '0;
    end
    endtask

   
    task automatic check_next_byte(
        input logic [7:0] exp_byte,
        input logic       exp_done
    );
    begin
        // wait until serializer actually outputs a byte
        while (byte_valid !== 1'b1) begin
            @(posedge clk);
            #1;
        end

        if (byte_out !== exp_byte) begin
            $display("@@@ERROR @ %0t: byte mismatch", $time);
            $display("@@@Expected byte = %h", exp_byte);
            $display("@@@Got           = %h", byte_out);
            $fatal;
        end

        if (pkt_done !== exp_done) begin
            $display("@@@ERROR @ %0t: pkt_done mismatch", $time);
            $display("@@@Expected pkt_done = %b", exp_done);
            $display("@@@Got               = %b", pkt_done);
            $fatal;
        end

        $display("@@@PASS @ %0t: byte=%h pkt_done=%b", $time, byte_out, pkt_done);

        @(posedge clk);
        #1;
    end
    endtask

    integer i;

    initial begin
        // init
        reset      = 1'b1;
        pkt_valid  = 1'b0;
        packet_in  = '0;
        uart_ready = 1'b1;

        // make one clear packet pattern
        test_pkt = 128'hA5A5_1122_3344_5566_7788_99AA_BBCC_DDEE;

        $display("==== Start pkt_serializer testbench ====");

        // hold reset
        repeat (3) @(posedge clk);
        #1;

        if (byte_out !== 8'h00 || byte_valid !== 1'b0 || pkt_done !== 1'b0) begin
            $display("@@@ERROR @ %0t: reset state incorrect", $time);
            $display("@@@byte_out   = %h", byte_out);
            $display("@@@byte_valid = %b", byte_valid);
            $display("@@@pkt_done   = %b", pkt_done);
            $fatal;
        end else begin
            $display("@@@PASS @ %0t: reset state correct", $time);
        end

        // release reset
        @(negedge clk);
        reset = 1'b0;

        // ---------------------------------
        // Test 1: normal packet serialization
        // ---------------------------------
        send_packet(test_pkt);

        for (i = 0; i < NUM_BYTES; i = i + 1) begin
            expected_byte = test_pkt[(PACK_W-1) - 8*i -: 8];

            if (i == NUM_BYTES-1)
                check_next_byte(expected_byte, 1'b1);
            else
                check_next_byte(expected_byte, 1'b0);
        end

        $display("@@@PASS @ %0t: normal serialization test passed", $time);

        // ---------------------------------
        // Test 2: stall when uart_ready = 0
        // ---------------------------------
        test_pkt = 128'h1234_5678_9ABC_DEF0_0102_0304_0506_0708;
        send_packet(test_pkt);

        // first 3 bytes should come out normally
        for (i = 0; i < 3; i = i + 1) begin
            expected_byte = test_pkt[(PACK_W-1) - 8*i -: 8];
            check_next_byte(expected_byte, 1'b0);
        end

        // stall serializer
        @(negedge clk);
        uart_ready = 1'b0;

        // wait a few cycles, byte_valid should stay 0
        repeat (3) begin
            @(posedge clk);
            #1;
            if (byte_valid !== 1'b0) begin
                $display("@@@ERROR @ %0t: byte_valid should be 0 during stall", $time);
                $fatal;
            end
        end

        $display("@@@PASS @ %0t: stall behavior looks correct", $time);

        // resume
        @(negedge clk);
        uart_ready = 1'b1;

        // remaining bytes should continue from byte index 3
        for (i = 3; i < NUM_BYTES; i = i + 1) begin
            expected_byte = test_pkt[(PACK_W-1) - 8*i -: 8];

            if (i == NUM_BYTES-1)
                check_next_byte(expected_byte, 1'b1);
            else
                check_next_byte(expected_byte, 1'b0);
        end

        $display("@@@PASS @ %0t: stall/resume test passed", $time);

        $display("==== All pkt_serializer tests passed ====");
        $finish;
    end

endmodule