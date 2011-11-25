#!/usr/bin/tclsh

# Usage: <comport> <mode>
# Example: COM1 9600,n,8,1

set PORT COM1
set MODE "9600,n,8,1"

set port $PORT
if { [llength $argv] > 0 } {
	set port [lindex $argv 0]
}

set mode $MODE
if { [llength $argv] > 1 } {
	set mode [lindex $argv 1]
}

if {[catch {set fd [open $port r+]} err]} {
	puts $err
	exit
}
if {[catch {fconfigure $fd -blocking 1 -mode $mode -buffering line -encoding binary -translation binary} err]} {
	close $fd
	puts $err
	exit
}

while { true } {
	set s [gets $fd]
	puts $s
	puts $fd $s
}

catch {close $fd}

