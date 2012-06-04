# chart.tcl --
#
#   COM related utilities
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.5
package provide measure::chart 0.1.0
package require cmdline
package require Plotchart
package require measure::listutils
package require measure::chart::static-chart
package require measure::chart::moving-chart
package require measure::math

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

	if { $max - $min < 1.0e-5 } {
		set max [expr $min + 1.0e-5]
	}

    if { $max >= 0 && $min >= 0 } {
        lassign [calcLimits $min $max] lower upper
    } elseif { $max <= 0 && $min <= 0 } {
        lassign [calcLimits [expr -1.0 * $max] [expr -1.0 * $min]] l u
        set lower [expr -1.0 * $u]
        set upper [expr -1.0 * $l]
    } else {
        lassign [calcLimits 0.0 $max] _ upper
        lassign [calcLimits 0.0 [expr -1.0 * $min]] _ u
        set lower [expr -1.0 * $u]
    }

	return [list $lower $upper [expr 0.2 * ($upper - $lower)]]
}

###############################################################################
# Internal procedures
###############################################################################

proc measure::chart::calcLimits { min max } {
    set a [expr log10($max - $min)]
    set b [expr -int($a >= 0 ? roundDown($a) : roundUp($a))]
    return [list [expr roundDown($min, $b)] [expr roundUp($max, $b)] ]
} 
