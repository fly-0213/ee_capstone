module mpl3115_test_top (
    input  logic clk,
    input  logic reset_btn,

    inout  wire  i2c_sda,
    output logic i2c_scl,

    output logic [3:0] led
);

    logic reset;
    assign reset = reset_btn;

    logic        start;
    logic        rw;
    logic [6:0]  dev_addr;
    logic [7:0]  reg_addr;
    logic [2:0]  num_bytes;
    logic [15:0] wdata;
    logic        use_reg_addr;

    logic [47:0] rdata;
    logic        busy;
    logic        done;
    logic        ack_error;

    logic        sda_in;
    logic        sda_oe;
    logic        sda_out_low;
    logic        scl_internal;

    // I2C SDA open-drain.
    // External pull-up resistor should pull SDA to 3.3V.
    assign i2c_sda = sda_oe ? 1'b0 : 1'bz;
    assign sda_in  = i2c_sda;

    // SCL from i2c_master.
    // In this design SCL is driven by FPGA.
    assign i2c_scl = scl_internal;

    i2c_master u_i2c_master (
        .clk          (clk),
        .reset        (reset),

        .start        (start),
        .rw           (rw),
        .dev_addr     (dev_addr),
        .reg_addr     (reg_addr),
        .num_bytes    (num_bytes),
        .wdata        (wdata),
        .use_reg_addr (use_reg_addr),

        .rdata        (rdata),
        .busy         (busy),
        .done         (done),
        .ack_error    (ack_error),

        .sda_in       (sda_in),
        .sda_oe       (sda_oe),
        .sda_out_low  (sda_out_low),
        .scl          (scl_internal)
    );

    mpl3115_test_ctrl u_mpl3115_test_ctrl (
        .clk          (clk),
        .reset        (reset),

        .start        (start),
        .rw           (rw),
        .dev_addr     (dev_addr),
        .reg_addr     (reg_addr),
        .num_bytes    (num_bytes),
        .wdata        (wdata),
        .use_reg_addr (use_reg_addr),

        .busy         (busy),
        .done         (done),
        .ack_error    (ack_error),
        .rdata        (rdata),

        .led          (led)
    );

endmodule