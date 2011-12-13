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

# 90 Day, Tcal ± 5 °C, NPLC = 100
set hardware::agilent::mm34410a::dcvReadingErrors {
	1.0e-1	0.000040
	1.0e-0	0.000030
	1.0e1	0.000020
	1.0e2	0.000035
	1.0e3	0.000035
}

# 90 Day, Tcal ± 5 °C, NPLC = 100
set hardware::agilent::mm34410a::dcvRangeErrors {
	1.0e-1	0.000035
	1.0e-0	0.000007
	1.0e1	0.000005
	1.0e2	0.000006
	1.0e3	0.000006
}

# 0.1 DCV range, Autozero for => 1 NPLC
set hardware::agilent::mm34410a::dcvNplcAdder0_1 {
	0.006	0.000600
	0.02	0.000300
	0.06	0.000200
	0.2		0.000150
	1.0		0.000010
	2.0		0.000010
	10.0	0.000005
	100.0	0.000000
}

# 1, 100 DCV ranges, Autozero for => 1 NPLC
set hardware::agilent::mm34410a::dcvNplcAdder1 {
	0.006	0.000040
	0.02	0.000030
	0.06	0.000020
	0.2		0.000015
	1.0		0.000001
	2.0		0.000001
	10.0	0.000000
	100.0	0.000000
}

# 10, 1000 DCV ranges, Autozero for => 1 NPLC
set hardware::agilent::mm34410a::dcvNplcAdder10 {
	0.006	0.000012
	0.02	0.000006
	0.06	0.000003
	0.2		0.000002
	1.0		0.000000
	2.0		0.000000
	10.0	0.000000
	100.0	0.000000
}

# 90 Day, Tcal ± 5 °C, NPLC = 100
set hardware::agilent::mm34410a::dciReadingErrors {
	1.0e-4	0.00040
	1.0e-3	0.00030
	1.0e-2	0.00030
	1.0e-1	0.00030
	1.0e0	0.00080
	3.0e0	0.00120
}

# 90 Day, Tcal ± 5 °C, NPLC = 100
set hardware::agilent::mm34410a::dciRangeErrors {
	1.0e-4	0.00025
	1.0e-3	0.00006
	1.0e-2	0.00020
	1.0e-1	0.00005
	1.0e0	0.00010
	3.0e0	0.00020
}

# Autozero for => 1 NPLC
set hardware::agilent::mm34410a::dciNplcAdder {
	0.006	0.000600
	0.02	0.000300
	0.06	0.000200
	0.2		0.000150
	1.0		0.000010
	2.0		0.000010
	10.0	0.000005
	100.0	0.000000
}

# 90 Day, Tcal ± 5 °C, NPLC = 100
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

# 90 Day, Tcal ± 5 °C, NPLC = 100
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

# 100 Ohm range, Autozero for => 1 NPLC
set hardware::agilent::mm34410a::resNplcAdder100 {
	0.006	0.000600
	0.02	0.000300
	0.06	0.000200
	0.2		0.000150
	1.0		0.000010
	2.0		0.000010
	10.0	0.000005
	100.0	0.000000
}

# 1K, 10K Ohm ranges, Autozero for => 1 NPLC
set hardware::agilent::mm34410a::resNplcAdder1000 {
	0.006	0.000040
	0.02	0.000030
	0.06	0.000020
	0.2		0.000015
	1.0		0.000001
	2.0		0.000001
	10.0	0.000000
	100.0	0.000000
}

set hardware::agilent::mm34410a::nplcs { 0.006 0.02 0.06 0.2 1 2 10 100 }

set hardware::agilent::mm34410a::powerFrequency 50.0

set hardware::agilent::mm34410a::dcvRanges { 100.0e-3 1.0 10.0 100.0 1000.0 }

set hardware::agilent::mm34410a::dciRanges { 100.0e-6 1.0e-3 10.0e-3 100.0e-3 1.0 3.0 }

set hardware::agilent::mm34410a::resistanceRanges { 100.0 1.0e3 10.0e3 100.0e3 1.0e6 10.0e6 100.0e6 1.0e9 }

# Calculates and returns systematic DC voltage measure error
# Automatic ranging mode is assumed. NPLC=10
# We use "90 Day" error with Tcal +/- 5 C
# Arguments
#   voltage - voltage value measured in volts
#   range - measurement range in volts. In omitted, min possible range is assumed
#   nplc - value of NPLC parameter. If omitted, max possible value is assumed
# Returns
#   Absolute error.
proc hardware::agilent::mm34410a::dcvSystematicError { voltage { range "" } { nplc "" } } {
	global hardware::agilent::mm34410a::dcvReadingErrors
	global hardware::agilent::mm34410a::dcvRangeErrors

	return [systematicError $voltage $dcvReadingErrors $dcvRangeErrors $range $nplc "getDcvNplcAdder"]
}

