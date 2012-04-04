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
    set newTimeout [expr int(10000 * $n)]
         
	# запускаем измерение напряжения
	scpi::cmd $mm "INIT"
	fconfigure $mm -timeout $newTimeout 

    if { [info exists cmm] } {
    	# запускаем измерение тока
    	scpi::cmd $cmm "INIT"
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
	set vs [split [scpi::query $mm "DATA:REMOVE? $n"] ","]
	# среднее значение и погрешность измерения
	set v [expr abs([math::statistics::mean $vs])]; set sv [math::statistics::stdev $vs]; if { $sv == ""} { set sv 0 }
	# инструментальная погрешность
   	set vErr [hardware::agilent::mm34410a::dcvSystematicError $v "" [measure::config::get mm.nplc]]
	
	# определяем силу тока
	switch -exact -- $settings(current.method) {
        0 {
            # измеряем непосредственно ток
            set cs [split [scpi::query $cmm "DATA:REMOVE? $n"] ","]
            # среднее значение и погрешность измерения
        	set c [expr abs([math::statistics::mean $cs])]; set sc [math::statistics::stdev $cs]; if { $sc == ""} { set sc 0 }
            # инструментальная погрешность
            set cErr [hardware::agilent::mm34410a::dciSystematicError $c "" [measure::config::get cmm.nplc]]
        }
        1 {
            # измеряем падение напряжения на эталоне
            set vvs [split [scpi::query $cmm "DATA:REMOVE? $n"] ","]
            set vv [expr abs([math::statistics::mean $vvs])] 
    		set rr [measure::config::get current.reference.resistance 1.0] 
    		set cs [list]
    		foreach c $vvs {
    			lappend cs [expr $c / $rr]
    		}
            # среднее значение и погрешность измерения
        	set c [expr abs([math::statistics::mean $cs])]; set sc [math::statistics::stdev $cs]; if { $sc == ""} { set sc 0 }
    		# инструментальная погрешность
	    	set vvErr [hardware::agilent::mm34410a::dcvSystematicError $vv "" [measure::config::get cmm.nplc]]
    		set rrErr [measure::config::get current.reference.error 0.0] 
	    	set cErr [measure::sigma::div $vv $vvErr $rr $rrErr]
        }
        2 {
            # ток измеряется вручную
            set c [expr 0.001 * [measure::config::get current.manual.current 1.0]]
            set cs [list]
            for { set i 0 } { $i < $n } { incr i } {
                lappend cs $c
            }
            # погрешности измерения нет
            set sc 0.0  
            # инструментальная погрешность задаётся вручную
            set cErr [expr 0.001 * [measure::config::get current.manual.error 0.0]] 
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

    if { ![measure::config::get measure.noSystErr 0] } {
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
		-sampleCount $settings(measure.numOfSamples)	\
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
        		-sampleCount $settings(measure.numOfSamples)	\
        		-scpiVersion $hardware::agilent::mm34410a::SCPI_VERSION   \
        		-text2 "V2 CURRENT" \
        		 $cmm
        }
        1 {
            # Ток измеряется измерением надения напряжения на эталонном сопротивлении
        	# Настраиваем мультиметр для измерения постоянного напряжения
        	hardware::agilent::mm34410a::configureDcVoltage \
        		-nplc $settings(cmm.nplc) \
        		-sampleCount $settings(measure.numOfSamples)	\
        		-scpiVersion $hardware::agilent::mm34410a::SCPI_VERSION   \
        		-text2 "V2 CURRENT" \
        		 $cmm
        }
    }
}

# Процедура вычисляет продолжительность одного измерения напряжения/тока в мс
proc oneMeasurementDuration {} {
	global settings

	return [hardware::agilent::mm34410a::measDur	\
		-nplc [measure::math::max $settings(mm.nplc) $settings(cmm.nplc)] \
		-sampleCount $settings(measure.numOfSamples)	\
	]
}

# Процедура производит одно измерение со всеми нужными переполюсовками
#   и сохраняет результаты в файле результатов
proc makeMeasurement {  stateArray temps } {
	global mm cmm connectors settings
	upvar $stateArray state

	set vs [list]; set svs [list]
	set cs [list]; set scs [list]
	set rs [list]; set srs [list]

	# Пробегаем по переполюсовкам
	set nc [llength $connectors]
	for { set i 0 } { $i < $nc } { incr i } {
		# Устанавливаем нужную полярность
		if { $nc > 1 } {
			setConnectors [lindex $connectors $i]
		}

		# Ждём окончания переходных процессов, 
		after $settings(switch.delay)

		# Измеряем напряжение
		set res [doMeasure]

		# Накапливаем суммы
		lassign $res v sv c sc r sr
		lappend vs $v; lappend svs $sv
		lappend cs $c; lappend scs $sc
		lappend rs $r; lappend srs $sr

        # Выводим результаты в окно программы
        display $v $sv $c $sc $r $sr

		# Выводим результаты в результирующий файл
		measure::datafile::write $settings(result.fileName) $settings(result.format) [list TIMESTAMP [lindex $temps $i] $state(measureError) $c $sc $v $sv $r $sr]
	}

	# Вычисляем средние значения
	set c [math::statistics::mean $cs]; set sc [math::statistics::mean $scs]
	set v [math::statistics::mean $vs]; set sv [math::statistics::mean $svs]
	set r [math::statistics::mean $rs]; set sr [math::statistics::mean $srs]

    # добавляем точку на график
    measure::interop::cmd [list addPointToChart $state(temperature) $r]
              
}

# Отправляем команду термостату 
proc setPoint { t } {
	# Отправляем команду термостату
	::measure::tsclient::setPoint $t

	# Выведем новую уставку на экран
	measure::interop::cmd [list setPointSet $t]
}

# Процедура вычисляет продолжительность измерения сопротивления в мс, 
# включая все нужные переполюсовки.
proc calcMeasureTime {} {
	global calcMeasureTime_cache
	
	if { ![info exists calcMeasureTime_cache] } {
		global settings
		
		set tm [oneMeasurementDuration]
		set d $settings(switch.delay)

		if { $settings(switch.voltage) && $settings(switch.current) } {
			return [expr 4.0 * $tm + 3.0 * $d
		}
		if { $settings(switch.voltage) || $settings(switch.current) } {
			return [expr 2.0 * $tm + $d
		}
		set calcMeasureTime_cache $tm
	}

	return $calcMeasureTime_cache
}

# Процедура определяет, вышли ли мы на нужные температурные условия
proc canMeasure { stateArray setPoint } {
	global settings connectors
	upvar $stateArray state
	
	# скорость измерения температуры, К/мс
	set tspeed [expr $state(derivative1) / (60.0 * 1000.0)]

	# продолжительность измерительного цикла
	set tm [calcMeasureTime]

    # предполагаемая температура по окончании измерения
    set estimate [expr $state(temperature) + $tspeed * $tm ]

	# переменная хранит разницу между уставкой и текущей температурой
	set err [expr $setPoint - $state(temperature)]

	# переменная хранит значение true, если мы готовы к измерению
	set flag [expr abs($err) <= $settings(ts.maxErr) && abs($setPoint - $estimate) <= $settings(ts.maxErr) && abs($state(trend)) <= $settings(ts.maxTrend) ]
	if { $flag } {
		# вычислим задержку в мс для получения минимального отклонения температуры от уставки
		set delay [expr $err / $tspeed - 0.5 * $tm - [clock milliseconds] + $state(timestamp)]
		if { $delay > 0 } {
			# выдержим паузу перед началом измерений
			measure::interop::sleep $delay
		} else {
			set delay 0.0
		}
	
		# вычисляем список предположительных температур в моменты измерения]
		set temps [list]
		set t [clock milliseconds]
		set dt [expr [oneMeasurementDuration] + $settings(switch.delay)]
		set nc [llength $connectors]
		for { set i 0 } { $i < $nc } { incr i } {
			lappend temps [expr ($t - $state(timestamp)) * $tspeed + $state(temperature)]
			set t [expr $t + $dt]
		}
		return $temps
	}

	return ""
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
measure::datafile::create $settings(result.fileName) $settings(result.format) $settings(result.rewrite) [list "Date/Time" "T (K)" "+/- (K)" "I (mA)" "+/- (mA)" "U (mV)" "+/- (mV)" "R (Ohm)" "+/- (Ohm)"]

# Производим подключение к устройствам и их настройку
setupMM
setupCMM

# Задаём наборы переполюсовок
# Основное положение переключателей
set connectors [list { 0 0 0 0 }]
if { [measure::config::get switch.voltage 0] } {
	# Инверсное подключение вольтметра
	lappend connectors {1000 1000 0 0} 
}
if { [measure::config::get switch.current 0] } {
	# Инверсное подключение источника тока
	lappend connectors { 0 0 1000 1000 }
	if { [measure::config::get switch.voltage 0] } {
		# Инверсное подключение вольтметра и источника тока
		lappend connectors { 1000 1000 1000 1000 } 
	}
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

	while { 1 } {
		# Проверяем, не была ли нажата кнопка "Стоп"
		measure::interop::checkTerminated

		# Считываем значение температуры
		set stateList [measure::tsclient::state]
		array set state $stateList 
		
		# Выводим температуру на экран
		measure::interop::cmd [list setTemperature $stateList]

		set temps [canMeasure state $t]
		if { $temps } {
			# Производим измерения
			makeMeasurement state $temps
			break
		}

		measure::interop::sleep 1000
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

