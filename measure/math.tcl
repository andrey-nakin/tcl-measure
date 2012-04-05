# math.tcl --
#
#   Math functions
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::math 0.1.0

package require math::statistics

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

proc ::measure::math::slope { xvalues yvalues } {
    set len [min [llength $xvalues] [llength $yvalues]]
    
    if { $len < 2 } {
        return 0.0
    }
    
    if { $len == 2 } {
        return [expr ([lindex $yvalues 1] - [lindex $yvalues 0]) / ([lindex $xvalues 1] - [lindex $xvalues 0])]
    }
    
    if { [catch {set res [::math::statistics::linear-model $xvalues $yvalues] }] } {
        return 0.0
    }
    return [lindex $res 1]
}

