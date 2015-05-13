#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 001
# Тестовый модуль, работающий тогда, когда не работает измерительный модуль
# Его задача - периодически снимать показания приборов 
#   и выводить в окно программы
###############################################################################

package require measure::logger
package require measure::config
package require hardware::owen::mvu8
package require hardware::scpi
package require hardware::agilent::pse3645a
package require hardware::agilent::mm34410a
package require tclvisa
package require measure::interop
package require measure::sigma

###############################################################################
# Подпрограммы
###############################################################################

# Устанавливает ток питания образца
# curr - требуемый ток в мА
proc setCurrent { curr } {
    global ps

	# Задаём выходной ток с переводом из мА в А
    scpi::cmd $ps "CURRENT [expr 0.001 * $curr]"
}

# Измеряет ток и напряжение на образце
# Возвращает напряжение, погрешность в милливольтах, ток и погрешность в миллиамперах, сопротивление и погрешность в омах
proc measureVoltage { } {
    global mm cmm measure settings
    
	# измеряем напряжение и ток
	set v [expr abs([scpi::query $mm "READ?"])]
	set c [expr abs([scpi::query $cmm "READ?"])]

	# вычисляем сопротивление
	set r [expr abs($v / $c)]

	# определяем инструментальную погрешность
	set vErr [hardware::agilent::mm34410a::dcvSystematicError $v "" $settings(nplc)]
	set cErr [hardware::agilent::mm34410a::dciSystematicError $c "" $settings(nplc)]
	set rErr [measure::sigma::div $v $vErr $c $cErr]

	# возвращаем результат измерений, переведённый в милливольты и милливольты
	return [list [expr 1000.0 * $v] [expr 1000.0 * $vErr] [expr 1000.0 * $c] [expr 1000.0 * $cErr] $r $rErr]
}

# Устанавливает положение переключателей полярности
proc setConnectors { conns } {
    global settings
    hardware::owen::mvu8::modbus::setChannels $settings(rs485Port) $settings(switchAddr) 0 $conns
}

# Инициализация источника питания
proc setupPs {} {
    global ps rm settings
    
    # Подключаемся к источнику питания (ИП)
    if { [catch { set ps [visa::open $rm $settings(psAddr)] } ] } {
		error "Невозможно подключиться к источнику питания по адресу `$settings(psAddr)'"
	}

    # Иниализируем и опрашиваем ИП
    hardware::agilent::pse3645a::init $ps
    
	# Задаём пределы по напряжению и току
    scpi::cmd $ps "APPLY 35.000,0.001"
}

# Инициализация вольтметра
proc setupMM {} {
    global mm rm settings measure
    
    # Подключаемся к мультиметру (ММ)
    if { [catch { set mm [visa::open $rm $settings(mmAddr)] } ] } {
		error "Невозможно подключиться к вольтметру по адресу `$settings(mmAddr)'"
	}

    # Иниализируем и опрашиваем ММ
    hardware::agilent::mm34410a::init -noFrontCheck $mm

	# Настраиваем мультиметр для измерения постоянного напряжения
	hardware::agilent::mm34410a::configureDcVoltage \
		-nplc $settings(nplc) \
		 $mm
}

# Инициализация амперметра
proc setupCMM {} {
    global cmm rm settings measure
    
    # Подключаемся к мультиметру (ММ)
    if { [catch { set cmm [visa::open $rm $settings(cmmAddr)] } ] } {
		error "Невозможно подключиться к амперметру по адресу `$settings(cmmAddr)'"
	}

    # Иниализируем и опрашиваем ММ
    hardware::agilent::mm34410a::init -noFrontCheck $cmm

	# Настраиваем мультиметр для измерения постоянного тока
	hardware::agilent::mm34410a::configureDcCurrent \
		-nplc $settings(nplc) \
		 $cmm
}

# Инициализируем устройства
proc openDevices {} {
    global rm ps mm cmm settings

	# реле в исходное
	setConnectors { 0 0 0 0 }

	# Подключаемся к менеджеру ресурсов VISA
	set rm [visa::open-default-rm]

	# Производим подключение к устройствам и их настройку
	setupMM
	setupCMM
	if { !$settings(manualPower) } {
		setupPs

		# Устанавливаем выходной ток
		setCurrent $measure(startCurrent)

		# Включаем подачу тока на выходы ИП
		hardware::agilent::pse3645a::setOutput $ps 1
	}
}

# Завершаем работу установки, матчасть в исходное.
proc finish {} {
    global rm ps mm cmm

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
}

# Процедура проверяет правильность настроек, при необходимости вносит поправки
proc validateSettings {} {
    global settings measure

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
}

# Процедура производит периодический опрос приборов и выводит показания на экран
proc run {} {
	# инициализируем устройства
	openDevices

	# работаем в цикле пока не получен сигнал останова
	while { ![measure::interop::isTerminated] }	{
		set tm [clock milliseconds]

		# Снимаем показания
		lassign [measureVoltage] v sv c sc r sr

		set cf [format "%0.9g \u00b1 %0.2g" $c $sc]
		set vf [format "%0.9g \u00b1 %0.2g" $v $sv]
		set rf [format "%0.9g \u00b1 %0.2g" $r $sr]
		set pf [format "%0.3g" [expr 0.001 * abs($c * $v)]]

		if { [measure::interop::isAlone] } {
		    # Выводим результаты в консоль
			puts "Current=$cf\tVoltage=$vf\tResistance=$rf\tPower=$pf"
		} else {
		    # Выводим результаты в окно программы
			measure::interop::setVar runtime(current) $cf
			measure::interop::setVar runtime(voltage) $vf
			measure::interop::setVar runtime(resistance) $rf
			measure::interop::setVar runtime(power) $pf
		}

		# Выдерживаем паузу
		measure::interop::sleep [expr int(500 - ([clock milliseconds] - $tm))]
	}
}

###############################################################################
# Начало работы
###############################################################################

# Инициализируем протоколирование
set log [measure::logger::init measure]

# Читаем настройки программы
measure::config::read

# Проверяем правильность настроек
validateSettings

###############################################################################
# Основной цикл измерений
###############################################################################

# Эта команда будет вызваться в случае преждевременной остановки потока
measure::interop::registerFinalization { finish }

# Запускаем процедуру измерения
run

# Завершаем работу
finish

after 1000
