# moving-chart.tcl --
#
# Chart with moving X-axis
#
# Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.5
package provide measure::chart::moving-chart 0.1.0

package require Tk
package require Ttk

namespace eval measure::chart {
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

	proc ::measure::chart::${canvas}::clear { } {
		variable chartValues
		
    	set chartValues [list]
    	
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

	proc ::measure::chart::${canvas}::getYStat {} {
		variable chartValues
		if { [llength $chartValues] < 1 } {
		  return {}
        }
	    return [::math::statistics::basic-stats $chartValues]
	}

	set ::measure::chart::${canvas}::canvas $canvas
	set ::measure::chart::${canvas}::chartValues [list]
	array set ::measure::chart::${canvas}::options [array get options]

	bind $canvas <Configure> "::measure::chart::${canvas}::doResize"

}
