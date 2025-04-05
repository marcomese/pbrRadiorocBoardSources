## Timing constraints

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets usb_txe_IBUF]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets usb_rxf_IBUF]

## PHYSICAL CONSTRAINTS
# IO standards

set_property PULLUP true [get_ports sc_NORT1]
set_property PULLUP true [get_ports sc_clk_sm]

set_property IOSTANDARD LVDS_25 [get_ports ADC_*]
set_property IOSTANDARD LVCMOS25 [get_ports nCNV]
set_property IOSTANDARD LVCMOS25 [get_ports nCMOS]
#set_property IOSTANDARD LVCMOS18 [get_ports BP*]
#set_property IOSTANDARD LVCMOS18 [get_ports Input_clk*]
set_property IOSTANDARD LVCMOS33 [get_ports {IO_FPGA[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {IO_FPGA[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {IO_FPGA[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {IO_FPGA[2]}]

set_property IOSTANDARD LVDS_25 [get_ports {T_p[*]}]
set_property IOSTANDARD LVDS_25 [get_ports {T_n[*]}]
set_property IOSTANDARD LVDS_25 [get_ports CLK_*]
#set_property IOSTANDARD LVDS_25 [get_ports val_evt*]
#set_property IOSTANDARD LVDS_25 [get_ports LVDS_out_p]
set_property IOSTANDARD LVCMOS33 [get_ports usb*]
set_property IOSTANDARD LVCMOS33 [get_ports npwr_reset]
set_property IOSTANDARD LVCMOS33 [get_ports LED]
set_property IOSTANDARD LVCMOS33 [get_ports {IO_FPGA[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {IO_FPGA[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports SCL_275]
set_property IOSTANDARD LVCMOS33 [get_ports SDA_275]
set_property IOSTANDARD LVCMOS12 [get_ports sc_NORT1]
set_property IOSTANDARD LVCMOS12 [get_ports sc_NORT2]
set_property IOSTANDARD LVCMOS12 [get_ports sc_NORTQ]
set_property IOSTANDARD LVCMOS12 [get_ports sc_ck_read]
set_property IOSTANDARD LVCMOS12 [get_ports sc_clk_sm]
set_property IOSTANDARD LVCMOS12 [get_ports sc_errorb]
set_property IOSTANDARD LVCMOS12 [get_ports sc_holdext]
set_property IOSTANDARD LVCMOS12 [get_ports sc_outd_probe]
set_property IOSTANDARD LVCMOS12 [get_ports sc_reset_n]
set_property IOSTANDARD LVCMOS12 [get_ports sc_rstb_i2c]
set_property IOSTANDARD LVCMOS12 [get_ports sc_rstb_probe]
set_property IOSTANDARD LVCMOS12 [get_ports sc_rstb_sc]
set_property IOSTANDARD LVCMOS12 [get_ports sc_rstn_read]
set_property IOSTANDARD LVCMOS12 [get_ports sc_scl]
set_property IOSTANDARD LVCMOS12 [get_ports sc_sda]
set_property IOSTANDARD LVCMOS12 [get_ports sc_trigext]
set_property IOSTANDARD LVCMOS12 [get_ports sc_val_evt]
# set_property IOSTANDARD LVCMOS33 [get_ports {test[*]}]

# Package pins
# Clock capable pins (MRCC / SRCC)
set_property PACKAGE_PIN H4 [get_ports CLK_100M_p]
set_property PACKAGE_PIN G4 [get_ports CLK_100M_n]
#set_property PACKAGE_PIN  [get_ports Input_clk1]
#set_property PACKAGE_PIN  [get_ports Input_clk2]


# Others
set_property PACKAGE_PIN AB21 [get_ports npwr_reset]
# USB v0
set_property PACKAGE_PIN AB20 [get_ports usb_rxf]
set_property PACKAGE_PIN AA19 [get_ports usb_txe]
set_property PACKAGE_PIN P16 [get_ports {usb[0]}]
set_property PACKAGE_PIN U20 [get_ports {usb[1]}]
set_property PACKAGE_PIN V20 [get_ports {usb[2]}]
set_property PACKAGE_PIN W19 [get_ports {usb[3]}]
set_property PACKAGE_PIN Y21 [get_ports {usb[4]}]
set_property PACKAGE_PIN AA21 [get_ports {usb[5]}]
set_property PACKAGE_PIN T20 [get_ports {usb[6]}]
set_property PACKAGE_PIN AA20 [get_ports {usb[7]}]
set_property PACKAGE_PIN N13 [get_ports usb_rd]
set_property PACKAGE_PIN Y19 [get_ports usb_wr]
#set_property PACKAGE_PIN R16 [get_ports usb_xtin]
set_property PACKAGE_PIN Y18 [get_ports usb_noe]
set_property PACKAGE_PIN AB18 [get_ports usb_siwu]

#RADIOROC
set_property PACKAGE_PIN U15 [get_ports sc_scl]
set_property PACKAGE_PIN Y17 [get_ports sc_sda]
set_property PACKAGE_PIN V15 [get_ports sc_clk_sm]
set_property PACKAGE_PIN T16 [get_ports sc_val_evt]
set_property PACKAGE_PIN V14 [get_ports sc_errorb]
set_property PACKAGE_PIN T14 [get_ports sc_rstn_read]
set_property PACKAGE_PIN T15 [get_ports sc_ck_read]
set_property PACKAGE_PIN AA16 [get_ports sc_reset_n]
set_property PACKAGE_PIN U16 [get_ports sc_rstb_sc]
set_property PACKAGE_PIN Y16 [get_ports sc_rstb_probe]
set_property PACKAGE_PIN W16 [get_ports sc_rstb_i2c]
set_property PACKAGE_PIN W12 [get_ports sc_outd_probe]
set_property PACKAGE_PIN Y12 [get_ports sc_holdext]
set_property PACKAGE_PIN Y11 [get_ports sc_trigext]
set_property PACKAGE_PIN AB10 [get_ports sc_NORT2]
set_property PACKAGE_PIN W11 [get_ports sc_NORT1]
set_property PACKAGE_PIN AA9 [get_ports sc_NORTQ]




set_property PACKAGE_PIN F19 [get_ports {T_p[63]}]
set_property PACKAGE_PIN F20 [get_ports {T_n[63]}]

set_property PACKAGE_PIN N20 [get_ports {T_p[62]}]
set_property PACKAGE_PIN M20 [get_ports {T_n[62]}]

set_property PACKAGE_PIN E21 [get_ports {T_p[61]}]
set_property PACKAGE_PIN D21 [get_ports {T_n[61]}]

set_property PACKAGE_PIN M18 [get_ports {T_p[60]}]
set_property PACKAGE_PIN L18 [get_ports {T_n[60]}]

set_property PACKAGE_PIN C18 [get_ports {T_p[59]}]
set_property PACKAGE_PIN C19 [get_ports {T_n[59]}]

set_property PACKAGE_PIN L16 [get_ports {T_p[58]}]
set_property PACKAGE_PIN K16 [get_ports {T_n[58]}]

set_property PACKAGE_PIN E16 [get_ports {T_p[57]}]
set_property PACKAGE_PIN D16 [get_ports {T_n[57]}]

set_property PACKAGE_PIN D20 [get_ports {T_p[56]}]
set_property PACKAGE_PIN C20 [get_ports {T_n[56]}]

set_property PACKAGE_PIN K18 [get_ports {T_p[55]}]
set_property PACKAGE_PIN K19 [get_ports {T_n[55]}]

set_property PACKAGE_PIN L19 [get_ports {T_p[54]}]
set_property PACKAGE_PIN L20 [get_ports {T_n[54]}]

set_property PACKAGE_PIN G21 [get_ports {T_p[53]}]
set_property PACKAGE_PIN G22 [get_ports {T_n[53]}]

set_property PACKAGE_PIN E22 [get_ports {T_p[52]}]
set_property PACKAGE_PIN D22 [get_ports {T_n[52]}]

set_property PACKAGE_PIN B21 [get_ports {T_p[51]}]
set_property PACKAGE_PIN A21 [get_ports {T_n[51]}]

set_property PACKAGE_PIN J20 [get_ports {T_p[50]}]
set_property PACKAGE_PIN J21 [get_ports {T_n[50]}]

set_property PACKAGE_PIN J14 [get_ports {T_p[49]}]
set_property PACKAGE_PIN H14 [get_ports {T_n[49]}]

set_property PACKAGE_PIN H17 [get_ports {T_p[48]}]
set_property PACKAGE_PIN H18 [get_ports {T_n[48]}]

set_property PACKAGE_PIN G17 [get_ports {T_p[47]}]
set_property PACKAGE_PIN G18 [get_ports {T_n[47]}]

set_property PACKAGE_PIN E19 [get_ports {T_p[46]}]
set_property PACKAGE_PIN D19 [get_ports {T_n[46]}]

set_property PACKAGE_PIN B20 [get_ports {T_p[45]}]
set_property PACKAGE_PIN A20 [get_ports {T_n[45]}]

set_property PACKAGE_PIN K17 [get_ports {T_p[44]}]
set_property PACKAGE_PIN J17 [get_ports {T_n[44]}]

set_property PACKAGE_PIN C22 [get_ports {T_p[43]}]
set_property PACKAGE_PIN B22 [get_ports {T_n[43]}]

set_property PACKAGE_PIN D17 [get_ports {T_p[42]}]
set_property PACKAGE_PIN C17 [get_ports {T_n[42]}]

set_property PACKAGE_PIN G15 [get_ports {T_p[41]}]
set_property PACKAGE_PIN G16 [get_ports {T_n[41]}]

set_property PACKAGE_PIN F18 [get_ports {T_p[40]}]
set_property PACKAGE_PIN E18 [get_ports {T_n[40]}]

set_property PACKAGE_PIN A15 [get_ports {T_p[39]}]
set_property PACKAGE_PIN A16 [get_ports {T_n[39]}]

set_property PACKAGE_PIN D14 [get_ports {T_p[38]}]
set_property PACKAGE_PIN D15 [get_ports {T_n[38]}]

set_property PACKAGE_PIN A18 [get_ports {T_p[37]}]
set_property PACKAGE_PIN A19 [get_ports {T_n[37]}]

set_property PACKAGE_PIN J15 [get_ports {T_p[36]}]
set_property PACKAGE_PIN H15 [get_ports {T_n[36]}]

set_property PACKAGE_PIN B17 [get_ports {T_p[35]}]
set_property PACKAGE_PIN B18 [get_ports {T_n[35]}]

set_property PACKAGE_PIN E13 [get_ports {T_p[34]}]
set_property PACKAGE_PIN E14 [get_ports {T_n[34]}]

set_property PACKAGE_PIN B15 [get_ports {T_p[33]}]
set_property PACKAGE_PIN B16 [get_ports {T_n[33]}]

set_property PACKAGE_PIN F16 [get_ports {T_p[32]}]
set_property PACKAGE_PIN E17 [get_ports {T_n[32]}]

set_property PACKAGE_PIN H13 [get_ports {T_p[31]}]
set_property PACKAGE_PIN G13 [get_ports {T_n[31]}]

set_property PACKAGE_PIN F13 [get_ports {T_p[30]}]
set_property PACKAGE_PIN F14 [get_ports {T_n[30]}]

set_property PACKAGE_PIN A13 [get_ports {T_p[29]}]
set_property PACKAGE_PIN A14 [get_ports {T_n[29]}]

set_property PACKAGE_PIN M15 [get_ports {T_p[28]}]
set_property PACKAGE_PIN M16 [get_ports {T_n[28]}]

set_property PACKAGE_PIN M13 [get_ports {T_p[27]}]
set_property PACKAGE_PIN L13 [get_ports {T_n[27]}]

set_property PACKAGE_PIN L14 [get_ports {T_p[26]}]
set_property PACKAGE_PIN L15 [get_ports {T_n[26]}]

set_property PACKAGE_PIN M6 [get_ports {T_p[25]}]
set_property PACKAGE_PIN M5 [get_ports {T_n[25]}]

set_property PACKAGE_PIN C14 [get_ports {T_p[24]}]
set_property PACKAGE_PIN C15 [get_ports {T_n[24]}]

set_property PACKAGE_PIN K6 [get_ports {T_p[23]}]
set_property PACKAGE_PIN J6 [get_ports {T_n[23]}]

set_property PACKAGE_PIN C2 [get_ports {T_p[22]}]
set_property PACKAGE_PIN B2 [get_ports {T_n[22]}]

set_property PACKAGE_PIN N18 [get_ports {T_p[21]}]
set_property PACKAGE_PIN N19 [get_ports {T_n[21]}]

set_property PACKAGE_PIN C13 [get_ports {T_p[20]}]
set_property PACKAGE_PIN B13 [get_ports {T_n[20]}]

set_property PACKAGE_PIN H3 [get_ports {T_p[19]}]
set_property PACKAGE_PIN G3 [get_ports {T_n[19]}]

set_property PACKAGE_PIN J5 [get_ports {T_p[18]}]
set_property PACKAGE_PIN H5 [get_ports {T_n[18]}]

set_property PACKAGE_PIN E1 [get_ports {T_p[17]}]
set_property PACKAGE_PIN D1 [get_ports {T_n[17]}]

set_property PACKAGE_PIN K13 [get_ports {T_p[16]}]
set_property PACKAGE_PIN K14 [get_ports {T_n[16]}]

set_property PACKAGE_PIN G1 [get_ports {T_p[15]}]
set_property PACKAGE_PIN F1 [get_ports {T_n[15]}]

set_property PACKAGE_PIN B1 [get_ports {T_p[14]}]
set_property PACKAGE_PIN A1 [get_ports {T_n[14]}]

set_property PACKAGE_PIN H2 [get_ports {T_p[13]}]
set_property PACKAGE_PIN G2 [get_ports {T_n[13]}]

set_property PACKAGE_PIN L5 [get_ports {T_p[12]}]
set_property PACKAGE_PIN L4 [get_ports {T_n[12]}]

set_property PACKAGE_PIN F3 [get_ports {T_p[11]}]
set_property PACKAGE_PIN E3 [get_ports {T_n[11]}]

set_property PACKAGE_PIN K2 [get_ports {T_p[10]}]
set_property PACKAGE_PIN J2 [get_ports {T_n[10]}]

set_property PACKAGE_PIN E2 [get_ports {T_p[9]}]
set_property PACKAGE_PIN D2 [get_ports {T_n[9]}]

set_property PACKAGE_PIN M1 [get_ports {T_p[8]}]
set_property PACKAGE_PIN L1 [get_ports {T_n[8]}]

set_property PACKAGE_PIN K1 [get_ports {T_p[7]}]
set_property PACKAGE_PIN J1 [get_ports {T_n[7]}]

set_property PACKAGE_PIN K4 [get_ports {T_p[6]}]
set_property PACKAGE_PIN J4 [get_ports {T_n[6]}]

set_property PACKAGE_PIN R1 [get_ports {T_p[5]}]
set_property PACKAGE_PIN P1 [get_ports {T_n[5]}]

set_property PACKAGE_PIN M3 [get_ports {T_p[4]}]
set_property PACKAGE_PIN M2 [get_ports {T_n[4]}]

set_property PACKAGE_PIN L3 [get_ports {T_p[3]}]
set_property PACKAGE_PIN K3 [get_ports {T_n[3]}]

set_property PACKAGE_PIN P2 [get_ports {T_p[2]}]
set_property PACKAGE_PIN N2 [get_ports {T_n[2]}]

set_property PACKAGE_PIN N4 [get_ports {T_p[1]}]
set_property PACKAGE_PIN N3 [get_ports {T_n[1]}]

set_property PACKAGE_PIN P5 [get_ports {T_p[0]}]
set_property PACKAGE_PIN P4 [get_ports {T_n[0]}]


# ADC
set_property PACKAGE_PIN J19 [get_ports ADC_SCKHG_p]
set_property PACKAGE_PIN H19 [get_ports ADC_SCKHG_n]
set_property PACKAGE_PIN M21 [get_ports ADC_SCKLG_p]
set_property PACKAGE_PIN L21 [get_ports ADC_SCKLG_n]
set_property PACKAGE_PIN K21 [get_ports ADC_HG_p]
set_property PACKAGE_PIN K22 [get_ports ADC_HG_n]
set_property PACKAGE_PIN N22 [get_ports ADC_LG_p]
set_property PACKAGE_PIN M22 [get_ports ADC_LG_n]
set_property PACKAGE_PIN J16 [get_ports nCNV]
set_property PACKAGE_PIN M17 [get_ports nCMOS]

set_property PACKAGE_PIN W22 [get_ports SCL_275]
set_property PACKAGE_PIN Y22 [get_ports SDA_275]

# User debug
#set_property PACKAGE_PIN  [get_ports BP1]
#set_property PACKAGE_PIN  [get_ports BP0]
set_property PACKAGE_PIN Y2 [get_ports {IO_FPGA[5]}]
set_property PACKAGE_PIN AB2 [get_ports {IO_FPGA[4]}]
set_property PACKAGE_PIN R2 [get_ports {IO_FPGA[3]}]
set_property PACKAGE_PIN R3 [get_ports {IO_FPGA[2]}]
set_property PACKAGE_PIN V2 [get_ports {IO_FPGA[1]}]
set_property PACKAGE_PIN AA3 [get_ports {IO_FPGA[0]}]
set_property PACKAGE_PIN W1 [get_ports LED]

set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN AA5} [get_ports pulse]

set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN W9} [get_ports uartRx]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN Y9} [get_ports uartTx]

set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN R14} [get_ports extTrg]

set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN Y4} [get_ports initDone]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN AA4} [get_ports busy]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN AB5} [get_ports running]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN R17} [get_ports dacSDI]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN U17} [get_ports dacSCLK]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN U18} [get_ports dacCS]

