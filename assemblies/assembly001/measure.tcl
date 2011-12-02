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

###############################################################################
# Подпрограммы
###############################################################################

# Устанавливает ток питания образца
proc setCurrent { curr } {
    global ps

	# Очищаем очередь ошибок
	hardware::scpi::cmd $ps "*CLS"

	# Задаём выходной ток с переводом из мА в А
    hardware::scpi::cmd $ps "CURRENT [expr 0.001 * $curr]"

	# Нет ли ошибки?
    #set ans [hardware::scpi::query $ps "SYSTEM:ERROR?"]
}

# Измеряет напряжение на образце
proc measureVoltage { } {
    global mm measure
    
	# запускаем измерения
	hardware::scpi::cmd $mm "INIT"

	# цикл ожидания конца измерений
	for { set i 0 } { $i < $measure(numberOfSamples) } { incr i } {
		# немного подождём
		after 1000
		
		# считываесм число накопленных в статистике измерений
		set n [hardware::scpi::query $mm "CALCULATE:AVERAGE:COUNT?"]
		if { $n >= $measure(numberOfSamples) } {
			# считываем среднее и станд. отклонение
			set avg [hardware::scpi::query $mm "CALCULATE:AVERAGE:AVERAGE?"]
			set std [hardware::scpi::query $mm "CALCULATE:AVERAGE:SDEVIATION?"]

			# возвращаем результат измерений, переведённый в милливольты
			return [list [expr 1000.0 * $avg] [expr 1000.0 * $std]]
		}
	}

	error "Таймаут ожидания измерения напряжения"

#    set t [clock milliseconds]
#    set res [hardware::scpi::query $mm "READ?"]
#	return [expr 1000.0 * $res]
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
    
    hardware::scpi::cmd $ps "APPLY 35.000,0.001"
}

# Инициализация мультиметра
proc setupMM {} {
    global mm rm settings measure
    
    # Подключаемся к мультиметру (ММ)
    if { [catch { set mm [visa::open $rm $settings(mmAddr)] } ] } {
		error "Невозможно подключиться к мультиметру по адресу `$settings(mmAddr)'"
	}

    # Иниализируем и опрашиваем ММ
    hardware::agilent::mm34410a::init $mm

	# включаем режим измерения пост. напряжения
	hardware::scpi::cmd $mm "CONFIGURE:VOLTAGE:DC AUTO"

	# Измерять напряжение в течении 10 циклов питания
	hardware::scpi::cmd $mm "SENSE:VOLTAGE:DC:NPLC 10"

    # Включить подстройку ноля
    hardware::scpi::cmd $mm "SENSE:VOLTAGE:DC:ZERO:AUTO ON"
    
    # Включить автоподстройку входного сопротивления
    hardware::scpi::cmd $mm "SENSE:VOLTAGE:DC:IMPEDANCE:AUTO ON"

	# Включить сбор статистики
	hardware::scpi::cmd $mm "CALCULATE:STATE ON;CALCULATE:FUNCTION AVERAGE"
	
	# Число измерений на одну точку результата
	if { ![info exists measure(numberOfSamples)] } {
		# Если не указано в настройках, по умолчанию равно 1
		set measure(numberOfSamples) 1
	}

	# Настраиваем триггер
    hardware::scpi::cmd $mm "TRIGGER:SOURCE IMMEDIATE;SAMPLE:SOURCE IMMEDIATE;SAMPLE:COUNT $measure(numberOfSamples)"
}

# Завершаем работу установки, матчасть в исходное.
proc finish {} {
    global ps mm

	# Переводим ИП в исходный режим
	hardware::agilent::pse3645a::done $ps

	# Переводим ММ в исходный режим
	hardware::agilent::mm34410a::done $mm

	# реле в исходное
	setConnectors { 0 0 0 0 }
}

###############################################################################
# Начало работы
###############################################################################

# Инициализируем протоколирование
set log [measure::logger::init measure]

# Читаем настройки программы
measure::config::read

# Создаём файл с результатами измерений
measure::datafile::create $measure(fileName) $measure(fileFormat) $measure(fileRewrite) [list "I (mA)" "U (mV)" "+/- (mV)" "R (Ohm)" "+/- (Ohm)"]

# Подключаемся к менеджеру ресурсов VISA
set rm [visa::open-default-rm]

# Подключаемся к устройствам
setupPs
setupMM

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

# Пробегаем по всем токам из заданного диапазона
for { set curr $measure(startCurrent) } { $curr <= $measure(endCurrent) + 0.1 } { set curr [expr $curr + $measure(currentStep)] } {
	setCurrent $curr
	measure::interop::setVar runtime(current) $curr

	set vsum 0.0
	set ssum 0.0

	# Пробегаем по переполюсовкам
	foreach conn $connectors {
		# Устанавливаем нужную полярность
		if { [llength $connectors] > 1 } {
			setConnectors $conn
		}

		# Ждём окончания переходных процессов, 
		after 10000

		# Измеряем напряжение
		set res [measureVoltage]

		# Вычисляем производные ведличины
		set v [lindex $res 0]
		set r [expr $v / $curr]
        set pw [expr 0.001 * $curr * $v]
		set vsum [expr $vsum + $v]
		set ssum [expr $ssum + [lindex $res 1]]
          
        # Выводим округлённые результаты в окно программы
    	measure::interop::setVar runtime(voltage) [format "%0.9g" $v]
    	measure::interop::setVar runtime(resistance) [format "%0.9g" $r]
    	measure::interop::setVar runtime(power) [format "%0.9g" $pw]
	}

	# среднее значение напряжения
	set v [expr $vsum / [llength $connectors]]
	set sv [expr $ssum / [llength $connectors]]
	set r [expr $v / $curr]
    set pw [expr 0.001 * $curr * $v]
	set vsum [expr $vsum + $v]

    # Выводим результаты в результирующий файл
	measure::datafile::write $measure(fileName) $measure(fileFormat) [list $curr $v $sv $r [expr $sv / $curr]]
}

###############################################################################
# Завершение измерений
###############################################################################

finish

