## Clock 100 MHz
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports clk]

## Buttons
## BTNC = reset
set_property PACKAGE_PIN U18 [get_ports reset_btn]
set_property IOSTANDARD LVCMOS33 [get_ports reset_btn]

## BTNU = start
set_property PACKAGE_PIN T18 [get_ports start_btn]
set_property IOSTANDARD LVCMOS33 [get_ports start_btn]

## BTND = stop
set_property PACKAGE_PIN U17 [get_ports stop_btn]
set_property IOSTANDARD LVCMOS33 [get_ports stop_btn]

## PMOD JA
## JA1 = SCL
set_property PACKAGE_PIN J1 [get_ports i2c_scl]
set_property IOSTANDARD LVCMOS33 [get_ports i2c_scl]

## JA2 = SDA
set_property PACKAGE_PIN L2 [get_ports i2c_sda]
set_property IOSTANDARD LVCMOS33 [get_ports i2c_sda]

## UART TX to USB-UART
set_property PACKAGE_PIN A18 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

## LED0 = system_busy
set_property PACKAGE_PIN U16 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]