set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN Y3} [get_ports readRq]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN V4} [get_ports cs]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN W2} [get_ports sclk]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN R4} [get_ports mosi]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN U2} [get_ports miso]

set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]



create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 65536 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list pll1/inst/clk_out4]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 8 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {radInterfInst/radioFSMInst/dataOut[0]} {radInterfInst/radioFSMInst/dataOut[1]} {radInterfInst/radioFSMInst/dataOut[2]} {radInterfInst/radioFSMInst/dataOut[3]} {radInterfInst/radioFSMInst/dataOut[4]} {radInterfInst/radioFSMInst/dataOut[5]} {radInterfInst/radioFSMInst/dataOut[6]} {radInterfInst/radioFSMInst/dataOut[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 3 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {radInterfInst/radioFSMInst/state[0]} {radInterfInst/radioFSMInst/state[1]} {radInterfInst/radioFSMInst/state[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 2 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {radInterfInst/state[0]} {radInterfInst/state[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 8 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {radInterfInst/radioFSMInst/dataIn[0]} {radInterfInst/radioFSMInst/dataIn[1]} {radInterfInst/radioFSMInst/dataIn[2]} {radInterfInst/radioFSMInst/dataIn[3]} {radInterfInst/radioFSMInst/dataIn[4]} {radInterfInst/radioFSMInst/dataIn[5]} {radInterfInst/radioFSMInst/dataIn[6]} {radInterfInst/radioFSMInst/dataIn[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 8 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {radInterfInst/radioFSMInst/i2cDataRd[0]} {radInterfInst/radioFSMInst/i2cDataRd[1]} {radInterfInst/radioFSMInst/i2cDataRd[2]} {radInterfInst/radioFSMInst/i2cDataRd[3]} {radInterfInst/radioFSMInst/i2cDataRd[4]} {radInterfInst/radioFSMInst/i2cDataRd[5]} {radInterfInst/radioFSMInst/i2cDataRd[6]} {radInterfInst/radioFSMInst/i2cDataRd[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 8 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {radInterfInst/radioFSMInst/i2cDataWr[0]} {radInterfInst/radioFSMInst/i2cDataWr[1]} {radInterfInst/radioFSMInst/i2cDataWr[2]} {radInterfInst/radioFSMInst/i2cDataWr[3]} {radInterfInst/radioFSMInst/i2cDataWr[4]} {radInterfInst/radioFSMInst/i2cDataWr[5]} {radInterfInst/radioFSMInst/i2cDataWr[6]} {radInterfInst/radioFSMInst/i2cDataWr[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 16 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {radInterfInst/radioFSMInst/addr[0]} {radInterfInst/radioFSMInst/addr[1]} {radInterfInst/radioFSMInst/addr[2]} {radInterfInst/radioFSMInst/addr[3]} {radInterfInst/radioFSMInst/addr[4]} {radInterfInst/radioFSMInst/addr[5]} {radInterfInst/radioFSMInst/addr[6]} {radInterfInst/radioFSMInst/addr[7]} {radInterfInst/radioFSMInst/addr[8]} {radInterfInst/radioFSMInst/addr[9]} {radInterfInst/radioFSMInst/addr[10]} {radInterfInst/radioFSMInst/addr[11]} {radInterfInst/radioFSMInst/addr[12]} {radInterfInst/radioFSMInst/addr[13]} {radInterfInst/radioFSMInst/addr[14]} {radInterfInst/radioFSMInst/addr[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 7 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {radInterfInst/radioFSMInst/i2cAddr[0]} {radInterfInst/radioFSMInst/i2cAddr[1]} {radInterfInst/radioFSMInst/i2cAddr[2]} {radInterfInst/radioFSMInst/i2cAddr[3]} {radInterfInst/radioFSMInst/i2cAddr[4]} {radInterfInst/radioFSMInst/i2cAddr[5]} {radInterfInst/radioFSMInst/i2cAddr[6]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 8 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {spiSlaveInst/buffOut[0]} {spiSlaveInst/buffOut[1]} {spiSlaveInst/buffOut[2]} {spiSlaveInst/buffOut[3]} {spiSlaveInst/buffOut[4]} {spiSlaveInst/buffOut[5]} {spiSlaveInst/buffOut[6]} {spiSlaveInst/buffOut[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 8 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {spiSlaveInst/buffIn[0]} {spiSlaveInst/buffIn[1]} {spiSlaveInst/buffIn[2]} {spiSlaveInst/buffIn[3]} {spiSlaveInst/buffIn[4]} {spiSlaveInst/buffIn[5]} {spiSlaveInst/buffIn[6]} {spiSlaveInst/buffIn[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list radInterfInst/dataReady]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list radInterfInst/radioFSMInst/exec]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list radInterfInst/radioFSMInst/i2cBusy]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list radInterfInst/radioFSMInst/i2cEna]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list radInterfInst/radioFSMInst/i2cRw]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_100M]
