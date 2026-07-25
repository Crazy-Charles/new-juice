if {![info exists ::env(NEW_JUICE_ROOT)]} {
    error "NEW_JUICE_ROOT is not set"
}

cd $::env(NEW_JUICE_ROOT)
open_project [file join $::env(NEW_JUICE_ROOT) new-juice.gprj]
run all

