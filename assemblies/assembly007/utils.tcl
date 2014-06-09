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
package require hardware::agilent::pse3645a
package require hardware::owen::trm201

# Число измерений, по которым определяется производная dT/dt
set DERIVATIVE_READINGS 10

# Число точек, по которым экстраполируется измеряемая величина
set EXTRAPOL 2

# Процедура проверяет правильность настроек, при необходимости вносит поправки
proc validateSettings {} {
    measure::config::validate {
        result.fileName ""
        result.format TXT
        result.rewrite 1
        result.comment ""

		measure.noSystErr 0
		measure.numOfSamples 1

		current.method 0
		
		switch.voltage 0
		switch.current 0
		switch.step 1
		switch.delay 0
    }	
}

# Инициализация приборов
proc setup {} {
    global ps tcmm log trm connectors connectorIndex connectorStep vSwitches cSwitches tValues vValues cValues rValues

    # Инициализация мультиметров на образце
    measure::measure::setupMmsForResistance

    if { 3 != [measure::config::get current.method] && [measure::config::get ps.addr] != "" } {
        # цепь запитывается при помощи управляемого ИП
        set ps [hardware::agilent::pse3645a::open \
    		-baud [measure::config::get ps.baud] \
    		-parity [measure::config::get ps.parity] \
    		-name "Power Supply" \
    		[measure::config::get -required ps.addr] \
    	]
    
        # Иниализируем и опрашиваем ИП
        hardware::agilent::pse3645a::init $ps
    
    	# Работаем в области бОльших напряжений
        scpi::cmd $ps "VOLTAGE:RANGE HIGH"
        
    	# Задаём пределы по напряжению и току
        scpi::cmd $ps "APPLY 60.000,[expr 0.001 * [measure::config::get current.manual.current]]"
        
        # включаем подачу напряжения на выходы ИП
        hardware::agilent::pse3645a::setOutput $ps 1
    }
    
    if { 0 == [measure::config::get tc.method 0]} {
        # Инициализация мультиметра на термопаре
        # Подключаемся к мультиметру (ММ)
        set tcmm [hardware::agilent::mm34410a::open \
    		-baud [measure::config::get tcmm.baud] \
    		-parity [measure::config::get tcmm.parity] \
    		-name "MM3" \
    		[measure::config::get -required tcmm.addr] \
    	]
    
        # Иниализируем и опрашиваем ММ
        hardware::agilent::mm34410a::init $tcmm
    
    	# Настраиваем мультиметр для измерения постоянного напряжения на термопаре
    	hardware::agilent::mm34410a::configureDcVoltage \
    		-nplc [measure::config::get tcmm.nplc 10] \
    		-text2 "MM3 TC" \
    		 $tcmm
    } else {
        set trm [::hardware::owen::trm201::init [measure::config::get tcm.serialAddr] [measure::config::get tcm.rs485Addr]]
    
        # Настраиваем ТРМ-201 для измерения температуры
        ::hardware::owen::trm201::setTcType $trm [measure::config::get tc.type] 
    }

    set connectors [list { 0 0 0 0 }]
    set vSwitches { 0 }
    set cSwitches { 0 }
    if { 0 != [measure::config::get switch.voltage 0]} {
        # переполюсовка по напряжению
    	# Инверсное подключение вольтметра
    	lappend connectors {1000 1000 0 0}
        lappend vSwitches { 1 } 
        lappend cSwitches { 0 } 
    }
    if { 0 != [measure::config::get switch.current 0]} {
        # переполюсовка по току
    	# Инверсное подключение источника тока
    	lappend connectors { 0 0 1000 1000 }
        lappend vSwitches { 0 } 
        lappend cSwitches { 1 } 
        if { 0 != [measure::config::get switch.voltage 0]} {
    		# Инверсное подключение вольтметра и источника тока
    		lappend connectors { 1000 1000 1000 1000 } 
            lappend vSwitches { 1 } 
            lappend cSwitches { 1 } 
        }
    }
    set connectorIndex 0
    set connectorStep 0
    set tValues {}
    set vValues {}
    set cValues {}
    set rValues {}
}

