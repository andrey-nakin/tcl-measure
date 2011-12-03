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
	1.0e-1	0.000035
	1.0e-0	0.000007
	1.0e1	0.000005
	1.0e2	0.000006
	1.0e3	0.000006
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
	1.0e-4	0.00025
	1.0e-3	0.00006
	1.0e-2	0.00020
	1.0e-1	0.00005
	1.0e0	0.00010
	3.0e0	0.00020
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
	1.0e2	0.00004
	1.0e3	0.00001
	1.0e4	0.00001
	1.0e5	0.00001
	1.0e6	0.00001
	1.0e7	0.00001
	1.0e8	0.00001
	1.0e9	0.00001
}

# Calculates and returns systematic DC voltage measure error
# Automatic ranging mode is assumed.
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
# Automatic ranging mode is assumed.
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
# Automatic ranging mode is assumed.
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
		if { $value <= $maxval } {
			set reading [expr $value * $err]
			break
		}
	}

	foreach { maxval err } $rangeErrors {
		if { $value <= $maxval } {
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

    # устанавливаем параметры канала
    scpi::configure $channel
    
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

