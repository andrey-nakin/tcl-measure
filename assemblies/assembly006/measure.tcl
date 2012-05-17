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

# Измеряет ток и напряжение на образце
# Возвращает напряжение, погрешность в милливольтах, ток и погрешность в миллиамперах, сопротивление и погрешность в омах
proc doMeasure { } {
    global mm cmm settings

    # кол-во отсчётов
	set n $settings(measure.numOfSamples)
	
    # сохраняем текущее значение таймаута и вычисляем новое
	set timeout [fconfigure $mm -timeout]
    set newTimeout [expr int(2.0 * [oneMeasurementDuration])]
    global log
    ${log}::debug "doMeasure newTimeout=$newTimeout !!!"
         
	# запускаем измерение напряжения
	scpi::cmd $mm "SAMPLE:COUNT $n;:INIT"
	fconfigure $mm -timeout $newTimeout 

    if { [info exists cmm] } {
    	# запускаем измерение тока
    	scpi::cmd $cmm "SAMPLE:COUNT $n;:INIT"
    	fconfigure $cmm -timeout $newTimeout
    }

	# ждём завершения измерения напряжения и восстанавливаем таймаут
	scpi::query $mm "*OPC?"
	fconfigure $mm -timeout $timeout

    if { [info exists cmm] } {
    	# ждём завершения измерения тока и восстанавливаем таймаут
        scpi::query $cmm "*OPC?"
    	fconfigure $cmm -timeout $timeout
	}

	# считываем значение напряжения и вычисляем погрешность измерений
	set vs [split [scpi::query $mm "DATA:REMOVE? $n;:SAMPLE:COUNT 1"] ","]
	# среднее значение и погрешность измерения
	set v [expr abs([math::statistics::mean $vs])]; set sv [math::statistics::stdev $vs]; if { $sv == ""} { set sv 0 }
	# инструментальная погрешность
   	set vErr [hardware::agilent::mm34410a::dcvSystematicError $v "" $settings(mm.nplc)]
	
	# определяем силу тока
	switch -exact -- $settings(current.method) {
        0 {
            # измеряем непосредственно ток
            set cs [split [scpi::query $cmm "DATA:REMOVE? $n;:SAMPLE:COUNT 1"] ","]
            # среднее значение и погрешность измерения
        	set c [expr abs([math::statistics::mean $cs])]; set sc [math::statistics::stdev $cs]; if { $sc == ""} { set sc 0 }
            # инструментальная погрешность
            set cErr [hardware::agilent::mm34410a::dciSystematicError $c "" $settings(cmm.nplc)]
        }
        1 {
            # измеряем падение напряжения на эталоне
            set vvs [split [scpi::query $cmm "DATA:REMOVE? $n;:SAMPLE:COUNT 1"] ","]
            set vv [expr abs([math::statistics::mean $vvs])] 
    		set cs [list]
    		foreach c $vvs {
    			lappend cs [expr $c / $settings(current.reference.resistance)]
    		}
            # среднее значение и погрешность измерения
        	set c [expr abs([math::statistics::mean $cs])]; set sc [math::statistics::stdev $cs]; if { $sc == ""} { set sc 0 }
    		# инструментальная погрешность
	    	set vvErr [hardware::agilent::mm34410a::dcvSystematicError $vv "" $settings(cmm.nplc)]
	    	set cErr [measure::sigma::div $vv $vvErr $settings(current.reference.resistance) $settings(current.reference.error)]
        }
        2 {
            # ток измеряется вручную
            set c [expr 0.001 * $settings(current.manual.current)]
            set cs [list]
            for { set i 0 } { $i < $n } { incr i } {
                lappend cs $c
            }
            # погрешности измерения нет
            set sc 0.0  
            # инструментальная погрешность задаётся вручную
            set cErr [expr 0.001 * $settings(current.manual.error 0.0)] 
        }
    }

	# вычисляем сопротивление
	set rs [list]
	foreach vv $vs cc $cs {
		lappend rs [expr $vv / $cc]
	}

	# вычисляем средние значения и сигмы
	set r [expr abs([math::statistics::mean $rs])]; set sr [math::statistics::stdev $rs]; if { $sr == ""} { set sr 0 }
   	set rErr [measure::sigma::div $v $vErr $c $cErr]

    if { !$settings(measure.noSystErr) } {
    	# суммируем инструментальную и измерительную погрешности
       	set sv [measure::sigma::add $vErr $sv]
       	set sc [measure::sigma::add $cErr $sc]
    	set sr [measure::sigma::add $rErr $sr]
    }

	# возвращаем результат измерений, переведённый в милливольты и амперывольты
	return [list [expr 1000.0 * $v] [expr 1000.0 * $sv] [expr 1000.0 * $c] [expr 1000.0 * $sc] $r $sr]
}

