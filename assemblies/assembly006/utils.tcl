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
        result.fileName ""
        result.format TXT
        result.rewrite 1
        switch.voltage 0
        switch.current 0
        switch.serialAddr COM1        
        switch.rs485Addr 40
		switch.delay 500
		ts.addr localhost
		ts.port 8080
		ts.maxErr 0.1
		ts.maxTrend 0.5
		mm.nplc 10
		cmm.nplc 10
		measure.numOfSamples 1
    }	

	::measure::tsclient::config -host $settings(ts.addr) -port $settings(ts.port)
}

# Устанавливает положение переключателей полярности
proc setConnectors { conns } {
    global settings

	# размыкаем цепь
    hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 4 {1000}
	#after 500

	# производим переключение полярности
    hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 0 $conns
	#after 500

	# замыкаем цепь
    hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 4 {0}
	#after 500
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

proc display { v sv c sc r sr } {
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
		measure::interop::cmd "addValueToChart $r"
	}
}

