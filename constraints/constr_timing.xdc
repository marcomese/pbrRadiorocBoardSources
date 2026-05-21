create_clock -period 5.000 -name clk_200M [get_ports sysClk_p]

create_generated_clock -name clk_2M -source [get_ports sysClk_p] -divide_by 100 [get_pins clk2MBufInst/O]

create_generated_clock -name adcSck -source [get_ports sysClk_p] -divide_by 2 [get_pins adcSckBufInst/O]

# Constraining all inputs as asynchronous since I am oversampling both data and serial clocks (e.g. scl for i2c)
create_clock -name virt_async_clk -period 5.000

set async_ports [filter [all_inputs] {NAME !~ sysClk_p && NAME !~ sysClk_n}]

set async_dest [get_cells -hier -filter {ASYNC_REG == TRUE}]

set_input_delay -clock virt_async_clk 0.000 $async_ports
set_max_delay 5.000 -datapath_only -from $async_ports -to $async_dest
set_min_delay 0.000 -from $async_ports -to $async_dest

set async_out_ports [all_outputs]

set_output_delay -clock virt_async_clk 0.000 $async_out_ports
set_max_delay 15.000 -to $async_out_ports
set_min_delay 0.000 -to $async_out_ports