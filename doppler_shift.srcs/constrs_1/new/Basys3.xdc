## Clock
set_property -dict { PACKAGE_PIN W5  IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Center button (reset)
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports reset]

## Pmod JA top row, line out
set_property -dict { PACKAGE_PIN J1  IOSTANDARD LVCMOS33 } [get_ports tx_mclk]
set_property -dict { PACKAGE_PIN L2  IOSTANDARD LVCMOS33 } [get_ports tx_lrck]
set_property -dict { PACKAGE_PIN J2  IOSTANDARD LVCMOS33 } [get_ports tx_sclk]
set_property -dict { PACKAGE_PIN G2  IOSTANDARD LVCMOS33 } [get_ports tx_data]

## Pmod JA bottom row, line in
set_property -dict { PACKAGE_PIN H1  IOSTANDARD LVCMOS33 } [get_ports rx_mclk]
set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports rx_lrck]
set_property -dict { PACKAGE_PIN H2  IOSTANDARD LVCMOS33 } [get_ports rx_sclk]
set_property -dict { PACKAGE_PIN G3  IOSTANDARD LVCMOS33 } [get_ports rx_data]

## Pitch buttons
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports btn_up]
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports btn_dn]

## Seven-segment cathodes
set_property -dict { PACKAGE_PIN W7 IOSTANDARD LVCMOS33 } [get_ports {seg[0]}]
set_property -dict { PACKAGE_PIN W6 IOSTANDARD LVCMOS33 } [get_ports {seg[1]}]
set_property -dict { PACKAGE_PIN U8 IOSTANDARD LVCMOS33 } [get_ports {seg[2]}]
set_property -dict { PACKAGE_PIN V8 IOSTANDARD LVCMOS33 } [get_ports {seg[3]}]
set_property -dict { PACKAGE_PIN U5 IOSTANDARD LVCMOS33 } [get_ports {seg[4]}]
set_property -dict { PACKAGE_PIN V5 IOSTANDARD LVCMOS33 } [get_ports {seg[5]}]
set_property -dict { PACKAGE_PIN U7 IOSTANDARD LVCMOS33 } [get_ports {seg[6]}]

## Seven-segment anodes
set_property -dict { PACKAGE_PIN U2 IOSTANDARD LVCMOS33 } [get_ports {an[0]}]
set_property -dict { PACKAGE_PIN U4 IOSTANDARD LVCMOS33 } [get_ports {an[1]}]
set_property -dict { PACKAGE_PIN V4 IOSTANDARD LVCMOS33 } [get_ports {an[2]}]
set_property -dict { PACKAGE_PIN W4 IOSTANDARD LVCMOS33 } [get_ports {an[3]}]

## QSPI flash boot
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]