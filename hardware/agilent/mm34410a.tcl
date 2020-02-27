# mm34410a.tcl --
#
#   Work with Agilent 34410A multimeter
#   http://www.home.agilent.com/agilent/product.jspx?id=692834&pageMode=OV&pid=692834&lc=eng&ct=PRODUCT&cc=US&pselect=SR.PM-Search%20Results.Overview
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide hardware::agilent::mm34410a 0.1.0

package require cmdline
package require scpi
package require hardware::agilent::utils

namespace eval hardware::agilent::mm34410a {
  namespace export \
    resistanceSystematicError \
    dcvSystematicError \
    dciSystematicError  \
	init	\
	done	\
	configureDcVoltage	\
	configureDcCurrent	\
	checkFrontRear
}

set hardware::agilent::mm34410a::IDN "Agilent Technologies,34410A"

set hardware::agilent::mm34410a::SCPI_VERSION 1994.0

set hardware::agilent::mm34410a::baudRates {  300 600 1200 2400 4800 9600 }

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

set hardware::agilent::mm34410a::supportedIds { "^Agilent Technologies,34410A,.*" "^HEWLETT-PACKARD,34401A,.*" "^V7-28,*" "^AKIP V7-78-1*" }

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

# Определяет величину тестового тока для измерения сопротивления омметром
# Аргументы
#   r - значение сопротивления в Ом (в режиме автоматического выбора диапазона)
#       или какое-нибудь значение из нужно диапазона (верхний предел не включается)
# Результат
#   Тестовый ток в мА
proc hardware::agilent::mm34410a::testCurrent { r } {
    set ranges { 1.0e2 1.0e3 1.0e4 1.0e5 1.0e6 1.0e7 }
    set currents { 0.1 1.0 0.1 0.01 0.025 0.0025 }
    
    set i 0
    foreach rr $ranges {
        if { $rr > $r } {
            return [lindex $currents $i]
        }
        incr i 
    }
    
    return [lindex $currents $i-1]
}

# Производит открытие устройства
proc hardware::agilent::mm34410a::open { args } {
	return [hardware::agilent::utils::open "e" {*}$args]
}

# Производит инициализацию и опрос устройства
# Аргументы
#   channel - канал с открытым портом для связи с устройством
proc hardware::agilent::mm34410a::init { args } {
    global hardware::agilent::mm34410a::SCPI_VERSION log

	set options {
		{noFrontCheck			""	""}
	}

	set usage ": init \[options] channel\noptions:"
	array set params [::cmdline::getoptions args $options $usage]

	set channel [lindex $args 0]

    # очищаем выходной буфер
	#scpi::clear $channel

    # производим опрос устройства
    #scpi::validateScpiVersion $channel $SCPI_VERSION 

	# в исходное состояние
    scpi::cmd $channel "*RST;*CLS"
    after 500

    if { [scpi::isSerialChannel $channel] } {
    	# включаем удалённый доступ
        scpi::cmd $channel "SYSTEM:REMOTE"
    }
    
    # включаем режим совместимости с Agilent 34401A
    #scpi::cmd $channel {SYSTEM:LANGUAGE "34401A"}
    
    if { ![info exists params(noFrontCheck)] } {
    	# Проверяем состояние переключателя front/rear
    	hardware::agilent::mm34410a::checkFrontRear $channel
    } 
}

# Производит опрос устройства и возвращает результат
# Аргументы:
#   args - параметры устройства, такие же, как в процедуре open
# Результат: целочисленное значение:
#   > 0 - опросо произведён успешно
#  0 - нет связи или неверные параметры устройства
#  -1 - устройство не является мультиметром
proc hardware::agilent::mm34410a::test { args } {
	set result 0
	global log 
    variable supportedIds

	catch {
		set mm [open {*}$args]

		# производим опрос устройства
		set id [scpi::query $mm "*IDN?"]
		if { $id != "" } {
		    set result -1
    		foreach sid $supportedIds {
                if {[regexp -nocase $sid $id]} {
                    set result 1
                    break
                }
            }
        }

		close $mm
	} rc inf

	return $result
}

