# sigma.tcl --
#
#   Measurement error calculations
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::sigma 0.2.0

package require math::statistics

namespace eval measure::sigma {
  namespace export mul div
}

set measure::sigma::n_values { 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 40 60 120 999999999 }
set measure::sigma::student_800_values { 3.078 1.886 1.638 1.533 1.476 1.44 1.415 1.397 1.383 1.372 1.363 1.356 1.35 1.345 1.341 1.337 1.333 1.33 1.328 1.325 1.323 1.321 1.319 1.318 1.316 1.315 1.314 1.313 1.311 1.31 1.303 1.296 1.289 1.282 }
set measure::sigma::student_950_values { 12.706 4.303 3.182 2.776 2.571 2.447 2.365 2.306 2.262 2.228 2.201 2.179 2.16 2.145 2.131 2.12 2.11 2.101 2.093 2.086 2.08 2.074 2.069 2.064 2.06 2.056 2.052 2.048 2.045 2.042 2.021 2.0 1.98 1.96 }
set measure::sigma::student_990_values { 63.657 9.925 5.841 4.604 4.032 3.707 3.499 3.355 3.25 3.169 3.106 3.055 3.012 2.977 2.947 2.921 2.898 2.878 2.861 2.845 2.831 2.819 2.807 2.797 2.787 2.779 2.771 2.763 2.756 2.75 2.704 2.66 2.617 2.576 }
set measure::sigma::student_999_values { 636.61 31.598 12.941 8.61 6.859 5.959 5.405 5.041 4.781 4.587 4.437 4.318 4.221 4.14 4.073 4.015 3.965 3.922 3.883 3.85 3.819 3.792 3.767 3.745 3.725 3.707 3.69 3.674 3.659 3.646 3.551 3.46 3.373 3.291 }

# Calculate error of sum of several values
# Arguments
#   args - value errors
# Return
#   error calculated
proc measure::sigma::add { args } {
	set sum 0.0

	foreach e $args {
        if { $e != "" } {	
		  set sum [expr $sum + $e * $e]
		}
	}

	return [expr sqrt($sum)]
}

# Calculate error of multiplication of several values
# Arguments
#   args - (value, error) pairs
# Return
#   error calculated
proc measure::sigma::mul { args } {
	set sum 0.0

	for { set i 0 } { $i < [llength $args] } { incr i } {
		set m 1.0
		for { set j 0 } { $j < [llength $args] } { incr j 2 } {
			if { $j != $i } {
				set m [expr $m * [lindex $args $j]]
			}
		}

		incr i
		set a [expr $m * [lindex $args $i]]
		set sum [expr $sum + $a * $a]
	}

	return [expr sqrt($sum)]
}

# Calculate error of multiplication of two values
# Arguments
#   values - list of two (value, error) pairs
# Return
#   error calculated
proc measure::sigma::div { a da b db } {
    if { abs($b) < 1.0e-15 } {
        return 0.0
    }
	set x [expr $db * $a / $b]
	return [expr 1.0 / $b * sqrt($da * $da + $x * $x)]
}

proc measure::sigma::sin { a da } {
	return [expr 0.5 * abs( sin($a + $da) - sin($a - $da) )]
}

proc measure::sigma::pow3 { a da } {
	return [measure::sigma::mul $a $da $a $da $a $da]
}

## Returns Student coefficient (pre-calculated & tabularized)
# Arguments
#   n - degree of freedom (integer number)
#   confLevel - confidence level (number between 0 and 1)
# Return
#   Nearest Student coefficient
proc measure::sigma::student-coeff { n { confLevel 0.95 } } {
	variable student_800_values
	variable student_950_values
	variable student_990_values
	variable student_999_values
	variable n_values

	if { $confLevel > 0.991 } {
		set lname student_999_values
	} elseif { $confLevel > 0.951 } {
		set lname student_990_values
	} elseif { $confLevel > 0.801 } {
		set lname student_950_values
	} else {
		set lname student_800_values
	}

	set idx 0
	foreach nn $n_values {	
		if { $nn >= $n } {
			break
		}
		incr idx
	} 

	eval "set res \[lindex \$$lname $idx\]"
	return $res
}

## Calculates mean value and estimated error of given sample
# Arguments
#   a - sample (list of numbers)
#   confLevel - confidence level (number between 0 and 1)
# Return
#   list of two values: mean and error
proc measure::sigma::sample { a { confLevel 0.95 } } {
	set n [llength $a]

	if { $n == 0 } {
		return { 0.0 0.0 }
	}
	if { $n == 1 } {
		return { [lindex $a 0] 0.0 }
	}
	
	lassign [::math::statistics::basic-stats $a] mean _ _ _ sample_std
	return [list $mean [expr $sample_std / sqrt($n) * [student-coeff $n $confLevel]] ]
}

