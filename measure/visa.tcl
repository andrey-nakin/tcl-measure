# visa.tcl --
#
#   VISA related utilities
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::visa 0.1.0

catch { package require tclvisa }

namespace eval measure::visa {
  namespace export allInstruments
}

# Returns list with addresses of all VISA INSTR resources available
proc measure::visa::allInstruments { } {
	if { [catch {
		set rm [visa::open-default-rm]
		set res [visa::find $rm ?*INSTR]
		close $rm } ] } {
		set res [list]
	}
	return $res
}

