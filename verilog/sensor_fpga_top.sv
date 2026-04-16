`include "packet_defs.svh"

module sensor_fpga_top (
    input  logic clk,
    input  logic reset,

    input  logic start_pulse,
    input  logic stop_pulse,

    // sensor side
    input  logic                     sens_valid,
    input  logic                     sens_busy,
    input  logic [DATA_W-1:0]        sensor_data,
    input  logic                     sensor_data_valid,
    output logic                     sens_req,
    output logic [$clog2(SENS_NUM)-1:0] sens_id,

    // uart output
    output logic tx_serial
);

    //////////////////////////////////////////////////
    //                                              //
    //              internal signals                //
    //                                              //
    //////////////////////////////////////////////////

    // latch which sensor this returned data belongs to
    logic [$clog2(SENS_NUM)-1:0] active_sensor_id;

    // timestamp counter
    logic [TS_W-1:0] timestamp;

    // packetizer output
    logic                    packet_valid;
    logic [PACKET_W-1:0]     packet_data_pkt;

    // fifo signals
    logic                    write_valid;
    logic                    read_valid;
    logic [PACKET_W-1:0]     packet_data_fifo;
    logic                    fifo_full;
    logic                    fifo_empty;

    // serializer signals
    logic                    pkt_valid;
    logic                    pkt_done;
    logic [7:0]              byte_out;
    logic                    byte_valid;
    //logic                    serializer_busy;   // optional if your serializer has this port

    // uart signals
    logic                    uart_ready;
    logic [7:0]              tx_data;
    logic                    tx_valid;
    logic                    tx_busy;
    logic                    tx_done;


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
    logic [19:0] mpl_temp_raw;
    logic [11:0] mpl_pressure_raw;
    logic        mpl_error;

 


    //////////////////////////////////////////////////
    //                                              //
    //               timestamp counter              //
    //                                              //
    //////////////////////////////////////////////////

    always_ff @(posedge clk) begin
        if (reset) begin
            timestamp <= '0;
        end else begin
            timestamp <= timestamp + 1'b1;
        end
    end

    //////////////////////////////////////////////////
    //                                              //
    //                  scheduler                   //
    //                                              //
    //////////////////////////////////////////////////

    scheduler scheduler_0 (
        .clk        (clk),
        .reset      (reset),
        .start_pulse(start_pulse),
        .stop_pulse (stop_pulse),
        .sens_valid (sens_valid),
        //.sens_busy  (sens_busy),     // if your scheduler has this port

        .sens_req   (sens_req),
        .sens_id    (sens_id)
    );

    //////////////////////////////////////////////////
    //                                              //
    //          latch active requested sensor       //
    //                                              //
    //////////////////////////////////////////////////


    ads1115_ctrl u_ads1115_ctrl(
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

    sht30_ctrl u_sht30_ctrl(
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

    mpl3115_ctrl u_mpl3115_ctrl(
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

    // When a request is actually issued, remember which sensor it was.
    // Later, when sensor_data_valid comes back, packetizer uses active_sensor_id.
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            active_sensor_id <= '0;
        end else if (sens_req && !sens_busy) begin
            active_sensor_id <= sens_id;
        end
    end

    //////////////////////////////////////////////////
    //                                              //
    //                 packetizer                   //
    //                                              //
    //////////////////////////////////////////////////

    packetizer packetizer_0 (
        .clk         (clk),
        .reset       (reset),
        .sample_valid(sensor_data_valid),
        .sensor_id   (active_sensor_id),
        .sensor_data (sensor_data),
        .timestamp   (timestamp),

        .packet_out  (packet_data_pkt),
        .packet_valid(packet_valid)
    );

    //////////////////////////////////////////////////
    //                                              //
    //             packetizer -> fifo               //
    //                                              //
    //////////////////////////////////////////////////

    assign write_valid = packet_valid && !fifo_full;

    //////////////////////////////////////////////////
    //                                              //
    //                    fifo                      //
    //                                              //
    //////////////////////////////////////////////////

    fifo fifo_0 (
        .clk        (clk),
        .reset      (reset),
        .write_valid(write_valid),
        .packet_in  (packet_data_pkt),
        .read_valid (read_valid),

        .packet_out (packet_data_fifo),
        .full       (fifo_full),
        .empty      (fifo_empty)
    );

    //////////////////////////////////////////////////
    //                                              //
    //            fifo -> pkt_serializer            //
    //                                              //
    //////////////////////////////////////////////////

    // Simplest policy:
    // if serializer is free and FIFO is not empty, read one packet
    //
    // Note:
    // This assumes FIFO's packet_out is valid immediately when read_valid is asserted
    // or valid in the expected cycle for your serializer.
    // If your FIFO is synchronous-read, you may need one extra state/register here.
    assign read_valid = (!fifo_empty) && (!serializer_busy);

    // Give serializer a 1-cycle pulse when we read a packet from FIFO
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pkt_valid <= 1'b0;
        end else begin
            pkt_valid <= read_valid;
        end
    end

    //////////////////////////////////////////////////
    //                                              //
    //               pkt_serializer                 //
    //                                              //
    //////////////////////////////////////////////////

    assign uart_ready = !tx_busy;

    pkt_serializer pkt_serializer_0 (
        .clk       (clk),
        .reset     (reset),
        .pkt_valid (pkt_valid),
        .packet_in (packet_data_fifo),
        .uart_ready(uart_ready),

        .byte_out  (byte_out),
        .pkt_done  (pkt_done),
        .byte_valid(byte_valid),
        //.busy      (serializer_busy)   // remove if your serializer does not have this port
    );

    //////////////////////////////////////////////////
    //                                              //
    //             pkt_serializer -> uart           //
    //                                              //
    //////////////////////////////////////////////////

    // Because serializer already sees uart_ready,
    // it should only advance when UART can accept a byte.
    assign tx_data  = byte_out;
    assign tx_valid = byte_valid;

    //////////////////////////////////////////////////
    //                                              //
    //                   uart_tx                    //
    //                                              //
    //////////////////////////////////////////////////

    uart_tx uart_tx_0 (
        .clk      (clk),
        .reset    (reset),
        .tx_valid (tx_valid),
        .tx_data  (tx_data),

        .tx_serial(tx_serial),
        .tx_busy  (tx_busy),
        .tx_done  (tx_done)
    );

endmodule