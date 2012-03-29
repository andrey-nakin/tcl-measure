# math.tcl --
#
#   Math functions
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::math 0.1.0

namespace eval ::measure::math {
  namespace export max 
}

proc ::measure::math::max { args } {
	set res ""

	foreach v $args {
		if { $v > $res } {
			set res $v
		}
	}

	return $res
}

proc ::measure::math::min { args } {
	set res ""

	foreach v $args {
		if { $res == "" || $v < $res } {
			set res $v
		}
	}

	return $res
}

