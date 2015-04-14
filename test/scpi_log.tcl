#!/usr/bin/tclsh

# Usage: <scpi_log> <mode>
# Example: COM1 9600,n,8,1

set PORT ASRL2::INSTR
set MODE "9600,n,8,1"

set port $PORT
if { [llength $argv] > 0 } {
	set port [lindex $argv 0]
}

set mode $MODE
if { [llength $argv] > 1 } {
	set mode [lindex $argv 1]
}

if { [string first INSTR $port] < 0 } {
    if {[catch {set fd [open $port r+]} err]} {
    	puts $err
    	exit
    }
} else {
    package require tclvisa
    set rm [visa::open-default-rm]
    if {[catch {set fd [visa::open $rm $port]} err]} {
    	puts $err
    	exit
    }
}

if {[catch {fconfigure $fd -blocking 1 -mode $mode -buffering line -encoding binary -translation binary -timeout 20000} err]} {
	close $fd
	puts $err
	exit
}

if {[catch {set log [open scpi.log a]} err]} {
	puts $err
	exit
}

puts $log "*** NEW SESSION STARTED [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] ***"
puts "Type commands, exit to terminate"

while { 1 } {
    set cmd [gets stdin]
    if { $cmd == "exit" } {
        break
    }
    puts $log "[clock format [clock seconds] -format {%H:%M:%S}] > $cmd"
    puts $fd $cmd
    
    if { [string first ? $cmd] >= 0 } {
    	set s [gets $fd]
    	puts $s
    	puts $log "[clock format [clock seconds] -format {%H:%M:%S}] < $s"
    }
}

catch {close $fd}

