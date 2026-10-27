set script_dir [file dirname [file normalize [info script]]]
set project_dir [file join $script_dir project game]
if {[llength $argv] >= 1} { set project_dir [file normalize [lindex $argv 0]] }
set include_dir [file normalize [file join $script_dir .. game generated]]
create_project -force game $project_dir -part xc7a35tcpg236-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
add_files [glob [file join $script_dir game rtl *.v]]
add_files [list [file join $script_dir rtl uart_rx.v] [file join $script_dir rtl uart_tx.v]]
add_files [file join $include_dir level.vh]
set_property file_type {Verilog Header} [get_files level.vh]
set_property include_dirs $include_dir [current_fileset]
add_files -fileset constrs_1 [file join $script_dir constraints game.xdc]
set_property top game_top [current_fileset]
add_files -fileset sim_1 [file join $script_dir game sim tb_game.sv]
set_property include_dirs $include_dir [get_filesets sim_1]
set_property top tb_game [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Created: [file join $project_dir game.xpr]"
