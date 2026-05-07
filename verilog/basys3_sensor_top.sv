module basys3_sensor_top (
    input  logic clk,
    input  logic reset_btn,
    input  logic start_btn,
    input  logic stop_btn,

    inout  wire  i2c_sda,
    output logic i2c_scl,

    output logic uart_tx,
    output logic [0:0] led
);

    logic i2c_sda_in;
    logic i2c_sda_oe;
    logic i2c_sda_out_low;
    logic system_busy;

    assign i2c_sda = (!reset_btn && i2c_sda_oe && i2c_sda_out_low) ? 1'b0 : 1'bz;
    assign i2c_sda_in = i2c_sda;

    sensor_fpga_top u_sensor_fpga_top (
        .clk(clk),
        .reset(reset_btn),

        .start_pulse(start_btn),
        .stop_pulse(stop_btn),

        .i2c_sda_in(i2c_sda_in),
        .i2c_sda_oe(i2c_sda_oe),
        .i2c_sda_out_low(i2c_sda_out_low),
        .i2c_scl(i2c_scl),

        .uart_tx(uart_tx),
        .system_busy(system_busy)
    );

    assign led[0] = system_busy;

endmodule