# Завершаем работу установки, матчасть в исходное.
proc finish {} {
    global mm cmm tcmm ps log trm

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
	
    if { [info exists ps] } {
    	# Переводим ИП в исходный режим
    	hardware::agilent::pse3645a::done $ps
    	close $ps
    	unset ps
    }
    
    if { [info exists tcmm] } {
    	# Переводим мультиметр в исходный режим
    	hardware::agilent::mm34410a::done $tcmm
    	close $tcmm
    	unset tcmm
    }
    
    if { [info exists trm] } {
        # Переводим ТРМ-201 в исходное состояние
        ::hardware::owen::trm201::done $trm
        unset trm
    }
    
	# реле в исходное
	resetConnectors
	
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

# Измеряем температуру и возвращаем вместе с инструментальной погрешностью и производной
proc readTemp {} {
    global tempValues timeValues startTime DERIVATIVE_READINGS
    
    if { 0 == [measure::config::get tc.method 0]} {
        lassign [readTempMm] t tErr
    } else {
        lassign [readTempTrm] t tErr
    }

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

# Снимаем показания вольтметра на термопаре и возвращаем температуру 
# вместе с инструментальной погрешностью
proc readTempTrm {} {
    global trm
    return [::hardware::owen::trm201::readTemperature $trm]
}

# Снимаем показания вольтметра на термопаре и возвращаем температуру 
# вместе с инструментальной погрешностью
proc readTempMm {} {
    global tcmm
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

    return [list $t $tErr]
}

# Измеряем сопротивление и регистрируем его вместе с температурой
proc readResistanceAndWrite { temp tempErr tempDer { write 0 } { manual 0 } { dotrace 1 } } {
    global log
    global settings connectors connectorIndex connectorStep vSwitches cSwitches tValues vValues cValues rValues EXTRAPOL

	# Измеряем напряжение
	lassign [measure::measure::resistance] v sv c sc r sr

    # Выводим результаты в окно программы
    display $v $sv $c $sc $r $sr $temp $tempErr $tempDer $write

    if { $write } {
    	# Выводим результаты в результирующий файл
    	writeDataPoint $settings(result.fileName) $temp $tempErr $tempDer \
            $v $sv $c $sc $r $sr    \
            $manual [lindex $vSwitches $connectorIndex] [lindex $cSwitches $connectorIndex]   
    }
    
    if { $dotrace } {
    	measure::datafile::write $settings(trace.fileName) [list \
            TIMESTAMP \
            [format %0.3f $temp] [format %0.3f $tempDer] [format %0.6g $r]  \
        ]
    }
    
    if { [llength $connectors] > 1 && $write } {
        # отслеживаем переполюсовки
        if { $connectorStep == 0 } {
            # записываем точку в файл с очищенными результатами
        	lassign [refineDataPoint $tValues $vValues $temp $v $sv] refinedV refinedSV 
        	lassign [refineDataPoint $tValues $cValues $temp $c $sc] refinedC refinedSC 
        	lassign [refineDataPoint $tValues $rValues $temp $r $sr] refinedR refinedSR
             
        	writeDataPoint [refinedFileName $settings(result.fileName)] $temp $tempErr $tempDer \
                $refinedV $refinedSV $refinedC $refinedSC $refinedR $refinedSR   

            set tValues {}; set vValues {}; set cValues {}; set rValues {}
        }
        
        incr connectorStep
        if { [measure::config::get switch.step 1] <= $connectorStep } {
            set connectorStep 0
            incr connectorIndex
            if { $connectorIndex >= [llength $connectors] } {
                set connectorIndex 0 
            }
            setConnectors [lindex $connectors $connectorIndex]
            after [measure::config::get switch.delay 0]
        }
    }
    
    if { $write } {
        ::measure::listutils::lappend tValues $temp $EXTRAPOL
        ::measure::listutils::lappend vValues $v $EXTRAPOL
        ::measure::listutils::lappend cValues $c $EXTRAPOL
        ::measure::listutils::lappend rValues $r $EXTRAPOL
    }
}

proc resetConnectors { } {
    global settings

    hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 0 {0 0 0 0 0 0 0 0}
}

# Устанавливает положение переключателей полярности
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

# конструирует имя файла для очищенных данных
proc refinedFileName { fn } {
    return "[file rootname $fn].refined[file extension $fn]"
}

# вычислим "очищенное" значение по нескольким предыдущим и текущему значению, полученному после переполюсовки
proc refineDataPoint { tValues values t v err } {
    global log
    set len [llength $values]

    if { $len > 0 } {
        # в простейшем случае просто среднее арифметическое двух значений
        set prev [lindex $values end]
        
        if { $len > 1} {
            # по двум предыдущим точкам определяем, какое могло бы быть значение при текущей температуре и прежней переполюсовке
            set slope [::measure::math::slope $tValues $values]
            set prev [expr $prev + $slope * ($t - [lindex $tValues end])]
        }
        
        set err [::measure::sigma::add $err [expr abs(0.5 * ($prev - $v))] ] 
        set v [expr 0.5 * ($prev + $v)]
    }
    
    # simply return given values by default
    return [list $v $err]
}

# записывает точку в файл данных с попутным вычислением удельного сопротивления
proc writeDataPoint { fn temp tempErr tempDer v sv c sc r sr { manual 0 } { vPolarity "" } { cPolarity "" } } {
	lassign [::measure::measure::calcRho $r $sr] rho rhoErr
    if { $rho != "" } {
        set rho [format %0.6g $rho]
        set rhoErr [format %0.2g $rhoErr]
    }
	
	if { $manual } {
	   set manual true
    } else {
        set manual ""
    }
    
	measure::datafile::write $fn [list \
        TIMESTAMP [format %0.3f $temp] [format %0.3f $tempErr] [format %0.3f $tempDer]  \
        [format %0.6g $c] [format %0.2g $sc]    \
        [format %0.6g $v] [format %0.2g $sv]    \
        [format %0.6g $r] [format %0.2g $sr]    \
        $rho $rhoErr  \
        $manual $vPolarity $cPolarity ]
}