# Переводит устройство в исходное состояние
# Аргументы
#   channel - канал с открытым портом для связи с устройством
proc hardware::agilent::mm34410a::done { channel } {
	if { $channel == "" } {
		return
	}

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

set hardware::agilent::mm34410a::configOptions {
	{nplc.arg			10	"NPLC"}
	{autoRange.arg		ON	"auto ranging: on, off or once"}
	{autoZero.arg		ON	"auto zero: on or off"}
	{triggerDelay.arg	DEF		"trigger delay"}
	{sampleCount.arg	1	"sample count"}
	{sampleInterval.arg	""		"sample interval"}
	{scpiVersion.arg	""		"Min valid SCPI version"}
	{text2.arg	        ""		"Text to show on secondary display"}
}

# Производит конфигурацию устройства для измерения постоянного напряжения
# Опции
#   nplc - число циклов линии питания, по умолчанию 10
#   autoRange - режим автоподстройки диапазона, может быть on или off. По умолчанию on
#   autoZero - режим автоподстройки нуля, может быть on, off или once. По умолчанию on
#   triggerDelay - пауза срабатывания триггера, по умолчанию DEF
#   sampleCount - число измерений на одно срабатывание триггера, по умолчанию 1
#   sampleInterval - интервал между измерениями, по умолчанию не указан
#   scpiVersion - минимальная необходимая версия языка SCPI, например 1994.0.
#   text2 - текст для вывода на дисплее №2 мультиметра. Если нет поддержки мультиметра, опция игнорируется.
proc hardware::agilent::mm34410a::configureDcVoltage { args } {
	variable configOptions
	variable SCPI_VERSION
    
	set usage ": configureDcVoltage \[options] channel\noptions:"
	array set params [::cmdline::getoptions args $configOptions $usage]

	set mm [lindex $args 0]
	
	# Определим версию протокола SCPI
	set version [string trim [scpi::query $mm "SYSTEM:VERSION?"]]
	
	# Проверим правильность версии SCPI
	if { $params(scpiVersion) != "" && $params(scpiVersion) > $version } {
	   error "SCPI version is $version, but $params(scpiVersion) required";
    }

	# включаем режим измерения пост. напряжения
	scpi::cmd $mm "CONFIGURE:VOLTAGE:DC AUTO"

    # Включить авытовыбор диапазона
    scpi::cmd $mm "SENSE:VOLTAGE:DC:RANGE:AUTO $params(autoRange)"
    
    if { $version >= $SCPI_VERSION } {
        # Включить нужный режим автоподстройки нуля
        scpi::cmd $mm "SENSE:VOLTAGE:DC:ZERO:AUTO $params(autoZero)"

        # Включить автоподстройку входного сопротивления
        scpi::cmd $mm "SENSE:VOLTAGE:DC:IMPEDANCE:AUTO ON"
        
        if { $params(text2) != "" } {
            # Отобразим текст на дисплее мультиметра
            scpi::cmd $mm "DISPLAY:WINDOW2:TEXT \"$params(text2)\""
        }
    } else {
        # Включить нужный режим автоподстройки нуля
        scpi::cmd $mm "SENSE:ZERO:AUTO $params(autoZero)"
    }

	if { $params(sampleInterval) != "" } {
		# Измерять напряжение в течении макс. возможного кол-ва циклов питания
		set params(nplc) [hardware::agilent::mm34410a::nplc $params(sampleInterval)]
	} else {
		# Измерять напряжение в течении указанного кол-ва циклов питания
		if { $params(nplc) == "" } {
			set params(nplc) 10
		}
	}
	scpi::cmd $mm "SENSE:VOLTAGE:DC:NPLC $params(nplc)"
	checkTimeout $mm [minTimeout $params(nplc)]

	# Настраиваем триггер
    #scpi::cmd $mm "TRIGGER:SOURCE IMMEDIATE"
	if { $params(triggerDelay) == "" } {
		set params(triggerDelay) DEF
	}
	if { ![string equal -nocase $params(triggerDelay) "DEF"] } {
	    scpi::cmd $mm ":TRIGGER:DELAY $params(triggerDelay)"
	}
    if { $version >= $SCPI_VERSION } {
    	if { $params(sampleInterval) != "" } {
    		# Настраиваем периодический съём сигнала
    		scpi::cmd $mm ":SAMPLE:SOURCE TIMER"
    		scpi::cmd $mm ":SAMPLE:TIMER $params(sampleInterval)"
    	} else {
            if { $version >= $SCPI_VERSION } {
    	   	   # Настраиваем непрерывный съём сигнала
    	       scpi::cmd $mm ":SAMPLE:SOURCE IMMEDIATE"
    	    }
    	}
    }
    scpi::cmd $mm ":SAMPLE:COUNT $params(sampleCount)"

	# Проверяем отсутствие ошибки
	scpi::checkError $mm
	
	after 500
}

# Производит конфигурацию устройства для измерения постоянного тока
# Опции - такие же, как у процедуры configureDcVoltage
proc hardware::agilent::mm34410a::configureDcCurrent { args } {
	variable configOptions
	variable SCPI_VERSION

	set usage ": configureDcCurrent \[options] channel\noptions:"
	array set params [::cmdline::getoptions args $configOptions $usage]

	set mm [lindex $args 0]

	# Определим версию протокола SCPI
	set version [scpi::query $mm "SYSTEM:VERSION?"]

	# Проверим правильность версии SCPI
	if { $params(scpiVersion) != "" && $params(scpiVersion) > $version } {
	   error "SCPI version is $version, but $params(scpiVersion) required";
    }
    
	# включаем режим измерения пост. напряжения
	scpi::cmd $mm "CONFIGURE:CURRENT:DC AUTO"

    # Включить авытовыбор диапазона
	if { $params(autoRange) == "" } {
		set params(autoRange) ON
	}
    scpi::cmd $mm "SENSE:CURRENT:DC:RANGE:AUTO $params(autoRange)"
    
    # Включить нужный режим автоподстройки нуля
	if { $params(autoZero) == "" } {
		set params(autoZero) ON
	}
    if { $version >= $SCPI_VERSION } {
        scpi::cmd $mm "SENSE:CURRENT:DC:ZERO:AUTO $params(autoZero)"
        
        if { $params(text2) != "" } {
            # Отобразим текст на дисплее мультиметра
            scpi::cmd $mm "DISPLAY:WINDOW2:TEXT \"$params(text2)\""
        }
    } else {
        scpi::cmd $mm "SENSE:ZERO:AUTO $params(autoZero)"
    }

	if { $params(sampleInterval) != "" } {
		# Измерять напряжение в течении макс. возможного кол-ва циклов питания
		set params(nplc) [hardware::agilent::mm34410a::nplc $params(sampleInterval)]
	} else {
		# Измерять напряжение в течении указанного кол-ва циклов питания
		if { $params(nplc) == "" } {
			set params(nplc) 10
		}
	}
	scpi::cmd $mm "SENSE:CURRENT:DC:NPLC $params(nplc)"
	checkTimeout $mm [minTimeout $params(nplc)]
    
	# Настраиваем триггер
    #scpi::cmd $mm "TRIGGER:SOURCE IMMEDIATE"
	if { $params(triggerDelay) == "" } {
		set params(triggerDelay) DEF
	}
	if { ![string equal -nocase $params(triggerDelay) "DEF"] } {
	    scpi::cmd $mm "TRIGGER:DELAY $params(triggerDelay)"
	}
	if { $params(sampleInterval) != "" } {
		# Настраиваем периодический съём сигнала
		scpi::cmd $mm "SAMPLE:SOURCE TIMER"
		scpi::cmd $mm "SAMPLE:TIMER $params(sampleInterval)"
	} else {
        if { $version >= $SCPI_VERSION } {
	   	   # Настраиваем непрерывный съём сигнала
	       scpi::cmd $mm "SAMPLE:SOURCE IMMEDIATE"
	    }
	}
    scpi::cmd $mm "SAMPLE:COUNT $params(sampleCount)"

	# Проверяем отсутствие ошибки
	scpi::checkError $mm
	
	after 500
}

# Производит конфигурацию устройства для измерения сопротивления
# 4-х контактным способом
proc hardware::agilent::mm34410a::configureResistance4w { args } {
	variable configOptions
	variable SCPI_VERSION
    
	set usage ": configureResistance4w \[options] channel\noptions:"
	array set params [::cmdline::getoptions args $configOptions $usage]

	set mm [lindex $args 0]
	
	# Определим версию протокола SCPI
	set version [scpi::query $mm "SYSTEM:VERSION?"]
	
	# Проверим правильность версии SCPI
	if { $params(scpiVersion) != "" && $params(scpiVersion) > $version } {
	   error "SCPI version is $version, but $params(scpiVersion) required";
    }

	# включаем режим измерения пост. напряжения
	scpi::cmd $mm "CONFIGURE:FRESISTANCE AUTO"

    # Включить авытовыбор диапазона
    scpi::cmd $mm "SENSE:FRESISTANCE:RANGE:AUTO $params(autoRange)"
    
    if { $version >= $SCPI_VERSION } {
        # Включить режим автокомпенсации
        scpi::cmd $mm "SENSE:FRESISTANCE:OCOM ON"
        
        if { $params(text2) != "" } {
            # Отобразим текст на дисплее мультиметра
            scpi::cmd $mm "DISPLAY:WINDOW2:TEXT \"$params(text2)\""
        }
    } else {
        # Включить нужный режим автоподстройки нуля
        scpi::cmd $mm "SENSE:ZERO:AUTO $params(autoZero)"
    }

	if { $params(sampleInterval) != "" } {
		# Измерять напряжение в течении макс. возможного кол-ва циклов питания
		set params(nplc) [hardware::agilent::mm34410a::nplc $params(sampleInterval)]
	} else {
		# Измерять напряжение в течении указанного кол-ва циклов питания
		if { $params(nplc) == "" } {
			set params(nplc) 10
		}
	}
	scpi::cmd $mm "SENSE:FRESISTANCE:NPLC $params(nplc)"
	checkTimeout $mm [minTimeout $params(nplc)]

	# Настраиваем триггер
    #scpi::cmd $mm "TRIGGER:SOURCE IMMEDIATE"
	if { $params(triggerDelay) == "" } {
		set params(triggerDelay) DEF
	}
	if { ![string equal -nocase $params(triggerDelay) "DEF"] } {
	    scpi::cmd $mm ":TRIGGER:DELAY $params(triggerDelay)"
	}
    if { $version >= $SCPI_VERSION } {
    	if { $params(sampleInterval) != "" } {
    		# Настраиваем периодический съём сигнала
    		scpi::cmd $mm ":SAMPLE:SOURCE TIMER"
    		scpi::cmd $mm ":SAMPLE:TIMER $params(sampleInterval)"
    	} else {
            if { $version >= $SCPI_VERSION } {
    	   	   # Настраиваем непрерывный съём сигнала
    	       scpi::cmd $mm ":SAMPLE:SOURCE IMMEDIATE"
    	    }
    	}
    }
    scpi::cmd $mm ":SAMPLE:COUNT $params(sampleCount)"

	# Проверяем отсутствие ошибки
	scpi::checkError $mm
	
	after 500
}

# Вычисляет продолжительность одного измерения напряжения или тока.
# Опции - такие же, как у процедур configureDcVoltage, configureDcCurrent 
# Возвращаемое значение
#   продолжительность измерения в мс
proc hardware::agilent::mm34410a::measDur { args } {
	variable configOptions
	variable SCPI_VERSION
	variable powerFrequency
    
	array set params [::cmdline::getoptions args $configOptions ": measDur \[options]\noptions:"]

	if { [string compare -nocase $params(autoZero) "ON"] == 0 } {
		set autoZero 2
	} else {
		set autoZero 1
	}
    
    return [expr int(1000.0 / $powerFrequency * $params(nplc) * $autoZero * $params(sampleCount))]
}

# Проверяет положение переключателя Front/Rear
# Если оно не равно нужному, выбрасывает ошибку
# Аргументы
#   channel - канал связи с мультиметром
#   required - нужное положение переключателя, может быть FRON или REAR
proc hardware::agilent::mm34410a::checkFrontRear { channel { required "FRON" } } {
    set pos [string range [scpi::query $channel "ROUTE:TERMINALS?"] 0 3]
	if { $pos != $required } {
		if { [string equal -nocase $required "FRON"] } {
			set required "Front"
		} else {
			set required "Rear"
		}
		error "Turn Front/Rear switch of Agilent multimeter to \"$required\""
	}
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

proc hardware::agilent::mm34410a::minTimeout { nplc } {
    global hardware::agilent::mm34410a::powerFrequency 
	return [expr int(1.0 / $powerFrequency * $nplc * 2500)]
} 

proc hardware::agilent::mm34410a::checkTimeout { channel timeout } {
    catch {
    	if { [fconfigure $channel -timeout] < $timeout } {
            fconfigure $channel -timeout $timeout	   
        }
    }   
}
