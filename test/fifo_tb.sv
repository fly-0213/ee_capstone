`timescale 1ns/1ps
`include "packet_defs.svh"

module fifo_tb;

    localparam int DEPTH = 8;

    logic                   clk;
    logic                   reset;
    logic                   write_valid;
    logic [PACK_W-1:0]      packet_in;
    logic                   read_en;

    logic [PACK_W-1:0]      packet_out;
    logic                   packet_out_valid;
    logic                   full;
    logic                   empty;

    int test_pass;
    int test_fail;

    packet_t pkt0, pkt1, pkt2, pkt3, pkt4, pkt5, pkt6, pkt7, pkt8;
    logic [PACK_W-1:0] bits0, bits1, bits2, bits3, bits4, bits5, bits6, bits7, bits8;

    fifo #(.DEPTH(DEPTH)) dut (
        .clk            (clk),
        .reset          (reset),
        .write_valid    (write_valid),
        .packet_in      (packet_in),
        .read_en        (read_en),
        .packet_out     (packet_out),
        .packet_out_valid(packet_out_valid),
        .full           (full),
        .empty          (empty)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    logic prev_full;
    logic prev_empty;
    logic prev_out_valid;
    logic [$clog2(DEPTH+1)-1:0] prev_count;

    always @(posedge clk) begin
        if (reset) begin
            prev_full      <= full;
            prev_empty     <= empty;
            prev_out_valid <= packet_out_valid;
            prev_count     <= dut.count;
        end else begin
            if (full != prev_full ||
                empty != prev_empty ||
                packet_out_valid != prev_out_valid ||
                dut.count != prev_count ||
                write_valid || read_en) begin
                $display("@@@[TRACE] t=%0t wr=%0b rd=%0b in=0x%0h | out_valid=%0b out=0x%0h full=%0b empty=%0b count=%0d head=%0d tail=%0d",
                         $time, write_valid, read_en, packet_in,
                         packet_out_valid, packet_out,
                         full, empty, dut.count, dut.head, dut.tail);
            end
            prev_full      <= full;
            prev_empty     <= empty;
            prev_out_valid <= packet_out_valid;
            prev_count     <= dut.count;
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
            reset       = 1'b1;
            write_valid = 1'b0;
            read_en     = 1'b0;
            packet_in   = '0;

            repeat (5) @(posedge clk);
            reset = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic drive_write(input [PACK_W-1:0] pkt_bits);
        begin
            write_valid = 1'b1;
            packet_in   = pkt_bits;
            read_en     = 1'b0;
            @(posedge clk);
            #1;
            write_valid = 1'b0;
            packet_in   = '0;
        end
    endtask

    task automatic drive_read();
        begin
            read_en     = 1'b1;
            write_valid = 1'b0;
            @(posedge clk);
            #1;
            read_en     = 1'b0;
        end
    endtask

    task automatic drive_read_write(input [PACK_W-1:0] pkt_bits);
        begin
            write_valid = 1'b1;
            read_en     = 1'b1;
            packet_in   = pkt_bits;
            @(posedge clk);
            #1;
            write_valid = 1'b0;
            read_en     = 1'b0;
            packet_in   = '0;
        end
    endtask

    task automatic check_packet_out(input [PACK_W-1:0] exp_bits, input string msg);
        begin
            check(packet_out_valid == 1'b1, {msg, " packet_out_valid asserted"});
            check(packet_out == exp_bits,   {msg, " packet_out correct"});
        end
    endtask

    task automatic build_pkt(
        output packet_t pkt,
        output logic [PACK_W-1:0] bits,
        input logic [SENSOR_W-1:0] in_sensor,
        input logic [TS_W-1:0]     in_ts,
        input logic [DATA_W-1:0]   in_data,
        input logic [FLAG_W-1:0]   in_flag,
        input logic [CRC_W-1:0]    in_crc
    );
        begin
            pkt.head   = HEAD_MAGIC;
            pkt.sensor = in_sensor;
            pkt.ts     = in_ts;
            pkt.data   = in_data;
            pkt.flag   = in_flag;
            pkt.crc    = in_crc;
            bits       = pkt;
        end
    endtask

    // =========================================================
    // TEST 1: reset state
    // =========================================================
    task automatic test_reset_state();
        begin
            $display("\n================ TEST 1: reset state ================");
            apply_reset();

            check(empty == 1'b1, "FIFO empty after reset");
            check(full  == 1'b0, "FIFO not full after reset");
            check(packet_out_valid == 1'b0, "packet_out_valid cleared after reset");
            check(packet_out == '0, "packet_out cleared after reset");
            check(dut.count == 0, "count reset to 0");
        end
    endtask

    // =========================================================
    // TEST 2: single write then single read
    // =========================================================
    task automatic test_single_write_read();
        begin
            $display("\n================ TEST 2: single write/read ================");
            apply_reset();

            drive_write(bits0);
            check(empty == 1'b0, "FIFO not empty after one write");
            check(full  == 1'b0, "FIFO not full after one write");
            check(dut.count == 1, "count = 1 after one write");
            check(packet_out_valid == 1'b0, "no output valid during write-only");

            drive_read();
            check_packet_out(bits0, "single read returns pkt0");
            check(dut.count == 0, "count = 0 after read");
            check(empty == 1'b1, "FIFO empty after reading only entry");

            @(posedge clk);
            #1;
            check(packet_out_valid == 1'b0, "packet_out_valid deasserts next cycle");
        end
    endtask

    // =========================================================
    // TEST 3: fill FIFO to full
    // =========================================================
    task automatic test_fill_to_full();
        begin
            $display("\n================ TEST 3: fill to full ================");
            apply_reset();

            drive_write(bits0);
            drive_write(bits1);
            drive_write(bits2);
            drive_write(bits3);
            drive_write(bits4);
            drive_write(bits5);
            drive_write(bits6);
            drive_write(bits7);

            check(full == 1'b1, "FIFO full after DEPTH writes");
            check(empty == 1'b0, "FIFO not empty when full");
            check(dut.count == DEPTH, "count = DEPTH when full");
        end
    endtask

    // =========================================================
    // TEST 4: write blocked when full
    // =========================================================
    task automatic test_write_blocked_when_full();
        begin
            $display("\n================ TEST 4: write blocked when full ================");
            apply_reset();

            drive_write(bits0);
            drive_write(bits1);
            drive_write(bits2);
            drive_write(bits3);
            drive_write(bits4);
            drive_write(bits5);
            drive_write(bits6);
            drive_write(bits7);

            check(full == 1'b1, "FIFO full before blocked write");

            drive_write(bits8);

            check(full == 1'b1, "FIFO still full after blocked write");
            check(dut.count == DEPTH, "count unchanged after blocked write");
        end
    endtask

    // =========================================================
    // TEST 5: drain FIFO and preserve order
    // =========================================================
    task automatic test_drain_and_order();
        begin
            $display("\n================ TEST 5: drain FIFO and preserve order ================");
            apply_reset();

            drive_write(bits0);
            drive_write(bits1);
            drive_write(bits2);

            drive_read();
            check_packet_out(bits0, "drain read #0");

            drive_read();
            check_packet_out(bits1, "drain read #1");

            drive_read();
            check_packet_out(bits2, "drain read #2");

            check(empty == 1'b1, "FIFO empty after draining");
            check(dut.count == 0, "count = 0 after draining");
        end
    endtask

    // =========================================================
    // TEST 6: read blocked when empty
    // =========================================================
    task automatic test_read_blocked_when_empty();
        begin
            $display("\n================ TEST 6: read blocked when empty ================");
            apply_reset();

            drive_read();

            check(empty == 1'b1, "FIFO remains empty after blocked read");
            check(packet_out_valid == 1'b0, "packet_out_valid stays low on blocked read");
            check(dut.count == 0, "count remains 0 on blocked read");
        end
    endtask

    // =========================================================
    // TEST 7: simultaneous read/write
    // =========================================================
    task automatic test_simultaneous_read_write();
        begin
            $display("\n================ TEST 7: simultaneous read/write ================");
            apply_reset();

            drive_write(bits0);
            drive_write(bits1);

            // now count=2, read old pkt0 while writing pkt2
            drive_read_write(bits2);

            check_packet_out(bits0, "simultaneous read/write returns old head");
            check(dut.count == 2, "count unchanged on simultaneous read/write");

            // remaining order should now be pkt1, pkt2
            drive_read();
            check_packet_out(bits1, "post simultaneous read returns pkt1");

            drive_read();
            check_packet_out(bits2, "post simultaneous read returns pkt2");

            check(empty == 1'b1, "FIFO empty after consuming pkt1 and pkt2");
        end
    endtask

    // =========================================================
    // TEST 8: wrap-around behavior
    // =========================================================
    task automatic test_wraparound();
        begin
            $display("\n================ TEST 8: wrap-around behavior ================");
            apply_reset();

            // fill some
            drive_write(bits0);
            drive_write(bits1);
            drive_write(bits2);
            drive_write(bits3);

            // pop two
            drive_read();
            check_packet_out(bits0, "wrap read pkt0");

            drive_read();
            check_packet_out(bits1, "wrap read pkt1");

            // push two more, should wrap tail eventually depending on depth/head/tail
            drive_write(bits4);
            drive_write(bits5);

            // remaining order should be pkt2, pkt3, pkt4, pkt5
            drive_read();
            check_packet_out(bits2, "wrap order pkt2");

            drive_read();
            check_packet_out(bits3, "wrap order pkt3");

            drive_read();
            check_packet_out(bits4, "wrap order pkt4");

            drive_read();
            check_packet_out(bits5, "wrap order pkt5");

            check(empty == 1'b1, "FIFO empty after wraparound sequence");
        end
    endtask

    // =========================================================
    // Build packets
    // =========================================================
    initial begin
        build_pkt(pkt0, bits0, S_ADS1115, 16'h0001, 32'h1111_0000, 4'h0, 4'h0);
        build_pkt(pkt1, bits1, S_SHT30,   16'h0002, 32'h2222_0000, 4'h1, 4'h0);
        build_pkt(pkt2, bits2, S_MPL3115, 16'h0003, 32'h3333_0000, 4'h2, 4'h0);
        build_pkt(pkt3, bits3, S_ADS1115, 16'h0004, 32'h4444_0000, 4'h3, 4'h0);
        build_pkt(pkt4, bits4, S_SHT30,   16'h0005, 32'h5555_0000, 4'h4, 4'h0);
        build_pkt(pkt5, bits5, S_MPL3115, 16'h0006, 32'h6666_0000, 4'h5, 4'h0);
        build_pkt(pkt6, bits6, S_ADS1115, 16'h0007, 32'h7777_0000, 4'h6, 4'h0);
        build_pkt(pkt7, bits7, S_SHT30,   16'h0008, 32'h8888_0000, 4'h7, 4'h0);
        build_pkt(pkt8, bits8, S_MPL3115, 16'h0009, 32'h9999_0000, 4'h8, 4'h0);
    end

    // =========================================================
    // Main
    // =========================================================
    initial begin
        test_pass = 0;
        test_fail = 0;

        test_reset_state();
        test_single_write_read();
        test_fill_to_full();
        test_write_blocked_when_full();
        test_drain_and_order();
        test_read_blocked_when_empty();
        test_simultaneous_read_write();
        test_wraparound();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #100;
        $finish;
    end

endmodule
