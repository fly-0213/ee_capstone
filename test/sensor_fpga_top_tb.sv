`timescale 1ns/1ps
`include "packet_defs.svh"

module sensor_fpga_top_tb;

    localparam int UART_CLKS_PER_BIT_TB = 4;
    localparam int PACK_BYTES = PACK_W / 8;

    logic clk;
    logic reset;

    logic start_pulse;
    logic stop_pulse;

    logic i2c_sda_in;
    logic i2c_sda_oe;
    logic i2c_sda_out_low;
    logic i2c_scl;

    logic uart_tx;
    logic system_busy;

    // fake open-drain slave side
    logic slave_drive_low;
    logic bus_sda;

    int test_pass;
    int test_fail;
    int uart_packet_rx_count;
    int uart_done_count;
    int packet_count;
    int fifo_pop_count;
    int serializer_done_count;
    logic test_completed;

    logic [PACK_W-1:0] rx_pkt_bits [0:2];
    packet_t rx_pkt;

    sensor_fpga_top #(
        .FIFO_DEPTH(8),
        .TS_TICK_RATIO(1000),
        .UART_CLKS_PER_BIT(UART_CLKS_PER_BIT_TB)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start_pulse(start_pulse),
        .stop_pulse(stop_pulse),

        .i2c_sda_in(i2c_sda_in),
        .i2c_sda_oe(i2c_sda_oe),
        .i2c_sda_out_low(i2c_sda_out_low),
        .i2c_scl(i2c_scl),

        .uart_tx(uart_tx),
        .system_busy(system_busy)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    always_comb begin
        logic master_drive_low;
        master_drive_low = i2c_sda_oe && i2c_sda_out_low;
        bus_sda   = (master_drive_low || slave_drive_low) ? 1'b0 : 1'b1;
        i2c_sda_in = bus_sda;
    end

    logic prev_uart_tx;
    logic prev_busy;
    logic [1:0] prev_sched_state;

    always @(posedge clk) begin
        if (reset) begin
            prev_uart_tx <= uart_tx;
            prev_busy    <= system_busy;
            prev_sched_state <= dut.u_sched.state;
        end else begin
            if (start_pulse || stop_pulse ||
                uart_tx != prev_uart_tx ||
                system_busy != prev_busy ||
                dut.u_sched.state != prev_sched_state) begin
                $display("@@@[TRACE] t=%0t start=%0b stop=%0b uart_tx=%0b system_busy=%0b sched_state=%0d sens_id=%0d fifo_empty=%0b ser_busy=%0b tx_busy=%0b",
                         $time, start_pulse, stop_pulse, uart_tx, system_busy,
                         dut.u_sched.state, dut.sens_id, dut.fifo_empty, dut.ser_busy, dut.tx_busy);
            end

            prev_uart_tx <= uart_tx;
            prev_busy    <= system_busy;
            prev_sched_state <= dut.u_sched.state;
        end
    end

    always @(posedge clk) begin
        if (reset) packet_count <= 0;
        else if (dut.packet_valid) packet_count <= packet_count + 1;
    end

    always @(posedge clk) begin
        if (reset) fifo_pop_count <= 0;
        else if (dut.fifo_packet_out_valid) fifo_pop_count <= fifo_pop_count + 1;
    end

    always @(posedge clk) begin
        if (reset) serializer_done_count <= 0;
        else if (dut.ser_pkt_done) serializer_done_count <= serializer_done_count + 1;
    end

    always @(posedge clk) begin
        if (reset) uart_done_count <= 0;
        else if (dut.tx_done) uart_done_count <= uart_done_count + 1;
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
            reset           = 1'b1;
            start_pulse     = 1'b0;
            stop_pulse      = 1'b0;
            slave_drive_low = 1'b0;
            uart_packet_rx_count = 0;
            uart_done_count = 0;
            packet_count = 0;
            fifo_pop_count = 0;
            serializer_done_count = 0;
            test_completed  = 1'b0;

            rx_pkt_bits[0]  = '0;
            rx_pkt_bits[1]  = '0;
            rx_pkt_bits[2]  = '0;

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

    task automatic wait_ack_phase_and_drive(input bit nack);
        begin
            wait(dut.u_i2c_mux.u_i2c_master.state == dut.u_i2c_mux.u_i2c_master.S_GET_ACK &&
                 dut.u_i2c_mux.u_i2c_master.subphase == dut.u_i2c_mux.u_i2c_master.SUB_0);

            if (nack)
                slave_drive_low = 1'b0;
            else
                slave_drive_low = 1'b1;

            @(posedge i2c_scl);
            @(negedge i2c_scl);
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
                @(posedge i2c_scl);
                @(negedge i2c_scl);
                slave_drive_low = (data_byte[i-1] == 1'b0);
            end

            @(posedge i2c_scl);
            @(negedge i2c_scl);
            slave_drive_low = 1'b0;

            @(posedge i2c_scl);
            master_sent_nack = (bus_sda == 1'b1);

            @(negedge i2c_scl);
            slave_drive_low = 1'b0;
        end
    endtask

    task automatic wait_read_start();
        begin
            wait(dut.u_i2c_mux.u_i2c_master.state == dut.u_i2c_mux.u_i2c_master.S_READ_BYTE);
        end
    endtask

    task automatic wait_master_idle();
        begin
            wait(dut.u_i2c_mux.u_i2c_master.state == dut.u_i2c_mux.u_i2c_master.S_IDLE &&
                 dut.u_i2c_mux.mas_busy == 1'b0);
            @(posedge clk);
        end
    endtask

    task automatic run_ads_once();
        bit last_nack;
        begin
            wait(dut.ads_i2c_busy == 1'b1);

            // write config
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);

            wait(dut.u_ads.state == dut.u_ads.S_WAIT_CONV);
            force dut.u_ads.conv_wait_cnt = dut.u_ads.CONV_WAIT_CYCLES;
            @(posedge clk);
            release dut.u_ads.conv_wait_cnt;

            // read conversion
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);

            wait_read_start();
            slave_send_byte(8'h12, last_nack);
            check(last_nack == 1'b0, "ADS byte0 ACK");
            slave_send_byte(8'h34, last_nack);
            check(last_nack == 1'b1, "ADS final byte NACK");
        end
    endtask

    task automatic run_sht_once();
        bit last_nack;
        begin
            wait(dut.sht_i2c_busy == 1'b1);

            // send measurement command
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);

            wait(dut.u_sht.state == dut.u_sht.S_WAIT_MEAS);
            force dut.u_sht.meas_wait_cnt = dut.u_sht.MEAS_WAIT_CYCLES;
            @(posedge clk);
            release dut.u_sht.meas_wait_cnt;

            // read 6 bytes
            wait_ack_phase_and_drive(1'b0);
            wait_read_start();

            slave_send_byte(8'h66, last_nack);
            slave_send_byte(8'h77, last_nack);
            slave_send_byte(8'hAA, last_nack);
            slave_send_byte(8'h88, last_nack);
            slave_send_byte(8'h99, last_nack);
            slave_send_byte(8'hBB, last_nack);

            check(last_nack == 1'b1, "SHT final byte NACK");
        end
    endtask

    task automatic run_mpl_once();
        bit last_nack;
        begin
            wait(dut.mpl_i2c_busy == 1'b1);

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
            check(last_nack == 1'b1, "MPL status byte NACK");

            // read measurement data
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);
            wait_ack_phase_and_drive(1'b0);

            wait_read_start();
            slave_send_byte(8'h12, last_nack);
            slave_send_byte(8'h34, last_nack);
            slave_send_byte(8'h50, last_nack);
            slave_send_byte(8'h67, last_nack);
            slave_send_byte(8'h80, last_nack);

            check(last_nack == 1'b1, "MPL final byte NACK");
        end
    endtask

    task automatic uart_recv_byte(output logic [7:0] rx_byte);
        int i;
        begin
            rx_byte = 8'h00;

            // wait start bit falling edge
            @(negedge uart_tx);

            // sample near center of start bit
            repeat (UART_CLKS_PER_BIT_TB/2) @(posedge clk);
            #1;
            check(uart_tx == 1'b0, "UART start bit low");

            // move to first data bit center
            repeat (UART_CLKS_PER_BIT_TB) @(posedge clk);
            #1;

            // 8 data bits, LSB first
            for (i = 0; i < 8; i++) begin
                rx_byte[i] = uart_tx;
                repeat (UART_CLKS_PER_BIT_TB) @(posedge clk);
                #1;
            end

            // stop bit should be high
            check(uart_tx == 1'b1, "UART stop bit high");
        end
    endtask

    task automatic uart_recv_packet(output logic [PACK_W-1:0] rx_bits);
        logic [7:0] rx_byte;
        int i;
        begin
            rx_bits = '0;
            for (i = 0; i < PACK_BYTES; i++) begin
                uart_recv_byte(rx_byte);
                rx_bits[(PACK_W-1) - 8*i -: 8] = rx_byte;
            end
        end
    endtask

    task automatic check_uart_packet(
        input integer idx,
        input logic [SENSOR_W-1:0] exp_sensor,
        input logic [DATA_W-1:0]   exp_data,
        input logic                exp_err,
        input string               tag
    );
        begin
            rx_pkt = rx_pkt_bits[idx];

            check(rx_pkt.head == HEAD_MAGIC,   {tag, " head correct"});
            check(rx_pkt.sensor == exp_sensor, {tag, " sensor correct"});
            check(rx_pkt.data == exp_data,     {tag, " data correct"});
            check(rx_pkt.flag[0] == exp_err,   {tag, " flag[0] correct"});
            check(rx_pkt.crc == '0,            {tag, " crc zero"});
        end
    endtask

    // =========================================================
    // TEST: one-shot full top smoke test
    // =========================================================
    task automatic test_full_top_smoke();
        logic [DATA_W-1:0] exp_ads;
        logic [DATA_W-1:0] exp_sht;
        logic [DATA_W-1:0] exp_mpl;
        begin
            $display("\n================ TEST: sensor_fpga_top smoke ================");

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

                        begin : UART_RX_THREAD
                            uart_recv_packet(rx_pkt_bits[0]);
                            uart_packet_rx_count = 1;
                            uart_recv_packet(rx_pkt_bits[1]);
                            uart_packet_rx_count = 2;
                            uart_recv_packet(rx_pkt_bits[2]);
                            uart_packet_rx_count = 3;
                        end

                        begin : CHECK_THREAD
                            pulse_start();

                            wait(uart_done_count >= 3*PACK_BYTES);
                            wait(dut.u_sched.state == dut.u_sched.S_IDLE &&
                                 system_busy == 1'b0 &&
                                 dut.fifo_empty == 1'b1 &&
                                 dut.ser_busy == 1'b0 &&
                                 dut.tx_busy == 1'b0);
                            repeat (20) @(posedge clk);

                            check(dut.u_sched.state == dut.u_sched.S_IDLE, "top scheduler returned to IDLE");
                            check_uart_packet(0, S_ADS1115, exp_ads, 1'b0, "top UART pkt0 ADS");
                            check_uart_packet(1, S_SHT30,   exp_sht, 1'b0, "top UART pkt1 SHT");
                            check_uart_packet(2, S_MPL3115, exp_mpl, 1'b0, "top UART pkt2 MPL");
                            test_completed = 1'b1;
                        end
                    join
                end

                begin : TIMEOUT_THREAD
                    repeat (8000000) @(posedge clk);
                    if (!test_completed) begin
                        $display("@@@[TB] timeout counters: packet_count=%0d fifo_pop_count=%0d serializer_done_count=%0d uart_done_count=%0d uart_packet_rx_count=%0d",
                                 packet_count, fifo_pop_count, serializer_done_count,
                                 uart_done_count, uart_packet_rx_count);
                        $display("@@@[FAIL] TOP TEST TIMEOUT");
                        test_fail++;
                    end
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
        uart_packet_rx_count = 0;
        uart_done_count = 0;
        packet_count = 0;
        fifo_pop_count = 0;
        serializer_done_count = 0;
        test_completed = 1'b0;

        $display("@@@[TB] PACK_W=%0d PACK_BYTES=%0d serializer_pkt_mem_bits=%0d serializer_byte_count_bits=%0d",
                 PACK_W, PACK_BYTES, $bits(dut.u_serializer.pkt_mem),
                 $bits(dut.u_serializer.byte_count));

        apply_reset();
        test_full_top_smoke();

        $display("\n========================================================");
        $display("@@@TEST SUMMARY: PASS=%0d FAIL=%0d", test_pass, test_fail);
        $display("========================================================\n");

        #100;
        $finish;
    end

endmodule
