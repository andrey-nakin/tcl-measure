#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 004
# Процедуры общего назначения
###############################################################################

# Процедура проверяет правильность настроек, при необходимости вносит поправки
proc validateSettings {} {
    global settings

	# Число измерений на одну точку результата
	if { ![info exists settings(measure.numOfSamples)] || $settings(measure.numOfSamples) < 1 } {
		# Если не указано в настройках, по умолчанию равно 1
		set settings(measure.numOfSamples) 1
	}

    measure::config::validate {
        current.method 0
		current.reference.resistance 1.0
		current.reference.error 0.0
		current.manual.current 1.0
		current.manual.error 0.0

        result.fileName ""
        result.format TXT
        result.rewrite 1
        result.comment ""

        switch.voltage 0
        switch.current 0
        switch.serialAddr COM1        
        switch.rs485Addr 40
		switch.delay 500

		ts.addr localhost
		ts.port 8080
		ts.maxErr 0.1
		ts.maxTrend 0.5
		ts.timeout 0

		measure.noSystErr 0
		measure.numOfSamples 1

		mm.nplc 10
		cmm.nplc 10
		beepOnExit 0
    }	

	::measure::tsclient::config -host $settings(ts.addr) -port $settings(ts.port)
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

# Завершаем работу установки, матчасть в исходное.
proc finish {} {
    global mm cmm log

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
	
	# реле в исходное
	setConnectors { 0 0 0 0 }
	
	# выдержим паузу
	after 1000
}

proc display { v sv c sc r sr { T "" } { series "result" } } {
    set cf [format "%0.9g \u00b1 %0.2g" $c $sc]
    set vf [format "%0.9g \u00b1 %0.2g" $v $sv]
    set rf [format "%0.9g \u00b1 %0.2g" $r $sr]
    set pf [format "%0.3g" [expr 0.001 * $c * $v]]    

	if { [measure::interop::isAlone] } {
	    # Выводим результаты в консоль
		puts "Current=$cf\tVoltage=$vf\tResistance=$rf\tPower=$pf"
	} else {
	    # Выводим результаты в окно программы
		measure::interop::setVar runtime(current) $cf
		measure::interop::setVar runtime(voltage) $vf
		measure::interop::setVar runtime(resistance) $rf
		measure::interop::setVar runtime(power) $pf
		if { $T != "" } {
			measure::interop::cmd [list addPointToChart $T $r $series]
		}
	}
}

# Процедура производит тестовое измерение сопротивления,
# и выводит результаты в окне
proc testMeasureAndDisplay { { traceFileName "" } { traceFileFormat "" } } {
	# Снимаем показания
	lassign [measure::measure::resistance -n 1] v sv c sc r sr

	# Считываем значение температуры выводим её на экран
	if { [ catch {
        set t [measure::tsclient::state]  
        array set tstate $t
        measure::interop::cmd [list setTemperature $t]

        # Трассируем значения температуры и сопротивления         
    	measure::datafile::write $traceFileName [list TIMESTAMP [format %0.3f $tstate(temperature)] [format %0.6g $r]]
         
        # Выводим результаты в окно программы
        display $v $sv $c $sc $r $sr $tstate(temperature) test          
    } err ] } {
        global log
        ${log}::error "testMeasureAndDisplay $err"
        # Выводим результаты в окно программы
        display $v $sv $c $sc $r $sr          
    }
}