# Calculates and returns systematic DC current measure error
# Automatic ranging mode is assumed. NPLC=10
# We use "90 Day" error with Tcal +/- 5 C
# Arguments
#   current - current value measured in ampers
#   range - measurement range in ampers. In omitted, min possible range is assumed
#   nplc - value of NPLC parameter. If omitted, max possible value is assumed
# Returns
#   Absolute error.
proc hardware::agilent::mm34410a::dciSystematicError { current { range "" } { nplc "" } } {
	global hardware::agilent::mm34410a::dciReadingErrors
	global hardware::agilent::mm34410a::dciRangeErrors

	return [systematicError $current $dciReadingErrors $dciRangeErrors $range $nplc "getDciNplcAdder"]
}

# Calculates and returns systematic resistance measure error
#   for 4-wire method
# Automatic ranging mode is assumed. NPLC=10
# We use "90 Day" error with Tcal +/- 5 C
# Arguments
#   resistance - resistance value measured in ohms
#   range - measurement range in ohms. In omitted, min possible range is assumed
#   nplc - value of NPLC parameter. If omitted, max possible value is assumed
# Returns
#   Absolute error.
proc hardware::agilent::mm34410a::resistanceSystematicError { resistance { range "" } { nplc "" } } {
	global hardware::agilent::mm34410a::resistance4wReadingErrors
	global hardware::agilent::mm34410a::resistance4wRangeErrors

	return [systematicError $resistance $resistance4wReadingErrors $resistance4wRangeErrors $range $nplc "getResNplcAdder"]
}

proc hardware::agilent::mm34410a::systematicError { value readingErrors rangeErrors range nplc adderFunc} {
	set delta [expr 1.0 + 1.0e-6]

	# determine reading error
	set err 0.0
	foreach { maxval err } $readingErrors {
		if { $range != "" } {
			if { $range <= $maxval * $delta } {
				break
			}
		} else {
			if { $value <= $maxval * $delta } {
				break
			}
		}
	}
	set readingErr [expr $value * $err]

	# determine range error
	set maxval 0.0
	set err 0.0
	foreach { maxval err } $rangeErrors {
		if { $range != "" } {
			if { $range <= $maxval * $delta } {
				break
			}
		} else {
			if { $value <= $maxval * $delta } {
				break
			}
		}
	}

	# determine NPLC rms noise adder
	set adder 0.0
	if { $nplc != "" && $adderFunc != "" } {
		set adder [$adderFunc $maxval $nplc]
	}

	set rangeErr [expr $maxval * ($err + $adder)]

	return [expr $readingErr + $rangeErr]
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

proc hardware::agilent::mm34410a::getDcvNplcAdder { range nplc } {
	global hardware::agilent::mm34410a::dcvNplcAdder0_1
	global hardware::agilent::mm34410a::dcvNplcAdder1
	global hardware::agilent::mm34410a::dcvNplcAdder10

	set delta [expr 1.0 + 1.0e-6]
	set tbl $dcvNplcAdder10

	if { $range <= 1000.0 * $delta } {
		set tbl $dcvNplcAdder10
	}
	if { $range <= 100.0 * $delta } {
		set tbl $dcvNplcAdder1
	}
	if { $range <= 10.0 * $delta } {
		set tbl $dcvNplcAdder10
	}
	if { $range <= 1.0 * $delta } {
		set tbl $dcvNplcAdder1
	}
	if { $range <= 0.1 * $delta } {
		set tbl $dcvNplcAdder0_1
	}

	return [getAdder $tbl $nplc]
}

proc hardware::agilent::mm34410a::getDciNplcAdder { range nplc } {
	global hardware::agilent::mm34410a::dciNplcAdder

	return [getAdder $dciNplcAdder $nplc]
}

proc hardware::agilent::mm34410a::getResNplcAdder { range nplc } {
	global hardware::agilent::mm34410a::resNplcAdder100
	global hardware::agilent::mm34410a::resNplcAdder1000

	set delta [expr 1.0 + 1.0e-6]
	set tbl $resNplcAdder100

	if { $range * $delta >= 1000.0 } {
		set tbl $resNplcAdder1000
	}

	return [getAdder $tbl $nplc]
}

proc hardware::agilent::mm34410a::getAdder { tbl nplc } {
	set delta [expr 1.0 + 1.0e-6]
	set result [lindex $tbl 0]

	foreach { n adder } $tbl {
		if { $nplc * $delta >= $n } {
			set result $adder
		} else {
			break
		}
	}

	return $result
}