# Инициализация вольтметра
proc setupMM {} {
    global mm settings
    
    # Подключаемся к мультиметру (ММ)
    set mm [hardware::agilent::mm34410a::open \
		-baud [measure::config::get mm.baud] \
		-parity [measure::config::get mm.parity] \
		-name "V1" \
		[measure::config::get -required mm.addr] \
	]

    # Иниализируем и опрашиваем ММ
    hardware::agilent::mm34410a::init $mm

	# Настраиваем мультиметр для измерения постоянного напряжения
	hardware::agilent::mm34410a::configureDcVoltage \
		-nplc $settings(mm.nplc) \
		-scpiVersion $hardware::agilent::mm34410a::SCPI_VERSION   \
		-text2 "V1 VOLTAGE" \
		 $mm
}

# Инициализация амперметра
proc setupCMM {} {
    global cmm settings
    
    if { $settings(current.method) == 2 } {
        # в ручном режиме второй мультиметр не используется
        return
    } 
    
    # Подключаемся к мультиметру (ММ)
    set cmm [hardware::agilent::mm34410a::open \
		-baud [measure::config::get cmm.baud] \
		-parity [measure::config::get cmm.parity] \
		-name "V2" \
		[measure::config::get -required cmm.addr] \
	]

    # Иниализируем и опрашиваем ММ
    hardware::agilent::mm34410a::init $cmm

    switch -exact -- $settings(current.method) {
        0 {
            # Ток измеряется непосредственно амперметром
        	# Настраиваем мультиметр для измерения постоянного тока
        	hardware::agilent::mm34410a::configureDcCurrent \
        		-nplc $settings(cmm.nplc) \
        		-scpiVersion $hardware::agilent::mm34410a::SCPI_VERSION   \
        		-text2 "V2 CURRENT" \
        		 $cmm
        }
        1 {
            # Ток измеряется измерением надения напряжения на эталонном сопротивлении
        	# Настраиваем мультиметр для измерения постоянного напряжения
        	hardware::agilent::mm34410a::configureDcVoltage \
        		-nplc $settings(cmm.nplc) \
        		-scpiVersion $hardware::agilent::mm34410a::SCPI_VERSION   \
        		-text2 "V2 VOLTAGE" \
        		 $cmm
        }
    }
}

# Процедура вычисляет продолжительность одного измерения напряжения/тока в мс
proc oneMeasurementDuration {} {
	global settings

	return [hardware::agilent::mm34410a::measDur	\
		-nplc [::tcl::mathfunc::max $settings(mm.nplc) $settings(cmm.nplc)] \
		-sampleCount $settings(measure.numOfSamples)	\
	]
}

# Процедура производит одно измерение со всеми нужными переполюсовками
#   и сохраняет результаты в файле результатов
proc makeMeasurement { } {
	global mm cmm settings

    # Измеряем температуру до начала измерения                 
	array set tBefore [measure::tsclient::state]
	
	# Измеряем напряжение
	set res [doMeasure]

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
	set tm [oneMeasurementDuration]

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
    global doSkipSetPoint settings

	# Цикл продолжается, пока не выйдем на нужную температуру
	# или оператор не прервёт
	while { $doSkipSetPoint != "yes" } {
		# Проверяем, не была ли нажата кнопка "Стоп"
		measure::interop::checkTerminated

		# Считываем значение температуры
		set stateList [measure::tsclient::state]
		array set state $stateList 
		
		# Выводим температуру на экран
		measure::interop::cmd [list setTemperature $stateList]

		if { [canMeasure state $t] } {
			# Производим измерения
			makeMeasurement
			break
		}

		# Производим тестовое измерение сопротивления
		set tm [clock milliseconds]
		testMeasureAndDisplay $settings(trace.fileName) $settings(result.format)

		# Ждём или 1 сек или пока не изменится переменная doSkipSetPoint
		after [expr int(1000 - ([clock milliseconds] - $tm))] set doSkipSetPoint timeout
		vwait doSkipSetPoint
		after cancel set doSkipSetPoint timeout
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
setupMM
setupCMM

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

# Создаём файлы с результатами измерений
measure::datafile::create $settings(result.fileName) $settings(result.format) $settings(result.rewrite) {
	"Date/Time" "T (K)" "+/- (K)" "I (mA)" "+/- (mA)" "U (mV)" "+/- (mV)" "R (Ohm)" "+/- (Ohm)" 
}
measure::datafile::create $settings(trace.fileName) $settings(result.format) $settings(result.rewrite) {
	"Date/Time" "T (K)" "R (Ohm)" 
}

###############################################################################
# Основной цикл измерений
###############################################################################

# Холостое измерение для "прогрева" мультиметров
doMeasure

# Обходим все температурные точки, указанные в программе измерений
foreach t [measure::ranges::toList [measure::config::get ts.program ""]] {
	# Проверяем, не была ли нажата кнопка "Стоп"
	measure::interop::checkTerminated

	# Даём команду термостату на установление температуры
	setPoint $t

	# Переменная-триггер для пропуска точек в программе температур
	set doSkipSetPoint ""
	
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
    	
    	if { $doSkipSetPoint == "yes" } {
        	# коннекторы в исходное
    		break
    	}
    }
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

