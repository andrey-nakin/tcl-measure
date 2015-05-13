#!/usr/bin/tclsh
# bsearch.tcl --
#
#   Binary numeric search
#
#   Copyright (c) 2012 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::bsearch 0.1.0

namespace eval measure::bsearch {
	namespace export getTcTypes calcKelvin calcCelsius
}

# Searches a number in a sorted list.
# Returns index of the greatest element which is less or equal to given value.
# Arguments
#   lst - list to search in
#   x - value to search
# Return
#   Index of the element which is less or equal to `x'.
#   -1 if list is empty or min list value is greater than `x'.
proc measure::bsearch::lowerBound { lst x } {
	global l v

	set l $lst
	set v $x
	return [lowerBoundImpl 0 [llength $l]]
}

# Searches a number in a sorted list.
# Returns index of the lowest element which is greater than given value.
# Arguments
#   lst - list to search in
#   x - value to search
# Return
#   Index of the element which is greater than `x'.
#   -1 if list is empty or max list value is less or equal to `x'.
proc measure::bsearch::upperBound { lst x } {
	global l v

	set l $lst
	set v $x
	return [upperBoundImpl 0 [llength $l]]
}

##############################################################################
# Private
##############################################################################

proc measure::bsearch::lowerBoundImpl { min max } {
	global l v

	set len [llength $l]
	if {$min >= $max} {
		return -1
	}

	set pivotIndex [expr {($max - $min) / 2} + $min]
	set pivotValue [lindex $l $pivotIndex]

	if {$pivotValue <= $v} {
		set result [lowerBoundImpl [expr $pivotIndex + 1] $max]
		return [expr $result < 0 ? $pivotIndex : $result]
	} else {
		return [lowerBoundImpl $min $pivotIndex]
	}
}

proc measure::bsearch::upperBoundImpl { min max } {
	global l v

	set len [llength $l]
	if {$min >= $max} {
		return -1
	}

	set pivotIndex [expr {($max - $min) / 2} + $min]
	set pivotValue [lindex $l $pivotIndex]

	if {$pivotValue <= $v} {
		return [upperBoundImpl [expr $pivotIndex + 1] $max]
	} else {
		set result [upperBoundImpl $min $pivotIndex]
		return [expr $result < 0 ? $pivotIndex : $result]
	}
}

#puts [measure::bsearch::lowerBound {1 2 3 4} 0.1]

