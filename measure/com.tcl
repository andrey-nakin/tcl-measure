# com.tcl --
#
#   COM related utilities
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::com 0.1.0

namespace eval measure::com {
  namespace export allPorts
}

# Returns list with addresses of all COM ports available
proc measure::com::allPorts { } {
	set res [list]
	for { set i 1 } { $i <= 99 } { incr i } {
		lappend res "COM$i"
	}
	return $res
}

