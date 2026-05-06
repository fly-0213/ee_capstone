module pin_test_top (
    input  logic clk,
    input  logic btnC,
    inout  tri   i2c_sda,
    inout  tri   i2c_scl,
    output logic [1:0] led
);

    // release both I2C lines
    assign i2c_sda = 1'bz;
    assign i2c_scl = 1'bz;

    assign led[0] = i2c_sda;
    assign led[1] = i2c_scl;

endmodule