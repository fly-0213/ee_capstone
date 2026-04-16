`timescale 1ns/100ps

module mock_tb;

  // -----------------------------
  // Params
  // -----------------------------
  localparam int DATA_W  = 52;
  localparam int I2C_LAT = 6;

  // -----------------------------
  // Signals
  // -----------------------------
  logic clk;
  logic reset;

  // ADC side (temp/light)
  logic req_adc;
  logic valid_adc;
  logic busy_adc;
  logic [DATA_W-1:0] data_adc;

  // I2C side (humidity/pressure)
  logic req_i2c;
  logic valid_i2c;
  logic busy_i2c;
  logic [DATA_W-1:0] data_i2c;

  // -----------------------------
  // Clock: 100MHz (10ns period)
  // -----------------------------
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // -----------------------------
  // DUTs
  // -----------------------------
  mock_adc #(.DATA_W(DATA_W)) u_adc (
    .clk   (clk),
    .reset (reset),
    .req   (req_adc),
    .valid (valid_adc),
    .data  (data_adc),
    .busy  (busy_adc)
  );

  mock_i2c #(.DATA_W(DATA_W), .LAT(I2C_LAT)) u_i2c (
    .clk   (clk),
    .reset (reset),
    .req   (req_i2c),
    .valid (valid_i2c),
    .data  (data_i2c),
    .busy  (busy_i2c)
  );

  // -----------------------------
  // FSDB dump for Verdi
  // -----------------------------
  //initial begin
  //  $fsdbDumpfile("mock.fsdb");
  //  $fsdbDumpvars(0, mock_tb);
  //end

  // -----------------------------
  // Simple tasks: pulse req 1-cycle
  // -----------------------------
  task automatic pulse_req_adc();
    begin
      @(posedge clk);
      req_adc <= 1'b1;
      @(posedge clk);
      req_adc <= 1'b0;
    end
  endtask

  task automatic pulse_req_i2c();
    begin
      @(posedge clk);
      req_i2c <= 1'b1;
      @(posedge clk);
      req_i2c <= 1'b0;
    end
  endtask

  // -----------------------------
  // Scoreboard-ish checks
  // -----------------------------
  logic [DATA_W-1:0] last_adc_data;
  logic [DATA_W-1:0] last_i2c_data;

  // ADC: each valid，data + 1
  always_ff @(posedge clk) begin
    if (reset) begin
      last_adc_data <= '0;
    end else if (valid_adc) begin
      assert( (data_adc == last_adc_data) || (data_adc == last_adc_data + 1) )
        else $error("ADC data unexpected. data=%0d last=%0d", data_adc, last_adc_data);
      last_adc_data <= data_adc;
    end
  end

  // I2C: each valid，data +16
  always_ff @(posedge clk) begin
    if (reset) begin
      last_i2c_data <= '0;
    end else if (valid_i2c) begin
      assert( (data_i2c == last_i2c_data) || (data_i2c == last_i2c_data + 16) )
        else $error("I2C data unexpected. data=%0d last=%0d", data_i2c, last_i2c_data);
      last_i2c_data <= data_i2c;
    end
  end

  logic req_i2c_d;

    always_ff @(posedge clk) begin
        if (reset) begin
            req_i2c_d <= 0;
        end else begin
            req_i2c_d <= req_i2c;

            if (req_i2c_d) begin
                assert(busy_i2c == 1'b1)
                    else $error("I2C busy didn't assert after req");
            end
        end
    end

  // -----------------------------
  // Stimulus
  // -----------------------------
  initial begin
    // init
    reset   = 1'b1;
    req_adc = 1'b0;
    req_i2c = 1'b0;

    // hold reset a few cycles
    repeat (3) @(posedge clk);
    reset = 1'b0;

    // ADC：each 8 beat per time
    // I2C：each 25 beat per time
    fork
      begin : ADC_DRIVER
        repeat (6) begin
          pulse_req_adc();
          repeat (8) @(posedge clk);
        end
      end

      begin : I2C_DRIVER
        repeat (4) begin
          pulse_req_i2c();
          repeat (25) @(posedge clk);
        end
      end
    join

    // run extra cycles to let last transactions finish
    repeat (50) @(posedge clk);

    $display("mock_tb finished.");
    $finish;
  end

endmodule