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

###############################################################################
# procedures in ::tcl::mathfunc namespace
###############################################################################

proc ::tcl::mathfunc::sign { x } {
	if { $x > 0 } {
		return 1
	}
	if { $x < 0 } {
		return -1
	}
	return 0
}

###############################################################################
# procedures in own namespace
###############################################################################

proc ::measure::math::slope { xvalues yvalues } {
    set len [::tcl::mathfunc::min [llength $xvalues] [llength $yvalues]]
    
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

proc ::measure::math::slope-std { xvalues yvalues } {
    set len [::tcl::mathfunc::min [llength $xvalues] [llength $yvalues]]
    
    if { $len < 2 } {
        return { 0.0 0.0 }
    }
    
    if { $len == 2 } {
        return [list [expr ([lindex $yvalues 1] - [lindex $yvalues 0]) / ([lindex $xvalues 1] - [lindex $xvalues 0])] 0.0 ]
    }
    
    if { [catch {set res [::math::statistics::linear-model $xvalues $yvalues] }] } {
        return { 0.0 0.0 }
    }
    return [list [lindex $res 1] [lindex $res 2] ]
}

proc ::measure::math::validateRange { varname minVal maxVal } {
	upvar $varname v

    if { $v > $maxVal } {
        set v $maxVal 
    } 
    if { $v < $minVal } {
        set v $minVal
    }
	return $v 
}

