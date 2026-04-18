`include "packet_defs.svh"

module sensor_fpga_top #(
    parameter int FIFO_DEPTH     = 8,
    parameter int TS_TICK_RATIO  = 1000,
    parameter int SENS_NUM = 3,
    parameter int UART_CLKS_PER_BIT = CLK_FREQ / BAUD_RATE

)(
    input  logic clk,
    input  logic reset,

    input  logic start_pulse,
    input  logic stop_pulse,

    input  logic i2c_sda_in,
    output logic i2c_sda_oe,
    output logic i2c_sda_out_low,
    output logic i2c_scl,

    output logic uart_tx,
    output logic system_busy
);

    //////////////////////////////////////////////////
    //                                              //
    //              internal signals                //
    //                                              //
    //////////////////////////////////////////////////

    // scheduler signals
    logic sens_req;
    logic [$clog2(SENS_NUM)-1:0] sens_id;

    // timestamp counter
    logic tick;
    logic [TS_W-1:0] time_c;

    // result mux
    logic        result_valid;
    logic [$clog2(SENS_NUM)-1:0] result_sensor_id;
    logic [DATA_W-1:0] result_data;
    logic        result_error;

    // packetizer output
    logic              packet_ready;
    logic [PACK_W-1:0] packet_out;
    logic              packet_valid;

    // fifo signals
    logic [PACK_W-1:0] fifo_packet_out;
    logic              fifo_packet_out_valid;
    logic              fifo_full;
    logic              fifo_empty;
    logic              fifo_read_en;

    // serializer signals
    logic              ser_pkt_valid;
    logic [PACK_W-1:0] ser_packet_in;
    logic              ser_pkt_ready;
    logic              ser_uart_ready;
    logic [7:0]        ser_byte_out;
    logic              ser_byte_valid;
    logic              ser_pkt_done;
    logic              ser_busy;

    // uart signals
    logic              tx_busy;
    logic              tx_done;
    logic              tx_ready;


    logic        ads_start;
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

    logic        ads_busy;
    logic        ads_data_valid;
    logic [15:0] ads_data_out;
    logic        ads_error;

    logic        sht_start;
    logic        sht_i2c_busy;
    logic        sht_i2c_done;
    logic [47:0] sht_i2c_rdata;
    logic        sht_i2c_ack_error;

    logic        sht_i2c_start;
    logic        sht_i2c_rw;         
    logic [6:0]  sht_i2c_dev_addr;
    logic [2:0]  sht_i2c_num_bytes;   
    logic [15:0] sht_i2c_wdata;

    logic        sht_busy;
    logic        sht_data_valid;
    logic [15:0] sht_temp_raw;
    logic [15:0] sht_hum_raw;
    logic        sht_error;

    logic        mpl_start;
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

    logic        mpl_busy;
    logic        mpl_data_valid;
    logic [19:0] mpl_pressure_raw;
    logic [11:0] mpl_temp_raw;
    logic        mpl_error;

    assign ads_start = sens_req && (sens_id == S_ADS1115);
    assign sht_start = sens_req && (sens_id == S_SHT30);
    assign mpl_start = sens_req && (sens_id == S_MPL3115);



    //////////////////////////////////////////////////
    //                                              //
    //               timestamp counter              //
    //                                              //
    //////////////////////////////////////////////////

    tick_gen #(
        .tick_ratio(TS_TICK_RATIO)
    ) u_tick_gen (
        .clk  (clk),
        .reset(reset),
        .tick (tick)
    );

    timestamp #(
        .TS_W(TS_W)
    ) u_timestamp (
        .clk   (clk),
        .reset (reset),
        .tick  (tick),
        .time_c(time_c)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                  scheduler                   //
    //                                              //
    //////////////////////////////////////////////////

    scheduler_os #(.SENS_NUM(SENS_NUM)) u_sched (
        .clk(clk),
        .reset(reset),
        .start_pulse(start_pulse),
        .stop_pulse(stop_pulse),
        .result_valid(result_valid),
        .result_error(result_error),
        .sens_req(sens_req),
        .sens_id(sens_id)
    );

    //////////////////////////////////////////////////
    //                                              //
    //            three sensor controller           //
    //                                              //
    //////////////////////////////////////////////////

    ads1115_ctrl u_ads (
        .clk(clk),
        .reset(reset),

        .start(ads_start),
        .i2c_busy(ads_i2c_busy),
        .i2c_done(ads_i2c_done),
        .i2c_rdata(ads_i2c_rdata),
        .i2c_ack_error(ads_i2c_ack_error),

        .i2c_start(ads_i2c_start),
        .i2c_rw(ads_i2c_rw),
        .i2c_dev_addr(ads_i2c_dev_addr),
        .i2c_reg_addr(ads_i2c_reg_addr),
        .i2c_num_bytes(ads_i2c_num_bytes),
        .i2c_wdata(ads_i2c_wdata),
        .busy(ads_busy),
        .data_valid(ads_data_valid),
        .data_out(ads_data_out),
        .error(ads_error)
    );

    sht30_ctrl u_sht(
        .clk(clk),
        .reset(reset),

        .start(sht_start),
        .i2c_busy(sht_i2c_busy),
        .i2c_done(sht_i2c_done),
        .i2c_rdata(sht_i2c_rdata),
        .i2c_ack_error(sht_i2c_ack_error),

        .i2c_start(sht_i2c_start),
        .i2c_rw(sht_i2c_rw),          
        .i2c_dev_addr(sht_i2c_dev_addr),
        .i2c_wdata(sht_i2c_wdata),
        .i2c_num_bytes(sht_i2c_num_bytes), 

        .busy(sht_busy),
        .data_valid(sht_data_valid),
        .temp_raw(sht_temp_raw),
        .hum_raw(sht_hum_raw),
        .error(sht_error)
    );

    mpl3115_ctrl u_mpl(
        .clk(clk),
        .reset(reset),

        .start(mpl_start),
        .i2c_busy(mpl_i2c_busy),
        .i2c_done(mpl_i2c_done),
        .i2c_rdata(mpl_i2c_rdata),
        .i2c_ack_error(mpl_i2c_ack_error),

        .i2c_start(mpl_i2c_start),
        .i2c_rw(mpl_i2c_rw),          
        .i2c_dev_addr(mpl_i2c_dev_addr),
        .i2c_reg_addr(mpl_i2c_reg_addr),
        .i2c_num_bytes(mpl_i2c_num_bytes), 
        .i2c_wdata(mpl_i2c_wdata),

        .busy(mpl_busy),
        .data_valid(mpl_data_valid),
        .pressure_raw(mpl_pressure_raw),
        .temp_raw(mpl_temp_raw),
        .error(mpl_error)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                   i2c_mux                    //
    //                                              //
    //////////////////////////////////////////////////    

    sensor_i2c_mux u_i2c_mux (
        .clk(clk),
        .reset(reset),

        .sens_id(sens_id),
        .sda_in(i2c_sda_in),
        .sda_oe(i2c_sda_oe),
        .sda_out_low(i2c_sda_out_low),
        .scl(i2c_scl),

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

    //////////////////////////////////////////////////
    //                                              //
    //                 result mux                   //
    //                                              //
    //////////////////////////////////////////////////

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

    //////////////////////////////////////////////////
    //                                              //
    //                 packetizer                   //
    //                                              //
    //////////////////////////////////////////////////

    assign packet_ready = !fifo_full;

    packetizer u_packetizer (
        .clk         (clk),
        .reset       (reset),
        .result_valid(result_valid),
        .result_error(result_error),
        .sensor_id   (result_sensor_id),
        .sensor_data (result_data),
        .timestamp   (time_c),

        .packet_ready(packet_ready),
        .packet_out  (packet_out),
        .packet_valid(packet_valid)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                    fifo                      //
    //                                              //
    //////////////////////////////////////////////////

    fifo #(.DEPTH(FIFO_DEPTH)) u_fifo (
        .clk        (clk),
        .reset      (reset),
        .write_valid(packet_valid),
        .packet_in  (packet_out),
        .read_en(fifo_read_en),

        .packet_out (fifo_packet_out),
        .packet_out_valid(fifo_packet_out_valid),
        .full       (fifo_full),
        .empty      (fifo_empty)
    );

    //////////////////////////////////////////////////
    //                                              //
    //               pkt_serializer                 //
    //                                              //
    //////////////////////////////////////////////////
    assign ser_pkt_valid = fifo_packet_out_valid;
    assign ser_packet_in = fifo_packet_out;
    assign fifo_read_en  = ser_pkt_ready && !fifo_empty;
    assign ser_uart_ready = tx_ready;

    pkt_serializer u_serializer (
        .clk       (clk),
        .reset     (reset),
        .pkt_valid (ser_pkt_valid),
        .packet_in (ser_packet_in),
        .pkt_ready(ser_pkt_ready),
        .uart_ready(ser_uart_ready),

        .byte_out  (ser_byte_out),
        .pkt_done  (ser_pkt_done),
        .byte_valid(ser_byte_valid),
        .busy(ser_busy)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                   uart_tx                    //
    //                                              //
    //////////////////////////////////////////////////

    uart_tx #(
        .CLKS_PER_BIT(UART_CLKS_PER_BIT)
    ) u_uart_tx (
        .clk      (clk),
        .reset    (reset),
        .tx_valid (ser_byte_valid),
        .tx_data  (ser_byte_out),

        .tx_serial(uart_tx),
        .tx_busy  (tx_busy),
        .tx_done  (tx_done),
        .tx_ready(tx_ready)
    );

    assign system_busy = ads_busy || sht_busy || mpl_busy ||
                        !fifo_empty || ser_busy || tx_busy;

endmodule
