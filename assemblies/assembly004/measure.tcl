#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 004
# Измерительный модуль
###############################################################################

package require measure::logger
package require measure::config
package require hardware::owen::mvu8
package require hardware::scpi
package require hardware::agilent::pse3645a
package require hardware::agilent::mm34410a
package require tclvisa
package require measure::datafile
package require measure::interop
package require measure::sigma
package require math::statistics

###############################################################################
# Подпрограммы
###############################################################################

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]

# Измеряет ток и напряжение на образце
# Возвращает напряжение, погрешность в милливольтах, ток и погрешность в миллиамперах, сопротивление и погрешность в омах
proc measureVoltage { } {
    global mm cmm settings
    
	# запускаем измерение напряжения
	scpi::cmd $mm "INIT"

	# запускаем измерение тока
	scpi::cmd $cmm "INIT"

	# выставим нужный таймаут
	set timeout [fconfigure $mm -timeout]
	fconfigure $mm -timeout [expr int(10000 * $settings(numberOfSamples))]
	fconfigure $cmm -timeout [expr int(10000 * $settings(numberOfSamples))]

	# ждём завершения измерения напряжения
	scpi::query $mm "*OPC?"

	# ждём завершения измерения тока
	scpi::query $cmm "*OPC?"

    # восстановим таймаут
	fconfigure $mm -timeout $timeout
	fconfigure $cmm -timeout $timeout

	# считываем значения напряжения и тока
	set n $settings(numberOfSamples)
	set vs [split [scpi::query $mm "DATA:REMOVE? $n"] ","]
	set cs [split [scpi::query $cmm "DATA:REMOVE? $n"] ","]
	
	if { $settings(useTestResistance) } {
		# пересчитаем падение напряжения на эталонном сопротивлении
		# в силу тока
		set newcs [list]
		foreach c $cs {
			lappend newcs [expr $c / $settings(testResistance)]
		}
		set cs $newcs
	}

	# вычисляем сопротивление
	set rs [list]
	foreach v $vs c $cs {
		lappend rs [expr $v / $c]
	}

	# вычисляем средние значения и сигмы
	set v [expr abs([math::statistics::mean $vs])]; set sv [math::statistics::stdev $vs]; if { $sv == ""} { set sv 0 }
	set c [expr abs([math::statistics::mean $cs])]; set sc [math::statistics::stdev $cs]; if { $sc == ""} { set sc 0 }
	set r [expr abs([math::statistics::mean $rs])]; set sr [math::statistics::stdev $rs]; if { $sr == ""} { set sr 0 }

    if { ![info exists settings(noSystErr)] || !$settings(noSystErr) } {
    	# определяем инструментальную погрешность
    	set vErr [hardware::agilent::mm34410a::dcvSystematicError $v "" $settings(nplc)]
		if { $settings(useTestResistance) } {
	    	set cErr [hardware::agilent::mm34410a::dcvSystematicError [expr $c * $settings(testResistance)] "" $settings(nplc)]
		} else {
	    	set cErr [hardware::agilent::mm34410a::dciSystematicError $c "" $settings(nplc)]
		}
    	set rErr [measure::sigma::div $v $vErr $c $cErr]
    
    	# суммируем инструментальную и измерительную погрешности
    	set sv [measure::sigma::add $vErr $sv]
    	set sc [measure::sigma::add $cErr $sc]
    	set sr [measure::sigma::add $rErr $sr]
    }

	# возвращаем результат измерений, переведённый в милливольты и милливольты
	return [list [expr 1000.0 * $v] [expr 1000.0 * $sv] [expr 1000.0 * $c] [expr 1000.0 * $sc] $r $sr]
}

# Инициализация вольтметра
proc setupMM {} {
    global mm rm settings
    
    # Подключаемся к мультиметру (ММ)
    if { [catch { set mm [visa::open $rm $settings(mmAddr)] } ] } {
		error "Невозможно подключиться к вольтметру по адресу `$settings(mmAddr)'"
	}

    # Иниализируем и опрашиваем ММ
    hardware::agilent::mm34410a::init $mm

	# Настраиваем мультиметр для измерения постоянного напряжения
	hardware::agilent::mm34410a::configureDcVoltage \
		-nplc $settings(nplc) \
		-autoZero ONCE	\
		-sampleCount $settings(numberOfSamples)	\
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
    hardware::agilent::mm34410a::init $cmm

	# Настраиваем мультиметр для измерения постоянного тока
	hardware::agilent::mm34410a::configureDcCurrent \
		-nplc $settings(nplc) \
		-autoZero ONCE	\
		-sampleCount $settings(numberOfSamples)	\
		 $cmm
}

