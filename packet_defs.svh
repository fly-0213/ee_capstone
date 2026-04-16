// packet_defs.svh
`ifndef PACKET_DEFS_SVH
`define PACKET_DEFS_SVH

//localparam int PACK_W   = 128;
localparam int HEAD_W   = 16;
localparam int SENSOR_W = 4;
localparam int TS_W     = 32;
localparam int DATA_W   = 52;
localparam int FLAG_W   = 8;
localparam int CRC_W    = 16;
localparam int PACK_W   = HEAD_W + SENSOR_W + TS_W + DATA_W + FLAG_W + CRC_W;

localparam logic [HEAD_W-1:0] HEAD_MAGIC = 16'hA5A5;
localparam logic CLK_FREQ = 50000000; //可改
localparam logic BAUD_RATE = 115200; //可改

// bit ranges (MSB:LSB)
localparam int HEAD_MSB = PACK_W-1;
localparam int HEAD_LSB = PACK_W-HEAD_W;

localparam int SENSOR_MSB = HEAD_LSB-1;
localparam int SENSOR_LSB = SENSOR_MSB-(SENSOR_W-1);

localparam int TS_MSB = SENSOR_LSB-1;
localparam int TS_LSB = TS_MSB-(TS_W-1);

localparam int DATA_MSB = TS_LSB-1;
localparam int DATA_LSB = DATA_MSB-(DATA_W-1);

localparam int FLAG_MSB = DATA_LSB-1;
localparam int FLAG_LSB = FLAG_MSB-(FLAG_W-1);

localparam int CRC_MSB = FLAG_LSB-1;
localparam int CRC_LSB = 0;

typedef struct packed {
  logic [HEAD_W-1:0]   head;
  logic [SENSOR_W-1:0] sensor;
  logic [TS_W-1:0]     ts;
  logic [DATA_W-1:0]   data;
  logic [FLAG_W-1:0]   flag;
  logic [CRC_W-1:0]    crc;
} packet_t;

typedef enum logic [SENSOR_W-1:0] {
  S_NONE    = 4'h0,
  S_ADS1115 = 4'h1,
  S_SHT30   = 4'h2,
  S_MPL3115 = 4'h3
} sensor_id_t;

`endif