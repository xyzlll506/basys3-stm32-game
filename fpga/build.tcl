# Single-process build: does not depend on Windows Script Host/runme.bat.
# Never opens or programs a hardware target.
# vivado -mode batch -source build.tcl -tclargs /build/directory
set script_dir [file dirname [file normalize [info script]]]
if {[llength $argv] >= 1} {
    set build_dir [file normalize [lindex $argv 0]]
} else {
    set build_dir [file join $script_dir build]
}
file mkdir $build_dir
create_project -in_memory board_link_build -part xc7a35tcpg236-1
set_property target_language Verilog [current_project]
read_verilog [glob [file join $script_dir rtl *.v]]
read_xdc [file join $script_dir constraints board_link.xdc]
synth_design -top board_link_top -part xc7a35tcpg236-1
opt_design
place_design
route_design
report_timing_summary -file [file join $build_dir timing_summary.txt]
report_drc -file [file join $build_dir design_rule_checks.txt]
report_utilization -file [file join $build_dir utilization.txt]
write_checkpoint -force [file join $build_dir board_link_routed.dcp]
set worst_path [get_timing_paths -delay_type max -max_paths 1 -nworst 1]
if {[llength $worst_path] == 0} { error "No clocked timing path was found" }
set worst_slack [get_property SLACK $worst_path]
if {$worst_slack < 0} { error "Setup timing failed: worst slack $worst_slack ns" }
write_bitstream -force [file join $build_dir board_link_top.bit]
puts "Bitstream: [file join $build_dir board_link_top.bit]"
puts "Worst setup slack: $worst_slack ns"
