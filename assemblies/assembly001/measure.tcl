#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 001
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
    
	# запускаем измерение напряжения
	scpi::cmd $mm "INIT"

	# запускаем измерение тока
	scpi::cmd $cmm "INIT"

	# выставим нужный таймаут
	set timeout [fconfigure $mm -timeout]
	fconfigure $mm -timeout [expr int(10000 * $measure(numberOfSamples))]
	fconfigure $cmm -timeout [expr int(10000 * $measure(numberOfSamples))]

	# ждём завершения измерения напряжения
	scpi::query $mm "*OPC?"

	# ждём завершения измерения тока
	scpi::query $cmm "*OPC?"

    # восстановим таймаут
	fconfigure $mm -timeout $timeout
	fconfigure $cmm -timeout $timeout

	# считываем значения напряжения и тока
	set n $measure(numberOfSamples)
	set vs [split [scpi::query $mm "DATA:REMOVE? $n"] ","]
	set cs [split [scpi::query $cmm "DATA:REMOVE? $n"] ","]

	# вычисляем сопротивление
	set rs [list]
	foreach v $vs c $cs {
		lappend rs [expr $v / $c]
	}

	# вычисляем средние значения и сигмы
	set v [expr abs([math::statistics::mean $vs])]; set sv [math::statistics::stdev $vs]
	set c [expr abs([math::statistics::mean $cs])]; set sc [math::statistics::stdev $cs]
	set r [expr abs([math::statistics::mean $rs])]; set sr [math::statistics::stdev $rs]

    if { ![info exists settings(noSystErr)] || !$settings(noSystErr) } {
    	# определяем инструментальную погрешность
    	set vErr [hardware::agilent::mm34410a::dcvSystematicError $v]
    	set cErr [hardware::agilent::mm34410a::dciSystematicError $c]
    	set rErr [measure::sigma::div $v $vErr $c $cErr]
    
    	# суммируем инструментальную и измерительную погрешности
    	set sv [measure::sigma::add $vErr $sv]
    	set sc [measure::sigma::add $cErr $sc]
    	set sr [measure::sigma::add $rErr $sr]
    }

	# возвращаем результат измерений, переведённый в милливольты и милливольты
	return [list [expr 1000.0 * $v] [expr 1000.0 * $sv] [expr 1000.0 * $c] [expr 1000.0 * $sc] $r $sr]
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
    hardware::agilent::mm34410a::init $mm

    # Включить автоподстройку нуля, если не используется переполюсовка
    if { $measure(switchVoltage) || $measure(switchCurrent) } {
        set autoZero "OFF"
    } else {
        set autoZero "ONCE"
    }
    
	# Настраиваем мультиметр для измерения постоянного напряжения
	hardware::agilent::mm34410a::configureDcVoltage \
		-nplc $settings(nplc) \
		-autoZero $autoZero	\
		-sampleCount $measure(numberOfSamples)	\
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
    hardware::agilent::mm34410a::init $cmm

    # Включить автоподстройку нуля, если не используется переполюсовка
    if { $measure(switchVoltage) || $measure(switchCurrent) } {
        set autoZero "OFF"
    } else {
        set autoZero "ONCE"
    }
    
	# Настраиваем мультиметр для измерения постоянного тока
	hardware::agilent::mm34410a::configureDcCurrent \
		-nplc $settings(nplc) \
		-autoZero $autoZero	\
		-sampleCount $measure(numberOfSamples)	\
		 $cmm
}

# Завершаем работу установки, матчасть в исходное.
proc finish {} {
    global ps mm cmm

	# Переводим ИП в исходный режим
	hardware::agilent::pse3645a::done $ps

	# Переводим вольтметр в исходный режим
	hardware::agilent::mm34410a::done $mm

	# Переводим амперметр в исходный режим
	hardware::agilent::mm34410a::done $cmm
	
	# реле в исходное
	setConnectors { 0 0 0 0 }
}

# Процедура проверяет правильность настроек, при необходимости вносит поправки
proc validateSettings {} {
    global settings measure

	# Число измерений на одну точку результата
	if { ![info exists measure(numberOfSamples)] || $measure(numberOfSamples) < 1 } {
		# Если не указано в настройках, по умолчанию равно 1
		set measure(numberOfSamples) 1
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
}

# Процедура производит одно измерение со всеми нужными переполюсовками
#   и сохраняет результаты в файле результатов
proc makeMeasurement {} {
	global mm cmm connectors measure

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
          
        # Выводим результаты в окно программы
    	measure::interop::setVar runtime(current) [format "%0.9g \u00b1 %0.2g" $c $sc]
    	measure::interop::setVar runtime(voltage) [format "%0.9g \u00b1 %0.2g" $v $sv]
    	measure::interop::setVar runtime(resistance) [format "%0.9g \u00b1 %0.2g" $r $sr]
    	measure::interop::setVar runtime(power) [format "%0.3g" [expr 0.001 * $c * $v]]
	}

	# Вычисляем средние значения
	set c [math::statistics::mean $cs]; set sc [math::statistics::mean $scs]
	set v [math::statistics::mean $vs]; set sv [math::statistics::mean $svs]
	set r [math::statistics::mean $rs]; set sr [math::statistics::mean $srs]

    # Выводим результаты в результирующий файл
	measure::datafile::write $measure(fileName) $measure(fileFormat) [list $c $sc $v $sv $r $sr]
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
measure::datafile::create $measure(fileName) $measure(fileFormat) $measure(fileRewrite) [list "I (mA)" "+/- (mA)" "U (mV)" "+/- (mV)" "R (Ohm)" "+/- (Ohm)"]

# Подключаемся к менеджеру ресурсов VISA
set rm [visa::open-default-rm]

# Производим подключение к устройствам и их настройку
if { !$settings(manualPower) } {
	setupPs
}
setupMM
setupCMM

# Задаём наборы переполюсовок
# Основное положение переключателей
set connectors [list { 0 0 0 0 }]
if { $measure(switchVoltage) } {
	# Инверсное подключение вольтметра
	lappend connectors {1000 1000 0 0} 
}
if { $measure(switchCurrent) } {
	# Инверсное подключение источника тока
	lappend connectors { 0 0 1000 1000 }
	if { $measure(switchVoltage) } {
		# Инверсное подключение вольтметра и источника тока
		lappend connectors { 1000 1000 1000 1000 } 
	}
}

###############################################################################
# Основной цикл измерений
###############################################################################

if { !$settings(manualPower) } {
	# Устанавливаем выходной ток
	setCurrent $measure(startCurrent)

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
	for { set curr $measure(startCurrent) } { $curr <= $measure(endCurrent) + 0.1 * $measure(currentStep) } { set curr [expr $curr + $measure(currentStep)] } {
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

finish

if { [info exists settings(beepOnExit)] && $settings(beepOnExit) } {
    # подаём звуковой сигнал об окончании измерений
    fconfigure $mm -timeout 0
    gets $mm
    puts $mm "*CLS"
}
