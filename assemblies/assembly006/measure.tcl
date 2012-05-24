#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 004
# Измерительный модуль
###############################################################################

package require math::statistics
package require http 2.7
package require uri
package require hardware::owen::mvu8
package require hardware::agilent::mm34410a
package require measure::logger
package require measure::config
package require measure::datafile
package require measure::interop
package require measure::sigma
package require measure::ranges
package require measure::math
package require measure::tsclient
package require measure::measure
package require scpi

###############################################################################
# Константы
###############################################################################

# макс. время ожидания благоприятного момента для старта измерения, мс
set MAX_WAIT_TIME 1000

###############################################################################
# Подпрограммы
###############################################################################

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]

# Процедура производит одно измерение со всеми нужными переполюсовками
#   и сохраняет результаты в файле результатов
proc makeMeasurement { } {
	global mm cmm settings

    # Измеряем температуру до начала измерения                 
	array set tBefore [measure::tsclient::state]
	
	# Измеряем напряжение
	set res [measure::measure::resistance]

    # Измеряем температуру сразу после измерения                 
	array set tAfter [measure::tsclient::state]
	
	# вычисляем среднее значение температуры
	set T [expr 0.5 * ($tAfter(temperature) + $tBefore(temperature))]
	# и суммарную погрешность
	set dT [measure::sigma::add $tAfter(measureError) [expr 0.5 * abs($tAfter(temperature) - $tBefore(temperature))] ]
	
	# раскидываем массив по переменным
	lassign $res v sv c sc r sr

    # Выводим результаты в окно программы
    display $v $sv $c $sc $r $sr $T "result"

	# Выводим результаты в результирующий файл
	measure::datafile::write $settings(result.fileName) [list TIMESTAMP $T $dT $c $sc $v $sv $r $sr]
}

# Отправляем команду термостату 
proc setPoint { t } {
	# Отправляем команду термостату
	::measure::tsclient::setPoint $t

	# Выведем новую уставку на экран
	measure::interop::cmd [list setPointSet $t]
}

# Процедура определяет, вышли ли мы на нужные температурные условия
# и готовы ли к измерению сопротивления
proc canMeasure { stateArray setPoint } {
	global settings connectors MAX_WAIT_TIME
	upvar $stateArray state
	
	# скорость измерения температуры, К/мс
	set tspeed [expr $state(derivative1) / (60.0 * 1000.0)]

	# продолжительность измерительного цикла
	set tm [measure::measure::oneMeasurementDuration]

    # предполагаемая температура по окончании измерения
    set estimate [expr $state(temperature) + $tspeed * $tm ]

	# переменная хранит разницу между уставкой и текущей температурой
	set err [expr $setPoint - $state(temperature)]

	# переменная хранит значение true, если мы готовы к измерению
	set flag [expr abs($err) <= $settings(ts.maxErr) && abs($setPoint - $estimate) <= $settings(ts.maxErr) && abs($state(trend)) <= $settings(ts.maxTrend) && $state(sigma) <= $settings(ts.maxSigma) ]

	if { $flag } {
		# можно измерять!
		# вычислим задержку в мс для получения минимального отклонения температуры от уставки
		set delay [expr int($err / $tspeed - 0.5 * $tm) - ([clock milliseconds] - $state(timestamp))]
		if { $delay > $MAX_WAIT_TIME } {
			# нет, слишком долго ждать, отложим измерения до следующего раза
			set flag 0
		} elseif { $delay > 0 } {
			# выдержим паузу перед началом измерений
			measure::interop::sleep $delay
		}
	}

	return $flag
}

