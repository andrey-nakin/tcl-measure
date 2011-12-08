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
# Возвращает напряжение, погрешность в милливольтах, ток и погрешность в миллиамперах
proc measureVoltage { } {
    global mm cmm measure
    
	if { $measure(numberOfSamples) > 1 } {
		# режим многократного измерения с подсчётом статистики

		# запускаем измерения напряжения
		scpi::cmd $mm "INIT"

		# запускаем измерения тока
		scpi::cmd $cmm "INIT"
		
		# цикл ожидания конца измерений
		for { set i 0 } { $i < $measure(numberOfSamples) } { incr i } {
		    # проверим, не нажата ли кнопка остановки
		    measure::interop::checkTerminated
		    
			# немного подождём
			after 1000
		
			# считываесм число накопленных в статистике измерений
			set n1 [scpi::query $mm "CALCULATE:AVERAGE:COUNT?"]
			set n2 [scpi::query $cmm "CALCULATE:AVERAGE:COUNT?"]
			if { $n1 >= $measure(numberOfSamples) && $n2 >= $measure(numberOfSamples) } {
				# считываем среднее и станд. отклонение
				set cavg [scpi::query $cmm "CALCULATE:AVERAGE:AVERAGE?"]
				set cstd [scpi::query $cmm "CALCULATE:AVERAGE:SDEVIATION?"]
				
				set avg [scpi::query $mm "CALCULATE:AVERAGE:AVERAGE?"]
				set std [scpi::query $mm "CALCULATE:AVERAGE:SDEVIATION?"]

				# Добавляем систематическую погрешность
				# и возвращаем результат измерений, переведённый в милливольты и милливольты
				set cerr [measure::sigma::add $cstd [hardware::agilent::mm34410a::dciSystematicError $cavg]]
				set err [measure::sigma::add $std [hardware::agilent::mm34410a::dcvSystematicError $avg]]
				return [list [expr 1000.0 * abs($avg)] [expr 1000.0 * $err] [expr 1000.0 * abs($cavg)] [expr 1000.0 * $cerr] ]
			}
			
			# выведем прогресс измерения на индикаторы мультиметров
			scpi::cmd $mm "DISPLAY:WINDOW2:TEXT:DATA \"[format %0.0f [expr 100.0 * $n1 / $measure(numberOfSamples)]]% measured\""
			scpi::cmd $cmm "DISPLAY:WINDOW2:TEXT:DATA \"[format %0.0f [expr 100.0 * $n2 / $measure(numberOfSamples)]]% measured\""
		}

		error "Таймаут ожидания измерения напряжения"
	} else {
		# режим однократного измерения

		# Считываем напряжение
		set cres [scpi::query $cmm "READ?"]
		set res [scpi::query $mm "READ?"]

		# Добавляем систематическую погрешность
		# и возвращаем результат измерений, переведённый в милливольты
		set cerr [hardware::agilent::mm34410a::dciSystematicError $cres]
        set verr [hardware::agilent::mm34410a::dcvSystematicError $res]  
		return [list [expr 1000.0 * abs($res)] [expr 1000.0 * $verr] [expr 1000.0 * abs($cres)] [expr 1000.0 * $cerr] ]
	}
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
		error "Невозможно подключиться к мультиметру по адресу `$settings(mmAddr)'"
	}

    # Иниализируем и опрашиваем ММ
    hardware::agilent::mm34410a::init $mm

	# включаем режим измерения пост. напряжения
	scpi::cmd $mm "CONFIGURE:VOLTAGE:DC AUTO"

    # Включить авытовыбор диапазона
    scpi::cmd $mm "SENSE:VOLTAGE:DC:RANGE:AUTO ON"
    
	# Измерять напряжение в течении 10 циклов питания
	scpi::cmd $mm "SENSE:VOLTAGE:DC:NPLC 10"

    # Включить автоподстройку нуля, если не используется переполюсовка
    if { $measure(switchVoltage) || $measure(switchCurrent) } {
        set mode "OFF"
    } else {
        set mode "ONCE"
    }
    scpi::cmd $mm "SENSE:VOLTAGE:DC:ZERO:AUTO $mode"
    
    # Включить автоподстройку входного сопротивления
    scpi::cmd $mm "SENSE:VOLTAGE:DC:IMPEDANCE:AUTO ON"

	# Включить сбор статистики
	scpi::cmd $mm "CALCULATE:STATE ON"
	scpi::cmd $mm "CALCULATE:FUNCTION AVERAGE"
	
	# Число измерений на одну точку результата
	if { ![info exists measure(numberOfSamples)] || $measure(numberOfSamples) < 1 } {
		# Если не указано в настройках, по умолчанию равно 1
		set measure(numberOfSamples) 1
	}

	# Настраиваем триггер
    scpi::cmd $mm "TRIGGER:SOURCE IMMEDIATE"
    scpi::cmd $mm "SAMPLE:SOURCE IMMEDIATE"
    scpi::cmd $mm "SAMPLE:COUNT $measure(numberOfSamples)"
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

	# включаем режим измерения пост. тока
	scpi::cmd $cmm "CONFIGURE:CURRENT:DC AUTO"

    # Включить авытовыбор диапазона
    scpi::cmd $cmm "SENSE:CURRENT:DC:RANGE:AUTO ON"
    
	# Измерять напряжение в течении 10 циклов питания
	scpi::cmd $cmm "SENSE:CURRENT:DC:NPLC 10"

    # Включить автоподстройку нуля, если не используется переполюсовка
    if { $measure(switchVoltage) || $measure(switchCurrent) } {
        set mode "OFF"
    } else {
        set mode "ONCE"
    }
    scpi::cmd $cmm "SENSE:CURRENT:DC:ZERO:AUTO $mode"
    
	# Включить сбор статистики
	scpi::cmd $cmm "CALCULATE:STATE ON"
	scpi::cmd $cmm "CALCULATE:FUNCTION AVERAGE"
	
	# Число измерений на одну точку результата
	if { ![info exists measure(numberOfSamples)] || $measure(numberOfSamples) < 1 } {
		# Если не указано в настройках, по умолчанию равно 1
		set measure(numberOfSamples) 1
	}

	# Настраиваем триггер
    scpi::cmd $cmm "TRIGGER:SOURCE IMMEDIATE"
    scpi::cmd $cmm "SAMPLE:SOURCE IMMEDIATE"
    scpi::cmd $cmm "SAMPLE:COUNT $measure(numberOfSamples)"
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

