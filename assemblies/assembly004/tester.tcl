#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 004
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

# Измеряет ток и напряжение на образце
# Возвращает напряжение, погрешность в милливольтах, ток и погрешность в миллиамперах, сопротивление и погрешность в омах
proc measureVoltage { } {
    global mm cmm settings
    
	# измеряем напряжение и ток
	set v [expr abs([scpi::query $mm "READ?"])]
	set c [expr abs([scpi::query $cmm "READ?"])]

	if { $settings(useTestResistance) } {
		# пересчитаем падение напряжения на эталонном сопротивлении
		# в силу тока
		set c [expr $c / $settings(testResistance)]
	}

	# вычисляем сопротивление
	set r [expr abs($v / $c)]

	# определяем инструментальную погрешность
	set vErr [hardware::agilent::mm34410a::dcvSystematicError $v "" $settings(nplc)]
	if { $settings(useTestResistance) } {
		set cErr [hardware::agilent::mm34410a::dcvSystematicError [expr $c * $settings(testResistance)] "" $settings(nplc)]
	} else {
		set cErr [hardware::agilent::mm34410a::dciSystematicError $c "" $settings(nplc)]
	}
	set rErr [measure::sigma::div $v $vErr $c $cErr]

	# возвращаем результат измерений, переведённый в милливольты и милливольты
	return [list [expr 1000.0 * $v] [expr 1000.0 * $vErr] [expr 1000.0 * $c] [expr 1000.0 * $cErr] $r $rErr]
}

# Инициализация вольтметра
proc setupMM {} {
    global mm rm settings
    
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
    global cmm rm settings
    
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
		setCurrent $settings(startCurrent)

		# Включаем подачу тока на выходы ИП
		hardware::agilent::pse3645a::setOutput $ps 1
	}
}

# Процедура производит периодический опрос приборов и выводит показания на экран
proc run {} {
	# инициализируем устройства
	openDevices

	# подключаем тестовое сопротивление если требуется
	connectTestResistance

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

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]

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
