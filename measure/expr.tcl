#!/usr/bin/tclsh
# expr.tcl --
#
#   Evaluating simple expressions
#
#   Copyright (c) 2012 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.5
package provide measure::expr 0.1.0

namespace eval measure::expr {
	namespace export eval
}

array set argNums {}

# Given numeric expression calculates it and return result
# Arguments
#   e - expression string, e.g. "2.0 * x**2 + 3.0 * y"
#   args - variable values to pass into expression
# Return
#   expression result
proc measure::expr::eval { e args } {
    variable argNums

	if {[info procs $e] eq ""} {
		# find all variable occurencies and add $ prefix to them
		# e.g. "x ** 2 + x" -> "$x ** 2 + $x"
		regsub -all {(^|[^a-zA-Z0-9.])([a-zA-Z][a-zA-Z0-9]*)([\s]*)([^\sa-zA-Z0-9(]|$)} $e {\1$\2\3\4} ce

		# replace commas in real numbers with dots
		# e.g. "123,45" -> "123.45"
		regsub -all {,} $ce {.} ce

		# collect all variable names
		set vars [list]
		foreach  v [regexp -inline -all -- {\$[a-zA-Z][a-zA-Z0-9]*} $ce] {
			set v [string range $v 1 end]
			if { [lsearch $vars $v] < 0 } {
				lappend vars $v
			}
		}

		# make procedure argument list
		set argList [list]
		foreach v $vars {
			# each variable has default zero value
			lappend argList [list $v 0.0]
		}

		# create new procedure
        if { 0 == [llength $argList] } {
	       proc $e {} [list expr $ce]
        } else {	
	       proc $e $argList [list expr $ce]
	    }
	    
	    set argNums($e) [llength $argList]
	}

    if { $argNums($e) == 0 } {
    	return [$e]
    } else {
    	return [$e {*}$args]
    }
}

#puts [measure::expr::eval "10" {}]
