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

if {[catch {fconfigure $fd -blocking 1 -mode $mode -buffering line -encoding binary -translation binary -timeout 800000} err]} {
	close $fd
	puts $err
	exit
}

after 1000
puts "Type Ctrl-C to exit"

puts $fd *IDN?
puts [gets $fd]
puts $fd "CONF:VOLT DEF"
puts $fd "SAMPLE:COUNT 400"

while { 1 } {
    #puts $fd "INIT"
    #puts $fd "FETCH?"
    #puts "FETCH = [gets $fd]"
    puts $fd "READ?"
    puts "READ = [gets $fd]"
    puts $fd "SYST:ERR?"
    set err [gets $fd]
    puts "err = $err"
    if { $err == "" } {
        while { $err == "" } {
            puts $fd "*IDN?"
            set err [gets $fd]
            puts "err = $err"
        }
        continue;
    }
    set err [lindex [split $err ,] 0]
    if { $err != 0 } {
        puts "ERROR $err";
        break;
    }
}

catch {close $fd}

