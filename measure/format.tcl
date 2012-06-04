# format.tcl --
#
#   Data formatting utils
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::format 0.1.0

package require cmdline

namespace eval ::measure::format {
  namespace export 
}

proc ::measure::format::value { args } {
    set configOptions {
    	{prec.arg      6	"Value precision"}
    	{mult.arg      1.0	"Value multiplier"}
    }
    
	set usage ": valueWithErr \[options] v units\noptions:"
	array set params [::cmdline::getoptions args $configOptions $usage]
	lassign $args v units

    set v [expr $v * $params(mult)]
    set vPrec $params(prec)
    set av [expr abs($v)]
    	
    if { $av >= 1.0e9 } {
        set rf [format "%0.${vPrec}g \u0413${units}" [expr 1.0e-9 * $v]]
    } elseif { $av >= 1.0e6 && $av < 1.0e9  } {
        set rf [format "%0.${vPrec}g \u041C${units}" [expr 1.0e-6 * $v]]
    } elseif { $av >= 1.0e3 && $av < 1.0e6  } { 
        set rf [format "%0.${vPrec}g \u043A${units}" [expr 1.0e-3 * $v]]
    } elseif { $av >= 1.0e-3 && $av < 1.0e0  } { 
        set rf [format "%0.${vPrec}g \u043C${units}" [expr 1.0e3 * $v]]
    } elseif { $av >= 1.0e-6 && $av < 1.0e-3  } { 
        set rf [format "%0.${vPrec}g \u03BC${units}" [expr 1.0e6 * $v]]
    } elseif { $av >= 1.0e-9 && $av < 1.0e-6  } { 
        set rf [format "%0.${vPrec}g \u043D${units}" [expr 1.0e9 * $v]]
    } elseif { $av >= 1.0e-12 && $av < 1.0e-9  } { 
        set rf [format "%0.${vPrec}g \u043F${units}" [expr 1.0e12 * $v]]
    } else {
        set rf [format "%0.${vPrec}g ${units}" $v]
    }
}

proc ::measure::format::valueWithErr { args } {
    set configOptions {
    	{prec.arg      6	"Value precision"}
    	{errPrec.arg   2	"Error precision"}
    	{mult.arg      1.0	"Value multiplier"}
    }
    
	set usage ": valueWithErr \[options] v err units\noptions:"
	array set params [::cmdline::getoptions args $configOptions $usage]
	lassign $args v err units

    set v [expr $v * $params(mult)]
    set av [expr abs($v)]
    set err [expr $err * $params(mult)]
    set vPrec $params(prec)
    set errPrec $params(errPrec)
    	
    if { $av >= 1.0e9 } {
        set rf [format "%0.${vPrec}g \u00b1 %0.${errPrec}g \u0413${units}" [expr 1.0e-9 * $v] [expr 1.0e-9 * $err]]
    } elseif { $av >= 1.0e6 && $av < 1.0e9  } {
        set rf [format "%0.${vPrec}g \u00b1 %0.${errPrec}g \u041C${units}" [expr 1.0e-6 * $v] [expr 1.0e-6 * $err]]
    } elseif { $av >= 1.0e3 && $av < 1.0e6  } { 
        set rf [format "%0.${vPrec}g \u00b1 %0.${errPrec}g \u043A${units}" [expr 1.0e-3 * $v] [expr 1.0e-3 * $err]]
    } elseif { $av >= 1.0e-3 && $av < 1.0e0  } { 
        set rf [format "%0.${vPrec}g \u00b1 %0.${errPrec}g \u043C${units}" [expr 1.0e3 * $v] [expr 1.0e3 * $err]]
    } elseif { $av >= 1.0e-6 && $av < 1.0e-3  } { 
        set rf [format "%0.${vPrec}g \u00b1 %0.${errPrec}g \u03BC${units}" [expr 1.0e6 * $v] [expr 1.0e6 * $err]]
    } elseif { $av >= 1.0e-9 && $av < 1.0e-6  } { 
        set rf [format "%0.${vPrec}g \u00b1 %0.${errPrec}g \u043D${units}" [expr 1.0e9 * $v] [expr 1.0e9 * $err]]
    } elseif { $av >= 1.0e-12 && $av < 1.0e-9  } { 
        set rf [format "%0.${vPrec}g \u00b1 %0.${errPrec}g \u043F${units}" [expr 1.0e12 * $v] [expr 1.0e12 * $err]]
    } else {
        set rf [format "%0.${vPrec}g \u00b1 %0.${errPrec}g ${units}" $v $err]
    }
}

#puts [::measure::format::number 0.0123 0.00123 A]