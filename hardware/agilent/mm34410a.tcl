# mm34410a.tcl --
#
#   Work with Agilent 34410A multimeter
#   http://www.home.agilent.com/agilent/product.jspx?id=692834&pageMode=OV&pid=692834&lc=eng&ct=PRODUCT&cc=US&pselect=SR.PM-Search%20Results.Overview
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide hardware::agilent::mm34410a 0.1.0

package require hardware::scpi

namespace eval hardware::agilent::mm34410a {
  namespace export \
    resistanceSystematicError \
    dcvSystematicError \
    dciSystematicError  \
	init	\
	done
}

set hardware::agilent::mm34410a::IDN "Agilent Technologies,34410A"

set hardware::agilent::mm34410a::dcvReadingErrors {
	1.0e-1	0.000040
	1.0e-0	0.000030
	1.0e1	0.000020
	1.0e2	0.000035
	1.0e3	0.000020
}

set hardware::agilent::mm34410a::dcvRangeErrors {
	1.0e-1	0.000040
	1.0e-0	0.000012
	1.0e1	0.000010
	1.0e2	0.000011
	1.0e3	0.000011
}

set hardware::agilent::mm34410a::dciReadingErrors {
	1.0e-4	0.00040
	1.0e-3	0.00030
	1.0e-2	0.00030
	1.0e-1	0.00030
	1.0e0	0.00080
	3.0e0	0.00120
}

set hardware::agilent::mm34410a::dciRangeErrors {
	1.0e-4	0.000255
	1.0e-3	0.000065
	1.0e-2	0.000205
	1.0e-1	0.000055
	1.0e0	0.000105
	3.0e0	0.000205
}

set hardware::agilent::mm34410a::resistance4wReadingErrors {
	1.0e2	0.00008
	1.0e3	0.00007
	1.0e4	0.00007
	1.0e5	0.00007
	1.0e6	0.00010
	1.0e7	0.00030
	1.0e8	0.00600
	1.0e9	0.06000
}

set hardware::agilent::mm34410a::resistance4wRangeErrors {
	1.0e2	0.000045
	1.0e3	0.000015
	1.0e4	0.000015
	1.0e5	0.000015
	1.0e6	0.000015
	1.0e7	0.000015
	1.0e8	0.000015
	1.0e9	0.000015
}

set hardware::agilent::mm34410a::nplcs { 0.006 0.02 0.06 0.2 1 2 10 100 }

set hardware::agilent::mm34410a::powerFrequency 50.0

set hardware::agilent::mm34410a::dcvRanges { 100.0e-3 1.0 10.0 100.0 1000.0 }

set hardware::agilent::mm34410a::dciRanges { 100.0e-6 1.0e-3 10.0e-3 100.0e-3 1.0 3.0 }

# Calculates and returns systematic DC voltage measure error
# Automatic ranging mode is assumed. NPLC=10
# We use "90 Day" error with Tcal +/- 5 C
# Arguments
#   voltage - voltage value measured in volts
# Returns
#   Absolute error.
proc hardware::agilent::mm34410a::dcvSystematicError { voltage } {
	global hardware::agilent::mm34410a::dcvReadingErrors
	global hardware::agilent::mm34410a::dcvRangeErrors

	return [systematicError $voltage $dcvReadingErrors $dcvRangeErrors]
}

# Calculates and returns systematic DC current measure error
# Automatic ranging mode is assumed. NPLC=10
# We use "90 Day" error with Tcal +/- 5 C
# Arguments
#   current - current value measured in ampers
# Returns
#   Absolute error.
proc hardware::agilent::mm34410a::dciSystematicError { current } {
	global hardware::agilent::mm34410a::dciReadingErrors
	global hardware::agilent::mm34410a::dciRangeErrors

	return [systematicError $current $dciReadingErrors $dciRangeErrors]
}

# Calculates and returns systematic resistance measure error
#   for 4-wire method
# Automatic ranging mode is assumed. NPLC=10
# We use "90 Day" error with Tcal +/- 5 C
# Arguments
#   resistance - resistance value measured in ohms
# Returns
#   Absolute error.
proc hardware::agilent::mm34410a::resistanceSystematicError { resistance } {
	global hardware::agilent::mm34410a::resistance4wReadingErrors
	global hardware::agilent::mm34410a::resistance4wRangeErrors

	return [systematicError $resistance $resistance4wReadingErrors $resistance4wRangeErrors]
}

proc hardware::agilent::mm34410a::systematicError { value readingErrors rangeErrors } {
	set reading 0.0
	set range 0.0

	foreach { maxval err } $readingErrors {
		if { $value <= $maxval * 1.0 } {
			set reading [expr $value * $err]
			break
		}
	}

	foreach { maxval err } $rangeErrors {
		if { $value <= $maxval * 1.0 } {
			set range [expr $maxval * $err]
			break
		}
	}

	return [expr $reading + $range]
}

# Производит инициализацию и опрос устройства
# Аргументы
#   channel - канал с открытым портом для связи с устройством
proc hardware::agilent::mm34410a::init { channel } {
    global hardware::agilent::mm34410a::IDN

    # очищаем выходной буфер
	scpi::clear $channel

    # производим опрос устройства
	scpi::validateIdn $channel $IDN

	# в исходное состояние
    scpi::cmd $channel "*RST;*CLS"
}

# Переводит устройство в исходное состояние
# Аргументы
#   channel - канал с открытым портом для связи с устройством
proc hardware::agilent::mm34410a::done { channel } {
    scpi::cmd $channel "*RST"
}

# Вычисляет и вовзвращает максимально возможное значение параметра NPLC
#   для указанного интервала измерений
# Аргументы
#   interval - интервал измерений в секундах
# Результат
#   значение параметра NPLC
proc hardware::agilent::mm34410a::nplc { interval } {
	global hardware::agilent::mm34410a::nplcs
	global hardware::agilent::mm34410a::powerFrequency
    
    set result [lindex $nplcs 0]

    foreach nplc $nplcs {
        if { 1.0 / $powerFrequency * $nplc < $interval * 0.95 } {
            set result $nplc
        }
    }
    
    return $result
}

# Определяет оптимальный диапазон измерения постоянного тока для указанного значения
# Аргументы
#   
proc hardware::agilent::mm34410a::dciRange { value } {
	global hardware::agilent::mm34410a::dciRanges
	
	set result [lindex $dciRanges end]

	for { set i [expr [llength $dciRanges] - 1 } { $i >= 0 } { incr i -1 } {
		set max [lindex $dciRanges $i]
		if { $max * 1.2 > $value } {
			set result $max
		} else {
			break
		}
	}

	return $result
}

