# sigma.tcl --
#
#   Measurement error calculations
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::sigma 0.1.0

namespace eval measure::sigma {
  namespace export mul div
}

# Calculate error of sum of several values
# Arguments
#   args - value errors
# Return
#   error calculated
proc measure::sigma::add { args } {
	set sum 0.0

	foreach e $args {
        if { $e != "" } {	
		  set sum [expr $sum + $e * $e]
		}
	}

	return [expr sqrt($sum)]
}

# Calculate error of multiplication of several values
# Arguments
#   args - (value, error) pairs
# Return
#   error calculated
proc measure::sigma::mul { args } {
	set sum 0.0

	for { set i 0 } { $i < [llength $args] } { incr i } {
		set m 1.0
		for { set j 0 } { $j < [llength $args] } { incr j 2 } {
			if { $j != $i } {
				set m [expr $m * [lindex $args $j]]
			}
		}

		incr i
		set a [expr $m * [lindex $args $i]]
		set sum [expr $sum + $a * $a]
	}

	return [expr sqrt($sum)]
}

# Calculate error of multiplication of two values
# Arguments
#   values - list of two (value, error) pairs
# Return
#   error calculated
proc measure::sigma::div { a da b db } {
    if { abs($b) < 1.0e-15 } {
        return 0.0
    }
	set x [expr $db * $a / $b]
	return [expr 1.0 / $b * sqrt($da * $da + $x * $x)]
}

