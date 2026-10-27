source [file join [file dirname [file normalize [info script]]] create_game_project.tcl]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
close_sim
set sim_log [file join $project_dir game.sim sim_1 behav xsim simulate.log]
set handle [open $sim_log r]
set log_text [read $handle]
close $handle
if {![string match "*PASS: game protocol*" $log_text]} {
    error "Game simulation did not reach PASS; inspect $sim_log"
}
puts "PASS checkpoint verified in $sim_log"
