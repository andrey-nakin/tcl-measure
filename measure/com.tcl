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

# Standard baud rates
set measure::com::bauds {1200 2400 4800 9600 14400 19200 38400 57600 115200}

# Standard word lengths
set measure::com::wordLengths { 7 8 }

# Standard stop bit numbers
set measure::com::stopBits { 1 2 }

set measure::com::parities { n s m e o }

# Returns list with addresses of all COM ports available
proc measure::com::allPorts { } {
	set res [list]
	for { set i 1 } { $i <= 99 } { incr i } {
		lappend res "COM$i"
	}
	return $res
}



