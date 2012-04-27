# static-chart.tcl --
#
# Chart with fixed X-axis
#
# Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.5
package provide measure::chart::static-chart 0.1.0

package require Tk
package require Ttk

namespace eval measure::chart {
}

proc measure::chart::staticChart { args } {
	set opts {
		{xlabel.arg		""	"X-axis label"}
		{ylabel.arg		""	"Y-axis label"}
		{lines.arg		"1"	"Plot lines"}
		{dots.arg		"0"	"Plot dots"}
	}
	set stdColors { green blue red }

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

		array set xValues {}
		array set yValues {}
	}

	proc ::measure::chart::${canvas}::addPoint { x y { series "series1" } } {
	   upvar stdColors stdColors
	
		variable xValues
		variable yValues
		variable options
		variable seriesMaxCount
		variable seriesColor

        if { ![info exists xValues($series)] } {
            set xValues($series) {} 
            set yValues($series) {}
            
            if { ![info exists seriesColor($series)] } {
                set seriesColor($series) [lindex $stdColors [llength [array names seriesColor]]] 
            }   
        }
        
        if { [info exists seriesMaxCount($series)] && $seriesMaxCount($series) != "" } {
    		::measure::listutils::lappend xValues($series) $x $seriesMaxCount($series)
    		::measure::listutils::lappend yValues($series) $y $seriesMaxCount($series)
        } else {
    		lappend xValues($series) $x
    		lappend yValues($series) $y
        }
        
		doPlot	
	}

	proc ::measure::chart::${canvas}::clear { } {
		variable xValues
		variable yValues

		array unset xValues
		array unset yValues
		array set xValues {}
		array set yValues {}

		doPlot	
	}
	
	proc ::measure::chart::${canvas}::makeXLimits { } {
	    variable xValues
        
        set a ""; set b ""
        foreach series [array names xValues] {
    		if { [llength $xValues($series)] > 0 } {
    			lassign [::math::statistics::basic-stats $xValues($series)] avg _a _b
    			if { $a == "" || $a > $_a } {
    			    set a $_a
                }
    			if { $b == "" || $b < $_b } {
    			    set b $_b
                }
    		}
        }
        
        if { $a == "" } {
            set a 0.0; set b 1.0
        } 

    	return [measure::chart::limits $a $b]
	}

	proc ::measure::chart::${canvas}::makeYLimits { } {
	    variable yValues
        
        set a ""; set b ""
        foreach series [array names yValues] {
    		if { [llength $yValues($series)] > 0 } {
    			lassign [::math::statistics::basic-stats $yValues($series)] avg _a _b
    			if { $a == "" || $a > $_a } {
    			    set a $_a
                }
    			if { $b == "" || $b < $_b } {
    			    set b $_b
                }
    		}
        }
        
        if { $a == "" } {
            set a 0.0; set b 1.0
        } 

    	return [measure::chart::limits $a $b]
	}
	
	proc ::measure::chart::${canvas}::doPlot {} {
		variable xValues
		variable yValues
		variable chartBgColor
		variable canvas
		variable options
		variable seriesColor

		$canvas delete all

		set s [::Plotchart::createXYPlot $canvas [makeXLimits] [makeYLimits]]
		foreach series [array names seriesColor] {
    		$s dataconfig $series -colour $seriesColor($series)
    		$s dotconfig $series -colour $seriesColor($series)
        }
		$s xtext $options(xlabel)
		$s xconfig -format %2g
		$s ytext $options(ylabel)
		$s yconfig -format %2g

		if { ![info exists chartBgColor] } {
			set chartBgColor [$canvas cget -bg]
		}
		$s background plot black
		$s background axes $chartBgColor

        foreach series [array names xValues] {
    		foreach x $xValues($series) y $yValues($series) {
                if { $options(lines) } {
        			$s plot $series $x $y
                }
                if { $options(dots) } {
        			$s dot $series $x $y 3
        		}
    		}
        }
	}

	proc ::measure::chart::${canvas}::doResize {} {
		doPlot
	}

	proc ::measure::chart::${canvas}::series { series args } {
    	set opts {
    		{color.arg		"green"	"Series color"}
    		{maxCount.arg	""	"Max number of points on chart"}
    	}
    
    	set usage ": series series-name \[options]\noptions:"
    	array set options [::cmdline::getoptions args $opts $usage]
    	
		variable seriesColor
		variable seriesMaxCount
		
        set seriesColor($series) $options(color) 
        set seriesMaxCount($series) $options(maxCount) 
	
		doPlot
	}
	
	set ::measure::chart::${canvas}::canvas $canvas
	set ::measure::chart::${canvas}::chartValues [list]
	array set ::measure::chart::${canvas}::options [array get options]

	bind $canvas <Configure> "::measure::chart::${canvas}::doResize"

}