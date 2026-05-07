`include "packet_defs.svh"
module sensor_result_mux(
    input logic [$clog2(SENS_NUM)-1:0]sens_id,

    input  logic        ads_data_valid,
    input  logic        ads_error,
    input  logic [15:0] ads_data_out,

    input  logic        sht_data_valid,
    input  logic        sht_error,      
    input  logic [15:0] sht_temp_raw,
    input  logic [15:0] sht_hum_raw,

    input  logic        mpl_data_valid,
    input  logic        mpl_error,         
    input  logic [19:0]  mpl_pressure_raw,
    input  logic [11:0]  mpl_temp_raw,

    output logic        result_valid,
    output logic [$clog2(SENS_NUM)-1:0] result_sensor_id,
    output logic [DATA_W-1:0] result_data,
    output logic        result_error
);

    localparam int ADS_W = 16;
    localparam int SHT_W = 32;
    localparam int MPL_W = 32;

    always_comb begin
        result_valid     = 1'b0;
        result_sensor_id = sens_id;
        result_data      = '0;
        result_error     = 1'b0;

        case (sens_id)
            S_ADS1115: begin
            /*
                result_valid = ads_data_valid;
                result_data = {{(DATA_W-ADS_W){1'b0}}, ads_data_out};
                result_error = ads_error;
            */
                result_valid = 1'b0;
                result_data  = '0;
                result_error = 1'b0;
            end

            S_SHT30: begin
                result_valid = sht_data_valid;
                result_data = {{(DATA_W-SHT_W){1'b0}}, sht_temp_raw, sht_hum_raw};
                result_error = sht_error;
            end

            S_MPL3115: begin
                result_valid = mpl_data_valid;
                result_data = {{(DATA_W-MPL_W){1'b0}}, mpl_pressure_raw, mpl_temp_raw};
                result_error = mpl_error;
            end
        endcase
    end

endmodule