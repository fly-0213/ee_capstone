module i2c_master (
    input  logic        clk,
    input  logic        reset,

    input  logic        start,
    input  logic        rw,           // 0=write, 1=read
    input  logic [6:0]  dev_addr,
    input  logic [7:0]  reg_addr,
    input  logic [1:0]  num_bytes,    // 1 or 2
    input  logic [15:0] wdata,

    output logic [15:0] rdata,
    output logic        busy,
    output logic        done,
    output logic        ack_error,

    inout  wire         sda,
    output logic        scl
);

endmodule