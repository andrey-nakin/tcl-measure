#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 002
# Измерительный модуль
###############################################################################

package require Tcl 8.5
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

# Измеряет ток и напряжение на образце
# Возвращает напряжение, погрешность в милливольтах, ток и погрешность в миллиамперах, сопротивление и погрешность в омах
proc measureVoltage { } {
    global mm measure
    
	# выставим нужный таймаут
	set timeout [fconfigure $mm -timeout]
	fconfigure $mm -timeout [expr int(10000 * $measure(numberOfSamples))]

	# запускаем измерение напряжения
	scpi::cmd $mm "INIT"

	# ждём завершения измерения напряжения, замеряем продолжительность измерения
	set tm [clock milliseconds]
	scpi::query $mm "*OPC?"
	set tm [expr 0.001 * ([clock milliseconds] - $tm)]

    # восстановим таймаут
	fconfigure $mm -timeout $timeout

	# считываем значения напряжения
	set n $measure(numberOfSamples)
	set vs [split [scpi::query $mm "DATA:REMOVE? $n"] ","]

	return [list $vs $tm]
}

# Инициализация вольтметра
proc setupMM {} {
    global mm rm settings measure
    
    set interval [expr 1.0 / $measure(freq)]
    
    # Подключаемся к мультиметру (ММ)
    if { [catch { set mm [visa::open $rm $settings(mmAddr)] } ] } {
		error "Невозможно подключиться к мультиметру по адресу `$settings(mmAddr)'"
	}

    # Иниализируем и опрашиваем ММ
    hardware::agilent::mm34410a::init $mm

	if { [scpi::query $mm "ROUTE:TERMINALS?"] != "FRON" } {
		error "Turn Front/Rear switch of voltmeter to Front"
	}

	# включаем режим измерения пост. напряжения
	scpi::cmd $mm "CONFIGURE:VOLTAGE:DC AUTO"

    # Включить авытовыбор диапазона
    scpi::cmd $mm "SENSE:VOLTAGE:DC:RANGE:AUTO ONCE"
    
	# Измерять напряжение с макс. возможным разрешением
	scpi::cmd $mm "SENSE:VOLTAGE:DC:NPLC [hardware::agilent::mm34410a::nplc $interval]"

    # Выключить автоподстройку нуля
    scpi::cmd $mm "SENSE:VOLTAGE:DC:ZERO:AUTO OFF"
    
    # Включить автоподстройку входного сопротивления
    scpi::cmd $mm "SENSE:VOLTAGE:DC:IMPEDANCE:AUTO ON"

	# Число измерений на одну точку результата
	if { ![info exists measure(numberOfSamples)] || $measure(numberOfSamples) < 1 } {
		# Если не указано в настройках, по умолчанию равно 1
		error "Number of samples is not specified"
	}

	# Настраиваем триггер
    scpi::cmd $mm "TRIGGER:SOURCE IMMEDIATE"
    scpi::cmd $mm "TRIGGER:DELAY MIN"
    scpi::cmd $mm "SAMPLE:SOURCE TIMER"
    scpi::cmd $mm "SAMPLE:TIMER $interval"
    scpi::cmd $mm "SAMPLE:COUNT $measure(numberOfSamples)"
}

# Завершаем работу установки, матчасть в исходное.
proc finish {} {
    global mm

	# Переводим вольтметр в исходный режим
	hardware::agilent::mm34410a::done $mm
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
measure::datafile::create $measure(fileName) $measure(fileFormat) $measure(fileRewrite) [list "Time (s)" "U (V)"]

# Подключаемся к менеджеру ресурсов VISA
set rm [visa::open-default-rm]

# Производим подключение к устройствам и их настройку
setupMM

###############################################################################
# Основной цикл измерений
###############################################################################

# Холостое измерение для "прогрева" мультиметров
measureVoltage

# Снимаем напряжение
lassign [measureVoltage] vs tm 

# Записываем результаты в файл
set t 0.0
set interval [expr $tm / $measure(numberOfSamples)]
set f [open $measure(fileName) a]
foreach v $vs {
	# Выводим результаты в результирующий файл
	puts $f "$t\t$v"
	set t [expr $t + $interval]
}
close $f

###############################################################################
# Завершение измерений
###############################################################################

finish

