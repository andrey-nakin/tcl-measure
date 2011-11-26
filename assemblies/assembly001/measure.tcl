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
    global mm
    
    set res [hardware::scpi::query $mm "MEASURE:VOLTAGE?"]
	return [expr 1000.0 * $res]
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
    
    hardware::scpi::cmd $ps "VOLT 0.100"
}

# Инициализация мультиметра
proc setupMM {} {
    global mm rm settings
    
    # Подключаемся к мультиметру (ММ)
    if { [catch { set mm [visa::open $rm $settings(mmAddr)] } ] } {
		error "Невозможно подключиться к мультиметру по адресу `$settings(mmAddr)'"
	}

    # Иниализируем и опрашиваем ММ
    hardware::agilent::mm34410a::init $mm

	# Измерять напряжение в течении 100 циклов питания
	hardware::scpi::setAndQuery $mm "SENSE:VOLTAGE:DC:NPLC" 100
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
measure::datafile::create $measure(fileName) $measure(fileFormat) $measure(fileRewrite) [list "I (mA)" "U (mV)" "R (Ohm)" "W (mWt)"]

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

	# Пробегаем по переполюсовкам
	foreach conn $connectors {
		# Устанавливаем нужную полярность
		if { [llength $connectors] > 1 } {
			setConnectors $conn
		}

		# Ждём окончания переходных процессов, 
		# а также пока пройдёт 100 циклов питания 
		# (частота 50 Гц, 1 цикл = 20 мс).
		after 3000

		# Измеряем напряжение
		set v [measureVoltage]

		measure::datafile::write $measure(fileName) $measure(fileFormat) [list $curr $v [expr $v / $curr] [expr 0.001 * $curr * $v]]
	}
}

###############################################################################
# Завершение измерений
###############################################################################

finish

