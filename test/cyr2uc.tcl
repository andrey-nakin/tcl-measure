#!/usr/bin/tclsh
set fileName [lindex $argv 0]
set f [open $fileName r]
fconfigure $f -encoding utf-8
set content [read $f]
close $f

set len [string length $content]
set f [open $fileName w]
for { set i 0 } { $i < $len } { incr i } {
    set c [string index $content $i]
	scan $c %c ascii
	if { $ascii > 127 } {
		set c "\\u[format %04X $ascii]"
	}
    puts -nonewline $f $c 
}
close $f
