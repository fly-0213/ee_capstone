`timescale 1ns/1ps
`include "packet_defs.svh"

module fifo_tb;

    localparam int DEPTH = 8;

    logic                     clk;
    logic                     reset;
    logic                     write_valid;
    logic [PACK_W-1:0]        packet_in;
    logic                     read_valid;

    logic [PACK_W-1:0]        packet_out;
    logic                     full;
    logic                     empty;

    // expected packets for checking
    logic [PACK_W-1:0]        exp_pkt0;
    logic [PACK_W-1:0]        exp_pkt1;
    logic [PACK_W-1:0]        exp_pkt2;
    logic [PACK_W-1:0]        exp_pkt3;
    logic [PACK_W-1:0]        exp_pkt4;
    logic [PACK_W-1:0]        exp_pkt5;
    logic [PACK_W-1:0]        exp_pkt6;
    logic [PACK_W-1:0]        exp_pkt7;

    fifo #(.DEPTH(DEPTH)) dut (
        .clk        (clk),
        .reset      (reset),
        .write_valid(write_valid),
        .packet_in  (packet_in),
        .read_valid (read_valid),
        .packet_out (packet_out),
        .full       (full),
        .empty      (empty)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("fifo_tb.vcd");
        $dumpvars(0, fifo_tb);
    end

    task automatic write_packet(input logic [PACK_W-1:0] pkt);
    begin
        @(negedge clk);
        write_valid = 1'b1;
        packet_in   = pkt;
        read_valid  = 1'b0;

        @(negedge clk);
        write_valid = 1'b0;
        packet_in   = '0;
    end
    endtask

    task automatic read_packet(input logic [PACK_W-1:0] exp_pkt);
    begin
        @(negedge clk);
        read_valid  = 1'b1;
        write_valid = 1'b0;

        @(posedge clk);
        #1;
        if (packet_out !== exp_pkt) begin
            $display("@@@ERROR @ %0t: FIFO read mismatch", $time);
            $display("@@@Expected = %h", exp_pkt);
            $display("@@@Got      = %h", packet_out);
            $fatal;
        end else begin
            $display("@@@PASS  @ %0t: FIFO read matched %h", packet_out, $time);
        end

        @(negedge clk);
        read_valid = 1'b0;
    end
    endtask

    task automatic rw_same_cycle(
        input logic [PACK_W-1:0] wr_pkt,
        input logic [PACK_W-1:0] exp_rd_pkt
    );
    begin
        @(negedge clk);
        write_valid = 1'b1;
        packet_in   = wr_pkt;
        read_valid  = 1'b1;

        @(posedge clk);
        #1;
        if (packet_out !== exp_rd_pkt) begin
            $display("@@@ERROR @ %0t: simultaneous read/write mismatch", $time);
            $display("@@@Expected read = %h", exp_rd_pkt);
            $display("@@@Got           = %h", packet_out);
            $fatal;
        end else begin
            $display("@@@PASS  @ %0t: simultaneous read/write OK", $time);
        end

        @(negedge clk);
        write_valid = 1'b0;
        read_valid  = 1'b0;
        packet_in   = '0;
    end
    endtask

    
    initial begin
        // init
        reset       = 1'b1;
        write_valid = 1'b0;
        read_valid  = 1'b0;
        packet_in   = '0;

        // build some distinct packets
        exp_pkt0 = {HEAD_MAGIC, S_LIGHT, 32'h0000_0001, 52'h0000_0000_00001, 8'h00, 16'h0000};
        exp_pkt1 = {HEAD_MAGIC, S_TEMP,  32'h0000_0002, 52'h0000_0000_00002, 8'h00, 16'h0000};
        exp_pkt2 = {HEAD_MAGIC, S_AIR,   32'h0000_0003, 52'h0000_0000_00003, 8'h00, 16'h0000};
        exp_pkt3 = {HEAD_MAGIC, S_HUMN,  32'h0000_0004, 52'h0000_0000_00004, 8'h00, 16'h0000};
        exp_pkt4 = {HEAD_MAGIC, S_LIGHT, 32'h0000_0005, 52'h0000_0000_00005, 8'h00, 16'h0000};
        exp_pkt5 = {HEAD_MAGIC, S_TEMP,  32'h0000_0006, 52'h0000_0000_00006, 8'h00, 16'h0000};
        exp_pkt6 = {HEAD_MAGIC, S_AIR,   32'h0000_0007, 52'h0000_0000_00007, 8'h00, 16'h0000};
        exp_pkt7 = {HEAD_MAGIC, S_HUMN,  32'h0000_0008, 52'h0000_0000_00008, 8'h00, 16'h0000};

        $display("==== Start FIFO testbench ====");

        // hold reset
        repeat (3) @(posedge clk);
        #1;
        if (empty !== 1'b1 || full !== 1'b0 || packet_out !== '0) begin
            $display("@@@ERROR @ %0t: reset state incorrect", $time);
            $display("@@@empty      = %b", empty);
            $display("@@@full       = %b", full);
            $display("@@@packet_out = %h", packet_out);
            $fatal;
        end else begin
            $display("@@@PASS  @ %0t: reset state correct", $time);
        end

        // release reset
        @(negedge clk);
        reset <= 1'b0;

        // -------------------------------------------------
        // Test 1: write one packet, then read it back
        // -------------------------------------------------
        write_packet(exp_pkt0);

        if (empty !== 1'b0) begin
            $display("@@@ERROR @ %0t: FIFO should not be empty after one write", $time);
            $fatal;
        end

        read_packet(exp_pkt0);

        if (empty !== 1'b1) begin
            $display("@@@ERROR @ %0t: FIFO should be empty after reading only packet", $time);
            $fatal;
        end else begin
            $display("@@@PASS  @ %0t: single write/read test OK", $time);
        end

        // -------------------------------------------------
        // Test 2: multiple writes, then multiple reads
        // -------------------------------------------------
        write_packet(exp_pkt1);
        write_packet(exp_pkt2);
        write_packet(exp_pkt3);

        if (empty !== 1'b0) begin
            $display("@@@ERROR @ %0t: FIFO should contain data", $time);
            $fatal;
        end

        read_packet(exp_pkt1);
        read_packet(exp_pkt2);
        read_packet(exp_pkt3);

        if (empty !== 1'b1) begin
            $display("@@@ERROR @ %0t: FIFO should be empty after draining", $time);
            $fatal;
        end else begin
            $display("@@@PASS  @ %0t: multi-packet FIFO order OK", $time);
        end

        // -------------------------------------------------
        // Test 3: fill FIFO completely
        // -------------------------------------------------
        write_packet(exp_pkt0);
        write_packet(exp_pkt1);
        write_packet(exp_pkt2);
        write_packet(exp_pkt3);
        write_packet(exp_pkt4);
        write_packet(exp_pkt5);
        write_packet(exp_pkt6);
        write_packet(exp_pkt7);

        #1;
        if (full !== 1'b1) begin
            $display("@@@ERROR @ %0t: FIFO should be full", $time);
            $fatal;
        end else begin
            $display("@@@PASS  @ %0t: FIFO full asserted correctly", $time);
        end

        // try one more write while full (should be ignored)
        @(posedge clk);
        write_valid <= 1'b1;
        packet_in   <= {HEAD_MAGIC, S_LIGHT, 32'hDEAD_BEEF, 52'h12345, 8'h00, 16'h0000};
        read_valid  <= 1'b0;

        @(posedge clk);
        write_valid <= 1'b0;
        packet_in   <= '0;

        if (full !== 1'b1) begin
            $display("@@@ERROR @ %0t: FIFO full should remain asserted", $time);
            $fatal;
        end else begin
            $display("@@@PASS  @ %0t: write while full ignored as expected", $time);
        end

        // -------------------------------------------------
        // Test 4: read all packets out of full FIFO
        // -------------------------------------------------
        read_packet(exp_pkt0);
        read_packet(exp_pkt1);
        read_packet(exp_pkt2);
        read_packet(exp_pkt3);
        read_packet(exp_pkt4);
        read_packet(exp_pkt5);
        read_packet(exp_pkt6);
        read_packet(exp_pkt7);

        if (empty !== 1'b1 || full !== 1'b0) begin
            $display("@@@ERROR @ %0t: FIFO flags incorrect after draining", $time);
            $display("@@@empty = %b, full = %b", empty, full);
            $fatal;
        end else begin
            $display("@@@PASS  @ %0t: FIFO drained correctly", $time);
        end

        // -------------------------------------------------
        // Test 5: simultaneous read/write
        // preload two packets first
        // -------------------------------------------------
        write_packet(exp_pkt1);
        write_packet(exp_pkt2);

        // same cycle: read pkt1, write pkt3
        rw_same_cycle(exp_pkt3, exp_pkt1);

        // remaining order should now be: pkt2, pkt3
        read_packet(exp_pkt2);
        read_packet(exp_pkt3);

        if (empty !== 1'b1) begin
            $display("@@@ERROR @ %0t: FIFO should be empty after simultaneous RW test", $time);
            $fatal;
        end else begin
            $display("@@@PASS  @ %0t: simultaneous read/write behavior OK", $time);
        end

        $display("==== All FIFO tests passed ====");
        $finish;
    end

endmodule