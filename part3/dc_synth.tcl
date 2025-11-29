# Simple synthesis script to use FreePDK/45nm libraries
file mkdir reports
file mkdir netlist
remove_design -all
define_design_lib FreePDK_45nm -path "FreePDK_45nm"
set_host_options -max_cores 16

#####################
# Config Variables
#####################

#####################
# Path Variables
#####################
set SYN  /cad/synopsys/syn/M-2016.12-SP2/libraries/syn/
set OPENCELL_45 ./lib/

#####################
# Set Design Library
#####################
set link_library [list NangateOpenCellLibrary.db dw_foundation.sldb]
set target_library [list NangateOpenCellLibrary.db]
set synthetic_library [list  dw_foundation.sldb]
set dw_lib     $SYN
set sym_lib    $OPENCELL_45
set target_lib $OPENCELL_45
set search_path [list ./ ../rtl/  $dw_lib $target_lib $sym_lib ../params/ ]

###################
# Read Design
###################
set file_list [list \
    ./defines.sv \
    ../logical/buffer.sv \
    ../logical/controller.sv \
    ../logical/instruction_memory.sv \
    ../logical/processing_element.sv \
    ../logical/top.sv \
    ./macros/array.sv \
]
analyze -library FreePDK_45nm -format sverilog $file_list
elaborate ${DESIGN_TARGET} -architecture verilog -library FreePDK_45nm
link


##################################
# Constraints File
##################################
set CLK  "clk"
set RST  "rst_n"
create_clock $CLK -period $CLK_PERIOD
set_wire_load_model -name 1K_hvratio_1_4
set_wire_load_mode top
set_max_fanout 4.0 [get_ports "*" -filter {@port_direction != out} ]
set all_inputs_wo_rst_clk [remove_from_collection [remove_from_collection [all_inputs] [get_port $CLK]] [get_port $RST]]
set_input_delay -clock $CLK [ expr $CLK_PERIOD*3/4 ] $all_inputs_wo_rst_clk
set_driving_cell -lib_cell "INV_X1" -pin "ZN" [ get_ports "*" -filter {@port_direction == in} ]
set_input_delay -clock $CLK 0 instruction_count
set_max_area $TARGET_AREA
remove_driving_cell $RST
set_drive 0 $RST
set_dont_touch_network $RST


##########################################
# Synthesize Design (Optimize for Timing)
##########################################
set_optimize_registers true -design ${DESIGN_TARGET}
set_clock_gating_style -sequential_cell latch -positive_edge_logic {integrated}
set compile_clock_gating_flag true
compile_ultra -retime -timing_high_effort_script


##########################
# Generate Reports 
##########################
redirect "reports/design_report" { report_design }
check_design
redirect "reports/design_check" {check_design }
report_area 
redirect "reports/area_report" { report_area }
report_area -hierarchy
redirect "reports/area_report_hier" { report_area -hierarchy }
report_power
redirect "reports/power_report" { report_power -analysis_effort hi }
report_timing
redirect "reports/timing_report_maxsm" { report_timing -significant_digits 4 }
report_qor
redirect "reports/qor_report" { report_qor }
check_error
redirect "reports/error_checking_report" { check_error }

###################################
# Save the Design DataBase
###################################
write -format verilog -hierarchy -output "netlist/top.mapped.v"

#Concise Results in a singular file
echo $CLK_PERIOD >> results.txt
sh cat reports/error_checking_report >> results.txt
sh grep -i slack reports/timing_report_maxsm >> results.txt
sh cat reports/power_report | grep Total >> results.txt
sh cat reports/power_report | grep Cell | grep Leakage >> results.txt
sh cat reports/area_report | grep Total | grep cell >> results.txt

exit 