###############################################################################
# Начало работы
###############################################################################

# Инициализируем протоколирование
set log [measure::logger::init measure]

# Эта команда будет вызвааться в случае преждевременной остановки потока
measure::interop::registerFinalization { finish }

# Читаем настройки программы
measure::config::read

# Создаём файл с результатами измерений
measure::datafile::create $measure(fileName) $measure(fileFormat) $measure(fileRewrite) [list "I (mA)" "+/- (mA)" "U (mV)" "+/- (mV)" "R (Ohm)" "+/- (Ohm)"]

# Подключаемся к менеджеру ресурсов VISA
set rm [visa::open-default-rm]

# Производим подключение к устройствам и их настройку
setupPs
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

# Устанавливаем выходной ток
setCurrent $measure(startCurrent)

# Включаем подачу тока на выходы ИП
hardware::agilent::pse3645a::setOutput $ps 1

# Холостое измерение для "прогрева" мультиметров
measureVoltage

# Пробегаем по всем токам из заданного диапазона
for { set curr $measure(startCurrent) } { $curr <= $measure(endCurrent) + 0.1 * $measure(currentStep) } { set curr [expr $curr + $measure(currentStep)] } {
    # проверим, не нажата ли кнопка остановки
    measure::interop::checkTerminated
    
	# выставляем ток на ИП
	setCurrent $curr

	set vsum 0.0
	set svsum 0.0
	set isum 0.0
	set sisum 0.0

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

		# Накапливаем сумму напряжения и погрешности
		lassign $res v sv i si
		set vsum [expr $vsum + $v]
		set svsum [expr $svsum + $sv]
		set isum [expr $isum + $i]
		set sisum [expr $sisum + $si]
          
        # Выводим результаты в окно программы
    	measure::interop::setVar runtime(current) [format "%0.9g \u2213 %0.2g" $i $si]
    	measure::interop::setVar runtime(voltage) [format "%0.9g \u2213 %0.2g" $v $sv]
    	measure::interop::setVar runtime(resistance) [format "%0.9g \u2213 %0.2g" [expr $v / $i] [measure::sigma::div $v $sv $i $si]]
    	measure::interop::setVar runtime(power) [format "%0.3g" [expr 0.001 * $i * $v]]
	}

	# Вычисляем средние значения тока, напряжения и погрешностей
	set v [expr $vsum / $nc]
	set sv [expr $svsum / $nc]
	set i [expr $isum / $nc]
	set si [expr $sisum / $nc]

    # Выводим результаты в результирующий файл
	measure::datafile::write $measure(fileName) $measure(fileFormat) [list $i $si $v $sv [expr $v / $i] [measure::sigma::div $v $sv $i $si] ]
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
