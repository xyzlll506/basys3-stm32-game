# Vivado single-process build. Does not connect/program hardware.
set script_dir [file dirname [file normalize [info script]]]
set build_dir [file join $script_dir build game]
if {[llength $argv] >= 1} { set build_dir [file normalize [lindex $argv 0]] }
file mkdir $build_dir
create_project -in_memory game_build -part xc7a35tcpg236-1
set_property target_language Verilog [current_project]
set_property include_dirs [file normalize [file join $script_dir .. game generated]] [current_fileset]
read_verilog [list [file join $script_dir rtl uart_rx.v] [file join $script_dir rtl uart_tx.v]]
read_verilog [glob [file join $script_dir game rtl *.v]]
read_xdc [file join $script_dir constraints game.xdc]
synth_design -top game_top -part xc7a35tcpg236-1
opt_design
place_design
route_design
report_timing_summary -file [file join $build_dir timing_summary.txt]
report_drc -file [file join $build_dir design_rule_checks.txt]
report_utilization -file [file join $build_dir utilization.txt]
report_clocks -file [file join $build_dir clocks.txt]
write_checkpoint -force [file join $build_dir game_routed.dcp]
set setup_path [get_timing_paths -delay_type max -max_paths 1 -nworst 1]
set hold_path [get_timing_paths -delay_type min -max_paths 1 -nworst 1]
if {[llength $setup_path] == 0 || [llength $hold_path] == 0} { error "No constrained timing paths" }
set setup_slack [get_property SLACK $setup_path]
set hold_slack [get_property SLACK $hold_path]
if {$setup_slack < 0 || $hold_slack < 0} { error "Timing failure: setup $setup_slack, hold $hold_slack" }
write_bitstream -force [file join $build_dir game_top.bit]
puts "Bitstream: [file join $build_dir game_top.bit]"
puts "Worst setup slack: $setup_slack ns; worst hold slack: $hold_slack ns"
