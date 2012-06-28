#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 007
# Процедуры общего назначения
###############################################################################

package require hardware::agilent::mm34410a
package require hardware::owen::mvu8
package require measure::thermocouple
package require measure::listutils
package require measure::math

# Число измерений, по которым определяется производная dT/dt
set DERIVATIVE_READINGS 10

# Процедура проверяет правильность настроек, при необходимости вносит поправки
proc validateSettings {} {
    measure::config::validate {
        result.fileName ""
        result.format TXT
        result.rewrite 1
        result.comment ""

		measure.noSystErr 0
		measure.numOfSamples 1
    }	
}

# Инициализация приборов
proc setup {} {
    # Инициализация мультиметров на образце
    measure::measure::setupMmsForResistance
    
    # Инициализация мультиметра на термопаре
    global tcmm
    
    # Подключаемся к мультиметру (ММ)
    set tcmm [hardware::agilent::mm34410a::open \
		-baud [measure::config::get tcmm.baud] \
		-parity [measure::config::get tcmm.parity] \
		-name "MM3" \
		[measure::config::get -required tcmm.addr] \
	]

    # Иниализируем и опрашиваем ММ
    hardware::agilent::mm34410a::init $tcmm

	# Настраиваем мультиметр для измерения постоянного напряжения
	hardware::agilent::mm34410a::configureDcVoltage \
		-nplc [measure::config::get tcmm.nplc 10] \
		-text2 "MM3 TC" \
		 $tcmm
		 
	# реле в исходное
	setConnectors { 0 0 0 0 }
}

# Завершаем работу установки, матчасть в исходное.
proc finish {} {
    global mm cmm tcmm log

    if { [info exists mm] } {
    	# Переводим вольтметр в исходный режим
    	hardware::agilent::mm34410a::done $mm
    	close $mm
    	unset mm
    }

    if { [info exists cmm] } {
    	# Переводим амперметр в исходный режим
    	hardware::agilent::mm34410a::done $cmm
    	close $cmm
    	unset cmm
    }
	
    if { [info exists tcmm] } {
    	# Переводим мультиметр в исходный режим
    	hardware::agilent::mm34410a::done $tcmm
    	close $tcmm
    	unset tcmm
    }
    
	# реле в исходное
	setConnectors { 0 0 0 0 }
	
	# выдержим паузу
	after 1000
}

proc display { v sv c sc r sr temp tempErr tempDer write } {
	if { [measure::interop::isAlone] } {
	    # Выводим результаты в консоль
    	set cv [::measure::format::valueWithErr -mult 1.0e-3 $c $sc A]
    	set vv [::measure::format::valueWithErr -mult 1.0e-3 $v $sv V]
    	set rv [::measure::format::valueWithErr $r $sr "\u03A9"]
    	set pw [::measure::format::value -prec 2 [expr 1.0e-6 * $c * $v] W]
    	set tv [::measure::format::valueWithErr $temp $tempErr K]
    	puts "C=$cv\tV=$vv\tR=$rv\tP=$pw\tT=$tv"
	} else {
	    # Выводим результаты в окно программы
        measure::interop::cmd [list display $v $sv $c $sc $r $sr $temp $tempErr $tempDer $write]
	}
}

set tempValues [list]
set timeValues [list]
set startTime [clock milliseconds]

# Снимаем показания вольтметра на термопаре и возвращаем температуру 
# вместе с инструментальной погрешностью и производной
proc readTemp {} {
    global tcmm tempValues timeValues startTime DERIVATIVE_READINGS
    global log

    # измеряем напряжение на термопаре    
    set v [string trim [scpi::query $tcmm "READ?"]]
    if { [measure::config::get tc.negate 0] } {
        set v [expr -1.0 * $v]
    }
	# инструментальная погрешность
   	set vErr [hardware::agilent::mm34410a::dcvSystematicError $v "" [measure::config::get tcmm.nplc 10]]
   	
   	# вычисляем и возвращаем температуру с инструментальной погрешностью
	lassign [measure::thermocouple::calcKelvin \
        [measure::config::get tc.type K] \
        [measure::config::get tc.fixedT 77.4] \
        $v $vErr \
        [measure::config::get tc.correction] \
        ] t tErr

    # накапливаем значения в очереди для вычисления производной 
    measure::listutils::lappend tempValues $t $DERIVATIVE_READINGS
    measure::listutils::lappend timeValues [expr [clock milliseconds] - $startTime] $DERIVATIVE_READINGS
    if { [llength $tempValues] < $DERIVATIVE_READINGS } {
        set der 0.0
    } else {
        set der [expr 60000.0 * [measure::math::slope $timeValues $tempValues]] 
    }
            
    return [list $t $tErr $der]
}

# Измеряем сопротивление и регистрируем его вместе с температурой
proc readResistanceAndWrite { temp tempErr tempDer { write 0 } { manual 0 } } {
    global settings

	# Измеряем напряжение
	lassign [measure::measure::resistance] v sv c sc r sr

    # Выводим результаты в окно программы
    display $v $sv $c $sc $r $sr $temp $tempErr $tempDer $write

    if { $write } {
    	# Выводим результаты в результирующий файл
    	lassign [::measure::measure::calcRho $r $sr] rho rhoErr
    	if { $manual } {
    	   set manual true
        } else {
            set manual ""
        }
    	measure::datafile::write $settings(result.fileName) [list TIMESTAMP $temp $tempErr $tempDer $c $sc $v $sv $r $sr $rho $rhoErr $manual]
    }
    
	measure::datafile::write $settings(trace.fileName) [list \
        TIMESTAMP \
        [format %0.3f $temp] [format %0.3f $tempDer] [format %0.6g $r]  \
    ]
}

proc setConnectors { conns } {
    global settings

    if { $settings(current.method) != 3 } {
    	# размыкаем цепь
        hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 4 {1000}
    	#after 500
    
    	# производим переключение полярности
        hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 0 $conns
    	#after 500

    	# замыкаем цепь
        hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 4 {0}
    	#after 500
    } else {
    	# в данном режиме цепь всегда разомкнута
        hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 4 {1000}
    }
}
