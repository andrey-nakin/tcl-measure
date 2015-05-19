#!/usr/bin/tclsh
# com.tcl --
#
#   COM related utilities
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::com 0.1.0
package require cmdline

namespace eval measure::com {
  namespace export allPorts
}

# Standard baud rates
set measure::com::bauds {1200 2400 4800 9600 14400 19200 38400 57600 115200}

# Standard word lengths
set measure::com::wordLengths { 7 8 }

# Standard stop bit numbers
set measure::com::stopBits { 1 2 }

set measure::com::parities { None Even Odd Mark Space }

# Returns list with addresses of all COM ports available
proc measure::com::allPorts { } {
	set res [list]
	for { set i 1 } { $i <= 99 } { incr i } {
		lappend res "COM$i"
	}
	return $res
}

# Returns string with correct serial port mode
# Arguments
#  args - list of options
proc measure::com::makeMode { args } {
	set opts {
		{baud.arg	9600	"Baud rate"}
		{parity.arg	n		"Parity: n s m e o"}
		{length.arg	8		"word length: 7 8"}
		{stop.arg	1		"stop bits: 1 2"}
	}

	set usage ": measure::com::makeMode \[options]\noptions:"
	array set options [::cmdline::getoptions args $opts $usage]

	set parity [string tolower [string range $options(parity) 0 0]]
	return "$options(baud),$parity,$options(length),$options(stop)"	
}

# Tests if given serial port can be opened
# Arguments
#   port - port name, e.g. /dev/ttyUSB0
# Return
#   1 - port is opened correctly
#   0 - port cannot be open
proc measure::com::test { port } {
	if {[catch {set fd [open $port r+]}]} {
		return 0
	}
	if {[catch {fconfigure $fd -blocking 1 -mode "9600,n,8,1"}]} {
		close $fd
		return 0
	}
	close $fd
	return 1
}

