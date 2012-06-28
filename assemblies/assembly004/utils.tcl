#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 004
# Процедуры общего назначения
###############################################################################

package require measure::format

set CURRENT_THRESHOLD 0.050

# Устанавливает ток питания образца
# curr - требуемый ток в мА
proc setCurrent { curr } {
    global ps log
    global CURRENT_THRESHOLD

    # переведём из мА в А
    set curr [expr 0.001 * $curr]
    
    if { $curr > $CURRENT_THRESHOLD } {
    	# Задаём непосредственно выходной ток с переводом из мА в А
        scpi::cmd $ps "CURRENT $curr]"
    } else {
        # Задаём падение напряжения на сопротивлении

        # измерим сопротивление
        set mmethod [measure::config::get current.method 0]
        if { $mmethod == 0 || $mmethod == 1 } {
		  lassign [measure::measure::resistance -n 1] _ _ _ _ r
        } else {
            # зададим тестовый ток для снятия сопротивления
            scpi::cmd $ps "APPLY 60,0.001"
            after 2000 
            
            set res [scpi::query $ps "MEASURE:VOLTAGE?;CURR?"]
            if { [scan $res "%f;%f" v c] != 2 } {
                error "Unexpected response `$res` from device `[scpi::channelName $ps]`"
            }
            set r [expr $v / $c]
        }
        
        # задаем нужное напряжение и макс. ток
        scpi::cmd $ps "APPLY [expr $curr * $r],$CURRENT_THRESHOLD"
    }
}

# Процедура проверяет правильность настроек, при необходимости вносит поправки
proc validateSettings {} {
    global settings

	# Число измерений на одну точку результата
	if { ![info exists settings(numberOfSamples)] || $settings(numberOfSamples) < 1 } {
		# Если не указано в настройках, по умолчанию равно 1
		set settings(numberOfSamples) 1
	}

	# Число циклов питание на одно измерение
	if { ![info exists settings(nplc)] || $settings(nplc) < 0 } {
		# Если не указано в настройках, по умолчанию равно 10
		set settings(nplc) 10
	}

	# Ручное управление питанием
	if { ![info exists settings(manualPower)] } {
		# Если не указано в настройках, по умолчанию равно 0
		set settings(manualPower) 0
	}

	if { ![info exists settings(useTestResistance)] } {
		set settings(useTestResistance) 0
	}

	# Проверим правильность ввода номинала эталонного сопротивления
	if { $settings(useTestResistance) } {
		if { ![info exists settings(testResistance)] || !$settings(testResistance) } {
			set settings(testResistance) 1.0
		}
	}
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

# Инициализация источника питания
proc setupPs {} {
    global ps rm settings
    
    # Подключаемся к источнику питания (ИП)
    if { [catch { set ps [visa::open $rm $settings(ps.addr)] } ] } {
		error "Невозможно подключиться к источнику питания по адресу `$settings(ps.addr)'"
	}

    # Иниализируем и опрашиваем ИП
    hardware::agilent::pse3645a::init $ps
    
    fconfigure $ps -timeout 10000
    
	# Работаем в области бОльших напряжений
    scpi::cmd $ps "VOLTAGE:RANGE HIGH"
    
	# Задаём пределы по напряжению и току
    scpi::cmd $ps "APPLY 60.000,0.001"
}

# Завершаем работу установки, матчасть в исходное.
proc finish {} {
    global rm ps mm cmm log

    if { [info exists ps] } {
    	# Переводим ИП в исходный режим
    	hardware::agilent::pse3645a::done $ps
    	close $ps
    	unset ps
    }

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
	
	if { [info exists rm] } {
    	close $rm
    	unset rm
    }
    
	# реле в исходное
	setConnectors { 0 0 0 0 }
	
	# выдержим паузу
	after 1000
}

proc display { v sv c sc r sr } {
	set cf [::measure::format::valueWithErr -mult 1.0e-3 $c $sc "\u0410"]
	set vf [::measure::format::valueWithErr -mult 1.0e-3 $v $sv "\u0412"]
	set rf [::measure::format::valueWithErr $r $sr "\u03A9"]
	set pf [::measure::format::value -prec 2 [expr 1.0e-6 * $c * $v] "\u0412\u0442"]
      
	if { [measure::interop::isAlone] } {
	    # Выводим результаты в консоль
		puts "Current=$cf\tVoltage=$vf\tResistance=$rf\tPower=$pf"
	} else {
	    # Выводим результаты в окно программы
		measure::interop::setVar runtime(current) $cf
		measure::interop::setVar runtime(voltage) $vf
		measure::interop::setVar runtime(resistance) $rf
		measure::interop::setVar runtime(power) $pf
		measure::interop::cmd [list addValueToChart $r]
	}
}
