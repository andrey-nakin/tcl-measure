#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 002
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

# Измеряет ток и напряжение на образце
# Возвращает напряжение, погрешность в милливольтах, ток и погрешность в миллиамперах, сопротивление и погрешность в омах
proc measureVoltage { } {
    global mm measure
    
	# запускаем измерение напряжения
	scpi::cmd $mm "INIT"

	# ждём завершения измерения напряжения
	scpi::query $mm "*OPC?"

	# списки для хранения значений
	set vs [list]

	# цикл измерения
	set n $measure(numberOfSamples)
	for { set i 0 } { $i < $n } { incr i } {
	    # проверим, не нажата ли кнопка остановки
	    measure::interop::checkTerminated

		# считываем напряжение
		set v [expr abs([scpi::query $mm "DATA:REMOVE? 1"])]
		lappend vs $v
	}

	return $vs
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

	if { [scpi::query $mm "ROUTE:TERMINALS?"] != "FRON" } {
		error "Turn Front/Rear switch of voltmeter to Front"
	}

	# включаем режим измерения пост. напряжения
	scpi::cmd $mm "CONFIGURE:VOLTAGE:DC AUTO"

    # Включить авытовыбор диапазона
    scpi::cmd $mm "SENSE:VOLTAGE:DC:RANGE:AUTO ON"
    
	# Измерять напряжение с макс. скоростью
	scpi::cmd $mm "SENSE:VOLTAGE:DC:NPLC MIN"

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
    scpi::cmd $mm "SAMPLE:SOURCE IMMEDIATE"
    scpi::cmd $mm "SAMPLE:TIMER [expr 1.0 / $measure(freq)]"
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
set vs [measureVoltage] 

# Записываем результаты в файл
set t 0.0
set interval [expr 1.0 / $measure(freq)]
foreach v $vs {
	# Выводим результаты в результирующий файл
	measure::datafile::write $measure(fileName) $measure(fileFormat) [list $t $v]
	set t [expr $t + $interval]
}

###############################################################################
# Завершение измерений
###############################################################################

finish

