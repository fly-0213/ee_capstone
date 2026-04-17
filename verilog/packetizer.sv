`include "packet_defs.svh"
module packetizer(
    input                      clk,
    input                      reset,
    input                      result_valid,
    input                      result_error,
    input       [SENSOR_W-1:0] sensor_id,
    input         [DATA_W-1:0] sensor_data,
    input           [TS_W-1:0] timestamp,
    input                      packet_ready, 

    output  logic [PACK_W-1:0] packet_out,
    output  logic              packet_valid

);

    logic [FLAG_W-1:0] flag;
    logic [CRC_W-1:0] crc;
    packet_t           pkt;
    logic              packet_fire;
    assign packet_fire = result_valid || result_error;

    always_comb begin
        flag = '0;
        crc  = '0;

        flag[0] = result_error;

        pkt.head   = HEAD_MAGIC;
        pkt.sensor = sensor_id;
        pkt.ts     = timestamp;
        pkt.data   = sensor_data;
        pkt.flag   = flag;
        pkt.crc    = crc;
    end

    always_ff@(posedge clk) begin
        if (reset) begin
            packet_out <= '0;
            packet_valid <= 1'b0; 
        end else begin
            if (packet_fire && packet_ready) begin
                packet_out <= pkt;
                packet_valid <= 1'b1;
            end else begin
                packet_valid <= 1'b0;
            end
        end 
    end 

endmodule