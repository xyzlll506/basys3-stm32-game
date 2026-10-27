# Runs the protocol/physical-UART testbench at a real 100 MHz clock.
source [file join [file dirname [file normalize [info script]]] create_project.tcl]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
close_sim
set sim_log [file join $project_dir board_link.sim sim_1 behav xsim simulate.log]
set log_handle [open $sim_log r]
set log_text [read $log_handle]
close $log_handle
if {![string match "*PASS: UART framing*" $log_text]} {
    error "UART simulation did not reach its PASS checkpoint; inspect $sim_log"
}
puts "PASS checkpoint verified in $sim_log"
