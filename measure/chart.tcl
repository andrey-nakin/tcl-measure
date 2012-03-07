# chart.tcl --
#
#   COM related utilities
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.5
package provide measure::chart 0.1.0
package require cmdline
package require Plotchart
package require measure::listutils

namespace eval measure::chart {
  namespace export limits
}

# Calculates chart axis limits upon given min and max values
# Arguments
#   min - min data value
#   max - max data value
# Return
#   List of three numbers: lower limit, upper limit, step
proc measure::chart::limits { min max } {
	if { $min == "" } {
		set min 0
	}
	if { $max == "" } {
		set max 1
	}

	if { $min > $max } {
		# swap min & max
		set v $min
		set min $max
		set max $v
	}

	if { $max - $min < 1.0e-100 } {
		set max [expr $min + 1.0e-100]
	}

    if { $max >= 0 && $min >= 0 } {
        lassign [calcLimits $min $max] lower upper
    } else {
    	if { $min < 0.0 && $max < 0.0 } {
    		set lower [expr -1.0 * [calcHigherLimit [expr -1.0 * $min]]]
    	} else {
    		set lower [calcLowerLimit $min]
    	}
    	
    	if { $max < 0.0 } {
    		set upper [expr -1.0 * [calcLowerLimit [expr -1.0 * $max]]]
    	} else {
    		set upper [calcHigherLimit $max]
    	}
    }

	return [list $lower $upper [expr 0.2 * ($upper - $lower)]]
}

proc measure::chart::movingChart { args } {
	set opts {
		{linearTrend	""	"add linear trend line"}
		{ylabel.arg		""	"Y-axis label"}
		{xpoints.arg	"200"	"Number of points on X-axis"}
	}

	set usage ": measure::chart::movingChart \[options] canvas\noptions:"
	array set options [::cmdline::getoptions args $opts $usage]
	lassign $args canvas

	namespace eval ::measure::chart::${canvas} {
        variable redo
		variable chartValues
		variable chartBgColor
		variable canvas
		variable options
	}

	proc ::measure::chart::${canvas}::addPoint { v } {
		variable chartValues
		variable options

		if { ![info exists chartValues] } {
			set chartValues [list]
		}

		measure::listutils::lappend chartValues $v $options(xpoints)

		doPlot	
	}

	proc ::measure::chart::${canvas}::doPlot {} {
		variable chartValues
		variable chartBgColor
		variable canvas
		variable options

		$canvas delete all

		if { [llength $chartValues] > 0 } {
			set stats [::math::statistics::basic-stats $chartValues]
			set ylimits [list [lindex $stats 1] [lindex $stats 2]]
		} else {
			set ylimits {0.0 1.0}
		}

		set s [::Plotchart::createXYPlot $canvas [list 0 $options(xpoints) 20] [measure::chart::limits [lindex $ylimits 0] [lindex $ylimits 1]]]
		$s dataconfig series1 -colour green
		$s ytext $options(ylabel)
		$s yconfig -format %2g

		if { ![info exists chartBgColor] } {
			set chartBgColor [$canvas cget -bg]
		}
		$s background plot black
		$s background axes $chartBgColor

		set x 0
		set xx [list]
		foreach y $chartValues {
			$s plot series1 $x $y
			lappend xx $x
			incr x
		}

		if { $options(linearTrend) && [llength $xx] > 10 } {
			lassign [::math::statistics::linear-model $xx $chartValues] a b
			set lll [expr [llength $xx] - 1]
			$s dataconfig series2 -colour magenta
			$s plot series2 [lindex $xx 0] [expr [lindex $xx 0] * $b + $a]
			$s plot series2 [lindex $xx $lll] [expr [lindex $xx $lll] * $b + $a]
		}
	}

	proc ::measure::chart::${canvas}::doResize {} {
		doPlot
		return
        variable redo

		#
		# To avoid redrawing the plot many times during resizing,
		# cancel the callback, until the last one is left.
		#
		if { [info exists redo] } {
		    after cancel $redo
		}

		set redo [after 50 doPlot]
	}

	set ::measure::chart::${canvas}::canvas $canvas
	set ::measure::chart::${canvas}::chartValues [list]
	array set ::measure::chart::${canvas}::options [array get options]

	bind $canvas <Configure> "::measure::chart::${canvas}::doResize"

}

proc measure::chart::staticChart { args } {
	set opts {
		{xlabel.arg		""	"X-axis label"}
		{ylabel.arg		""	"Y-axis label"}
		{lines.arg		"1"	"Plot lines"}
		{dots.arg		"0"	"Plot dots"}
	}

	set usage ": measure::chart::movingChart \[options] canvas\noptions:"
	array set options [::cmdline::getoptions args $opts $usage]
	lassign $args canvas

	namespace eval ::measure::chart::${canvas} {
        variable redo
		variable xValues
		variable yValues
		variable chartBgColor
		variable canvas
		variable options

		set xValues [list]
		set yValues [list]
	}

	proc ::measure::chart::${canvas}::addPoint { x y } {
		variable xValues
		variable yValues
		variable options

		lappend xValues $x
		lappend yValues $y

		doPlot	
	}

	proc ::measure::chart::${canvas}::clear { } {
		variable xValues
		variable yValues

		set xValues [list]
		set yValues [list]

		doPlot	
	}
	
	proc ::measure::chart::${canvas}::makeLimits { values } {
		if { [llength $values] > 0 } {
			set stats [::math::statistics::basic-stats $values]
			return [measure::chart::limits [lindex $stats 1] [lindex $stats 2]]
		} else {
			return [measure::chart::limits 0.0 1.0]
		}
	}

	proc ::measure::chart::${canvas}::doPlot {} {
		variable xValues
		variable yValues
		variable chartBgColor
		variable canvas
		variable options

		$canvas delete all

		set s [::Plotchart::createXYPlot $canvas [makeLimits $xValues] [makeLimits $yValues]]
		$s dataconfig series1 -colour green
		$s dotconfig series1 -colour green
		$s xtext $options(xlabel)
		$s xconfig -format %2g
		$s ytext $options(ylabel)
		$s yconfig -format %2g

		if { ![info exists chartBgColor] } {
			set chartBgColor [$canvas cget -bg]
		}
		$s background plot black
		$s background axes $chartBgColor

		foreach x $xValues y $yValues {
            if { $options(lines) } {
    			$s plot series1 $x $y
            }
            if { $options(dots) } {
    			$s dot series1 $x $y 3
    		}
		}
	}

	proc ::measure::chart::${canvas}::doResize {} {
		doPlot
	}

	set ::measure::chart::${canvas}::canvas $canvas
	set ::measure::chart::${canvas}::chartValues [list]
	array set ::measure::chart::${canvas}::options [array get options]

	bind $canvas <Configure> "::measure::chart::${canvas}::doResize"

}

###############################################################################
# Internal procedures
###############################################################################

proc measure::chart::calcLimits { min max } {
    set diff [expr $max - $min]
    return [list [expr floor($min - 1)] [expr floor($max + 1)] ]
} 

proc measure::chart::calcHigherLimit { v } {
    return [expr $v * 1.1]
	set step [expr 10 ** floor(log10($v))]
	set res $step
	while { $res < $v } {
		set res [expr $res + $step]
	}
	return $res
}

proc measure::chart::calcLowerLimit { v } {
    return [expr $v * 0.9]
	set step [expr 10 ** floor(log10($v))]
	set res [expr $step * 9]
	while { $res > $v } {
		set res [expr $res - $step]
	}
	return $res
}

