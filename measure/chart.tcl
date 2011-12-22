# chart.tcl --
#
#   COM related utilities
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::chart 0.1.0

namespace eval measure::chart {
  namespace export limits
}

# Calculates chart axis limits upon given min and max values
# Arguments
#   min - min data value
#   max - max data value
# Return
#   List of three numbers: lower limit, upper limit, step
proc measure::chart::limits { min max } {
	if { $min == "" } {
		set min 0
	}
	if { $max == "" } {
		set max 1
	}

	if { $min > $max } {
		# swap min & max
		set v $min
		set min $max
		set max $v
	}

	if { $max - $min < 1.0e-100 } {
		set max [expr $min + 1.0e-100]
	}

	if { $min < 0.0 } {
		set lower [expr -1.0 * [calcHigherLimit [expr -1.0 * $min]]]
	} else {
		set lower [calcLowerLimit $min]
	}
	
	if { $max < 0.0 } {
		set upper [expr -1.0 * [calcLowerLimit [expr -1.0 * $max]]]
	} else {
		set upper [calcHigherLimit $max]
	}

	return [list $lower $upper [expr 0.2 * ($upper - $lower)]]
}

###############################################################################
# Internal procedures
###############################################################################

proc measure::chart::calcHigherLimit { v } {
	set step [expr 10 ** floor(log10($v))]
	set res $step
	while { $res < $v } {
		set res [expr $res + $step]
	}
	return $res
}

proc measure::chart::calcLowerLimit { v } {
	set step [expr 10 ** floor(log10($v))]
	set res [expr $step * 9]
	while { $res > $v } {
		set res [expr $res - $step]
	}
	return $res
}

