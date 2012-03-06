#!/usr/bin/tclsh
# ranges.tcl --
#
#   Parsing and evaluating ranges of numbers
#
#   Copyright (c) 2012 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::ranges 0.1.0

namespace eval measure::ranges {
	namespace export 
}

# Parses string with range expressions to the list of numbers.
# Arguments
#   e - Expression string
# Return
#   List of numbers
proc measure::ranges::toList { e } {
	set result [list]

	set e [string map { .. # } $e]
	foreach s [split $e #] {
		set f 1
		foreach v [regexp -inline -all -- {[0-9\.]+} $s] {
			if { $f && [llength $result] > 1 } {
				set x [lindex $result end-1]
				set step [expr [lindex $result end] - $x]
				for { set x [expr $x + $step * 2.0] } { $x <= $v + 0.1 * $step } { set x [expr $x + $step] } {
					lappend result $x
				}
			} else {
				lappend result $v
			}
			set f 0
		}
	}

	return $result
}

#puts [measure::ranges::toList {
#	1.1,1.2..2.0
#	15, 25
#	100, 110 .. 150
#}]

#puts [measure::ranges::toList {}]

