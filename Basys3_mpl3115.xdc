## Clock: 100 MHz
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Reset button: BTNC
set_property PACKAGE_PIN U18 [get_ports reset_btn]
set_property IOSTANDARD LVCMOS33 [get_ports reset_btn]

## Pmod JA
## JA1 = SCL
set_property PACKAGE_PIN J1 [get_ports i2c_scl]
set_property IOSTANDARD LVCMOS33 [get_ports i2c_scl]

## JA2 = SDA
set_property PACKAGE_PIN L2 [get_ports i2c_sda]
set_property IOSTANDARD LVCMOS33 [get_ports i2c_sda]

## LEDs
set_property PACKAGE_PIN U16 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

set_property PACKAGE_PIN E19 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

set_property PACKAGE_PIN U19 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]

set_property PACKAGE_PIN V19 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]