# Процедура производит одно измерение со всеми нужными переполюсовками
#   и сохраняет результаты в файле результатов
proc makeMeasurement {} {
	global mm cmm connectors

	set vs [list]; set svs [list]
	set cs [list]; set scs [list]
	set rs [list]; set srs [list]

	# Пробегаем по переполюсовкам
	set nc [llength $connectors]
	foreach conn $connectors {
		# Устанавливаем нужную полярность
		if { $nc > 1 } {
			setConnectors $conn
		}

		# Ждём окончания переходных процессов, 
		after 1000

		# Измеряем напряжение
		set res [measureVoltage]

		# Накапливаем суммы
		lassign $res v sv c sc r sr
		lappend vs $v; lappend svs $sv
		lappend cs $c; lappend scs $sc
		lappend rs $r; lappend srs $sr
          
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
		}
	}

	# Вычисляем средние значения
	set c [math::statistics::mean $cs]; set sc [math::statistics::mean $scs]
	set v [math::statistics::mean $vs]; set sv [math::statistics::mean $svs]
	set r [math::statistics::mean $rs]; set sr [math::statistics::mean $srs]

    # Выводим результаты в результирующий файл
	measure::datafile::write $settings(fileName) $settings(fileFormat) [list $c $sc $v $sv $r $sr]
}

###############################################################################
# Начало работы
###############################################################################

# Инициализируем протоколирование
set log [measure::logger::init measure]

# Эта команда будет вызвааться в случае преждевременной остановки потока
measure::interop::registerFinalization { finish }

# Читаем настройки программы
measure::config::read

# Проверяем правильность настроек
validateSettings

# Создаём файл с результатами измерений
measure::datafile::create $settings(fileName) $settings(fileFormat) $settings(fileRewrite) [list "I (mA)" "+/- (mA)" "U (mV)" "+/- (mV)" "R (Ohm)" "+/- (Ohm)"]

# Подключаемся к менеджеру ресурсов VISA
set rm [visa::open-default-rm]

# Производим подключение к устройствам и их настройку
if { !$settings(manualPower) } {
	setupPs
}
setupMM
setupCMM

# подключаем тестовое сопротивление если требуется
connectTestResistance

# Задаём наборы переполюсовок
# Основное положение переключателей
set connectors [list { 0 0 0 0 }]
if { $settings(switchVoltage) } {
	# Инверсное подключение вольтметра
	lappend connectors {1000 1000 0 0} 
}
if { $settings(switchCurrent) } {
	# Инверсное подключение источника тока
	lappend connectors { 0 0 1000 1000 }
	if { $settings(switchVoltage) } {
		# Инверсное подключение вольтметра и источника тока
		lappend connectors { 1000 1000 1000 1000 } 
	}
}

###############################################################################
# Основной цикл измерений
###############################################################################

if { !$settings(manualPower) } {
	# Устанавливаем выходной ток
	setCurrent $settings(startCurrent)

	# Включаем подачу тока на выходы ИП
	hardware::agilent::pse3645a::setOutput $ps 1
}

# Холостое измерение для "прогрева" мультиметров
measureVoltage

if { $settings(manualPower) } {
	# Ручной режим управления питанием
	# Просто делаем одно измерение и сохраняем результат в файл
	makeMeasurement
} else {
	# Режим автоматического управления питанием
	# Пробегаем по всем токам из заданного диапазона
	for { set curr $settings(startCurrent) } { $curr <= $settings(endCurrent) + 0.1 * $settings(currentStep) } { set curr [expr $curr + $settings(currentStep)] } {
		# проверим, не нажата ли кнопка остановки
		measure::interop::checkTerminated
		
		# выставляем ток на ИП
		setCurrent $curr

		# Делаем очередное измерение из сохраняем результат в файл
		makeMeasurement
	}
}

###############################################################################
# Завершение измерений
###############################################################################

if { [info exists settings(beepOnExit)] && $settings(beepOnExit) } {
    # подаём звуковой сигнал об окончании измерений
	scpi::cmd $mm "SYST:BEEP"
	after 500
}

finish

