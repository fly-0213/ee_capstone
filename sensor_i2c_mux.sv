`include "packet_defs.svh"
module sensor_i2c_mux(
    input  logic        clk,
    input  logic        reset,

    input logic [$clog2(SENS_NUM)-1:0]sens_id,

    input  logic sda_in,
    output logic sda_oe,
    output logic sda_out_low,
    output logic scl,

    input  logic        ads_i2c_start,
    input  logic        ads_i2c_rw,
    input  logic [6:0]  ads_i2c_dev_addr,
    input  logic [7:0]  ads_i2c_reg_addr,
    input  logic [1:0]  ads_i2c_num_bytes,
    input  logic [15:0] ads_i2c_wdata,

    output logic        ads_i2c_busy,
    output logic        ads_i2c_done,
    output logic [15:0] ads_i2c_rdata,
    output logic        ads_i2c_ack_error,

    output logic        sht_i2c_busy,
    output logic        sht_i2c_done,
    output logic [47:0] sht_i2c_rdata,
    output logic        sht_i2c_ack_error,

    input  logic        sht_i2c_start,
    input  logic        sht_i2c_rw,      
    input  logic [6:0]  sht_i2c_dev_addr,
    input  logic [2:0]  sht_i2c_num_bytes,   
    input  logic [15:0] sht_i2c_wdata,

    output logic        mpl_i2c_busy,
    output logic        mpl_i2c_done,
    output logic [39:0] mpl_i2c_rdata,
    output logic        mpl_i2c_ack_error,

    input  logic        mpl_i2c_start,
    input  logic        mpl_i2c_rw,         
    input  logic [6:0]  mpl_i2c_dev_addr,
    input  logic [7:0]  mpl_i2c_reg_addr,
    input  logic [2:0]  mpl_i2c_num_bytes,   
    input  logic [7:0]  mpl_i2c_wdata
);

    logic        mas_start;
    logic        mas_rw;           
    logic [6:0]  mas_dev_addr;
    logic [7:0]  mas_reg_addr;
    logic [2:0]  mas_num_bytes;    
    logic [15:0] mas_wdata;
    logic        mas_use_reg_addr;

    logic [47:0] mas_rdata;
    logic        mas_busy;
    logic        mas_done;
    logic        mas_ack_error;

    logic        mas_sda_in;
    logic        mas_sda_oe;
    logic        mas_sda_out_low;
    logic        mas_scl;

    i2c_master u_i2c_master(
        .clk(clk),
        .reset(reset),

        .start(mas_start),
        .rw(mas_rw),          
        .dev_addr(mas_dev_addr),
        .reg_addr(mas_reg_addr),
        .num_bytes(mas_num_bytes),    
        .wdata(mas_wdata),
        .use_reg_addr(mas_use_reg_addr),

        .rdata(mas_rdata),
        .busy(mas_busy),
        .done(mas_done),
        .ack_error(mas_ack_error),

        .sda_in(mas_sda_in),
        .sda_oe(mas_sda_oe),
        .sda_out_low(mas_sda_out_low),
        .scl(mas_scl)
    );

    assign mas_sda_in   = sda_in;
    assign sda_oe       = mas_sda_oe;
    assign sda_out_low  = mas_sda_out_low;
    assign scl          = mas_scl;

    always_comb begin
        mas_start = '0;
        mas_rw = '0;
        mas_dev_addr = '0;
        mas_reg_addr = '0;
        mas_num_bytes = '0; 
        mas_wdata = '0;
        mas_use_reg_addr = '0;
        case(sens_id)
            S_ADS1115: begin
                mas_start = ads_i2c_start;
                mas_rw = ads_i2c_rw;    
                mas_dev_addr = ads_i2c_dev_addr;
                mas_reg_addr = ads_i2c_reg_addr;
                mas_num_bytes = {1'b0, ads_i2c_num_bytes}; 
                mas_wdata = ads_i2c_wdata;
                mas_use_reg_addr = 1'b1;
            end
            S_SHT30: begin
                mas_start = sht_i2c_start;
                mas_rw = sht_i2c_rw;    
                mas_dev_addr = sht_i2c_dev_addr;
                mas_reg_addr = '0;
                mas_num_bytes = sht_i2c_num_bytes;   
                mas_wdata = sht_i2c_wdata;
                mas_use_reg_addr = 1'b0;
            end 
            S_MPL3115: begin
                mas_start = mpl_i2c_start;
                mas_rw = mpl_i2c_rw;    
                mas_dev_addr = mpl_i2c_dev_addr;
                mas_reg_addr = mpl_i2c_reg_addr;
                mas_num_bytes = mpl_i2c_num_bytes; 
                mas_wdata = {8'b0, mpl_i2c_wdata};
                mas_use_reg_addr = 1'b1;
            end 
            default: begin
                mas_start = 0;
                mas_rw = 0;   
                mas_dev_addr = 0;
                mas_reg_addr = 0;
                mas_num_bytes = 0;
                mas_wdata = 0;
                mas_use_reg_addr = 0;
            end 
        endcase
    end 

    always_comb begin
        ads_i2c_busy      = 1'b0;
        ads_i2c_done      = 1'b0;
        ads_i2c_rdata     = '0;
        ads_i2c_ack_error = 1'b0;

        sht_i2c_busy      = 1'b0;
        sht_i2c_done      = 1'b0;
        sht_i2c_rdata     = '0;
        sht_i2c_ack_error = 1'b0;

        mpl_i2c_busy      = 1'b0;
        mpl_i2c_done      = 1'b0;
        mpl_i2c_rdata     = '0;
        mpl_i2c_ack_error = 1'b0;
        case(sens_id)
            S_ADS1115: begin
                ads_i2c_busy = mas_busy;
                ads_i2c_done = mas_done;    
                ads_i2c_rdata = mas_rdata[15:0];
                ads_i2c_ack_error = mas_ack_error;
            end
            S_SHT30: begin
                sht_i2c_busy = mas_busy;
                sht_i2c_done = mas_done;        
                sht_i2c_rdata = mas_rdata[47:0];
                sht_i2c_ack_error = mas_ack_error;
            end 
            S_MPL3115: begin
                mpl_i2c_busy = mas_busy;
                mpl_i2c_done = mas_done;    
                mpl_i2c_rdata = mas_rdata[39:0];
                mpl_i2c_ack_error = mas_ack_error;
            end 
        endcase  
    end 

endmodule