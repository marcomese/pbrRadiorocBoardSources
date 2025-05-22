## Timing constraints

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets usb_txe_IBUF]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets usb_rxf_IBUF]

## PHYSICAL CONSTRAINTS
# IO standards

set_property PULLTYPE PULLUP [get_ports sc_NORT1]
set_property PULLTYPE PULLUP [get_ports sc_clk_sm]

set_property IOSTANDARD LVDS_25 [get_ports ADC_*]
set_property IOSTANDARD LVCMOS25 [get_ports nCNV]
set_property IOSTANDARD LVCMOS25 [get_ports nCMOS]
#set_property IOSTANDARD LVCMOS18 [get_ports BP*]
#set_property IOSTANDARD LVCMOS18 [get_ports Input_clk*]
set_property IOSTANDARD LVCMOS25 [get_ports {IO_FPGA[5]}]
set_property IOSTANDARD LVCMOS25 [get_ports {IO_FPGA[4]}]
set_property IOSTANDARD LVCMOS25 [get_ports {IO_FPGA[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {IO_FPGA[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {IO_FPGA[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {IO_FPGA[0]}]

set_property IOSTANDARD LVDS_25 [get_ports {T_p[*]}]
set_property IOSTANDARD LVDS_25 [get_ports {T_n[*]}]
set_property IOSTANDARD LVDS_25 [get_ports CLK_*]
#set_property IOSTANDARD LVDS_25 [get_ports val_evt*]
#set_property IOSTANDARD LVDS_25 [get_ports LVDS_out_p]
set_property IOSTANDARD LVCMOS33 [get_ports usb*]
set_property IOSTANDARD LVCMOS33 [get_ports npwr_reset]
set_property IOSTANDARD LVCMOS33 [get_ports LED]
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
set_property PACKAGE_PIN Y8 [get_ports {IO_FPGA[5]}]
set_property PACKAGE_PIN AB2 [get_ports {IO_FPGA[4]}]
set_property PACKAGE_PIN R2 [get_ports {IO_FPGA[3]}]
set_property PACKAGE_PIN R3 [get_ports {IO_FPGA[2]}]
set_property PACKAGE_PIN Y7 [get_ports {IO_FPGA[1]}]
set_property PACKAGE_PIN W9 [get_ports {IO_FPGA[0]}]
set_property PACKAGE_PIN AB22 [get_ports LED]

set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN AA5} [get_ports pulse]

set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN R14} [get_ports extTrg]

set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN R17} [get_ports dacSDI]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN U17} [get_ports dacSCLK]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN U18} [get_ports dacCS]

set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN Y3} [get_ports readRq_p]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN V4} [get_ports sclk_p]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN W2} [get_ports cs_p]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN R4} [get_ports miso_p]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN U2} [get_ports mosi_p]

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
connect_debug_port u_ila_0/probe0 [get_nets [list {devAddr[0][0]} {devAddr[0][1]} {devAddr[0][2]} {devAddr[0][3]} {devAddr[0][4]} {devAddr[0][5]} {devAddr[0][6]} {devAddr[0][7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 8 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {devAddr[1][0]} {devAddr[1][1]} {devAddr[1][2]} {devAddr[1][3]} {devAddr[1][4]} {devAddr[1][5]} {devAddr[1][6]} {devAddr[1][7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 3 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {devId[0]} {devId[1]} {devId[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 8 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {dataFromRadioroc[0][0]} {dataFromRadioroc[0][1]} {dataFromRadioroc[0][2]} {dataFromRadioroc[0][3]} {dataFromRadioroc[0][4]} {dataFromRadioroc[0][5]} {dataFromRadioroc[0][6]} {dataFromRadioroc[0][7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 8 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {dataFromRadioroc[3][0]} {dataFromRadioroc[3][1]} {dataFromRadioroc[3][2]} {dataFromRadioroc[3][3]} {dataFromRadioroc[3][4]} {dataFromRadioroc[3][5]} {dataFromRadioroc[3][6]} {dataFromRadioroc[3][7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 8 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {dataToMaster[0]} {dataToMaster[1]} {dataToMaster[2]} {dataToMaster[3]} {dataToMaster[4]} {dataToMaster[5]} {dataToMaster[6]} {dataToMaster[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 8 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {dataToDev[1][0]} {dataToDev[1][1]} {dataToDev[1][2]} {dataToDev[1][3]} {dataToDev[1][4]} {dataToDev[1][5]} {dataToDev[1][6]} {dataToDev[1][7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 8 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {dataFromMaster[0]} {dataFromMaster[1]} {dataFromMaster[2]} {dataFromMaster[3]} {dataFromMaster[4]} {dataFromMaster[5]} {dataFromMaster[6]} {dataFromMaster[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 8 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {dataFromRadioroc[1][0]} {dataFromRadioroc[1][1]} {dataFromRadioroc[1][2]} {dataFromRadioroc[1][3]} {dataFromRadioroc[1][4]} {dataFromRadioroc[1][5]} {dataFromRadioroc[1][6]} {dataFromRadioroc[1][7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 8 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {dataToDev[0][0]} {dataToDev[0][1]} {dataToDev[0][2]} {dataToDev[0][3]} {dataToDev[0][4]} {dataToDev[0][5]} {dataToDev[0][6]} {dataToDev[0][7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 8 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {dataToDev[2][0]} {dataToDev[2][1]} {dataToDev[2][2]} {dataToDev[2][3]} {dataToDev[2][4]} {dataToDev[2][5]} {dataToDev[2][6]} {dataToDev[2][7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 8 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {dataToDev[3][0]} {dataToDev[3][1]} {dataToDev[3][2]} {dataToDev[3][3]} {dataToDev[3][4]} {dataToDev[3][5]} {dataToDev[3][6]} {dataToDev[3][7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 8 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {dataFromRadioroc[2][0]} {dataFromRadioroc[2][1]} {dataFromRadioroc[2][2]} {dataFromRadioroc[2][3]} {dataFromRadioroc[2][4]} {dataFromRadioroc[2][5]} {dataFromRadioroc[2][6]} {dataFromRadioroc[2][7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 8 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {i2cDataRdRad[0]} {i2cDataRdRad[1]} {i2cDataRdRad[2]} {i2cDataRdRad[3]} {i2cDataRdRad[4]} {i2cDataRdRad[5]} {i2cDataRdRad[6]} {i2cDataRdRad[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 8 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {i2cDataWrRad[0]} {i2cDataWrRad[1]} {i2cDataWrRad[2]} {i2cDataWrRad[3]} {i2cDataWrRad[4]} {i2cDataWrRad[5]} {i2cDataWrRad[6]} {i2cDataWrRad[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list cs]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list devBurst]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list devBusyRadioroc]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list devExec]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list devReadyRadioroc]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list devRw]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list miso]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list mosi]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list readRq]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list rxPresent]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list sclk]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
set_property port_width 1 [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list txWrAck]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
set_property port_width 1 [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list txWrite]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_100M]