# Процедура измерения одной температурной точки
proc measureOnePoint { t } {
    global doSkipSetPoint settings log

	# Цикл продолжается, пока не выйдем на нужную температуру
	# или оператор не прервёт
	while { 1 } {
		# Проверяем, не была ли нажата кнопка "Стоп"
		measure::interop::checkTerminated

		# Считываем значение температуры
		set stateList [measure::tsclient::state]
		array set state $stateList 
		
		# Выводим температуру на экран
		measure::interop::cmd [list setTemperature $stateList]

		if { $doSkipSetPoint == "yes" || [canMeasure state $t] } {
			# Производим измерения
			makeMeasurement
			break
		}

		# Производим тестовое измерение сопротивления
		set tm [clock milliseconds]
		testMeasureAndDisplay $settings(trace.fileName) $settings(result.format)

        if { $doSkipSetPoint != "yes" } {
    		# Ждём или 1 сек или пока не изменится переменная doSkipSetPoint
    		after [expr int(1000 - ([clock milliseconds] - $tm))] set doSkipSetPoint timeout
    		vwait doSkipSetPoint
    		after cancel set doSkipSetPoint timeout
        }
	}
}

###############################################################################
# Обработчики событий
###############################################################################

# Команда пропустить одну точку в программе температур
proc skipSetPoint {} {
	global doSkipSetPoint

    global log
	set doSkipSetPoint yes
}

# Команда прочитать последние настройки
proc applySettings { lst } {
	global settings

	array set settings $lst
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

# Производим подключение к устройствам и их настройку
measure::measure::setupMmsForResistance

# Задаём наборы переполюсовок
# Основное положение переключателей
set connectors [list { 0 0 0 0 }]
if { $settings(switch.voltage) } {
	# Инверсное подключение вольтметра
	lappend connectors {1000 1000 0 0} 
}
if { $settings(switch.current) } {
	# Инверсное подключение источника тока
	lappend connectors { 0 0 1000 1000 }
	if { $settings(switch.voltage) } {
		# Инверсное подключение вольтметра и источника тока
		lappend connectors { 1000 1000 1000 1000 } 
	}
}
# устанавливаем переключатели в нужное для измерений положение
setConnectors [lindex $connectors 0]

# Создаём файлы с результатами измерений
measure::datafile::create $settings(result.fileName) $settings(result.format) $settings(result.rewrite) {
	"Date/Time" "T (K)" "+/- (K)" "I (mA)" "+/- (mA)" "U (mV)" "+/- (mV)" "R (Ohm)" "+/- (Ohm)" 
} $settings(result.comment)
measure::datafile::create $settings(trace.fileName) $settings(result.format) $settings(result.rewrite) {
	"Date/Time" "T (K)" "R (Ohm)" 
}

###############################################################################
# Основной цикл измерений
###############################################################################

# Холостое измерение для "прогрева" мультиметров
measure::measure::resistance -n 1

# Обходим все температурные точки, указанные в программе измерений
foreach t [measure::ranges::toList [measure::config::get ts.program ""]] {
	# Проверяем, не была ли нажата кнопка "Стоп"
	measure::interop::checkTerminated

	# Даём команду термостату на установление температуры
	setPoint $t

	# Переменная-триггер для пропуска точек в программе температур
	set doSkipSetPoint ""
	
	# Принудительно проводим измерения по истечении заданного таймаута
	if { $settings(ts.timeout) > 0 } {
	   after [expr int(60000 * $settings(ts.timeout))] set doSkipSetPoint yes
    }
	
	# Пробегаем по переполюсовкам
	foreach conn $connectors {
		# Устанавливаем нужную полярность
		if { [llength $connectors] > 1 } {
			setConnectors $conn
			
    		# Ждём окончания переходных процессов, 
    		after $settings(switch.delay)
		}

		# Работаем в заданной температурной точке
		measureOnePoint $t
    }

    # отменяем взведённый таймаут
	after cancel set doSkipSetPoint yes
}

###############################################################################
# Завершение измерений
###############################################################################

if { $settings(beepOnExit) } {
    # подаём звуковой сигнал об окончании измерений
	scpi::cmd $mm "SYST:BEEP"
	after 500
}

finish

