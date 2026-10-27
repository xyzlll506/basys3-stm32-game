# Vivado 2018.3 Tcl console: source /absolute/path/create_project.tcl
# Batch: vivado -mode batch -source create_project.tcl -tclargs /build/directory
set script_dir [file dirname [file normalize [info script]]]
if {[llength $argv] >= 1} {
    set project_dir [file normalize [lindex $argv 0]]
} else {
    set project_dir [file join $script_dir project]
}
create_project -force board_link $project_dir -part xc7a35tcpg236-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
add_files [glob [file join $script_dir rtl *.v]]
add_files -fileset constrs_1 [file join $script_dir constraints board_link.xdc]
set_property top board_link_top [current_fileset]
add_files -fileset sim_1 [file join $script_dir sim tb_board_link.sv]
set_property top tb_board_link [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Created: [file join $project_dir board_link.xpr]"
