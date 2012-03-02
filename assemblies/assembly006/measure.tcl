#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 004
# Измерительный модуль
###############################################################################

package require measure::logger
package require measure::config
package require hardware::owen::mvu8
package require scpi
package require hardware::agilent::mm34410a
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
puts "!!! vs=$vs"	
	# среднее значение и погрешность измерения
	set v [expr abs([math::statistics::mean $vs])]; set sv [math::statistics::stdev $vs]; if { $sv == ""} { set sv 0 }
puts "!!! v=$v  sv=$sv"	
	# инструментальная погрешность
   	set vErr [hardware::agilent::mm34410a::dcvSystematicError $v "" [measure::config::get mm.nplc]]
puts "!!! vErr=$vErr"   	
	
	# определяем силу тока
	switch -exact -- [measure::config::get current.method] {
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
            set cs [split [scpi::query $cmm "DATA:REMOVE? $n"] ","]
            set vval [expr abs([math::statistics::mean $cs])] 
    		set newcs [list]
    		set rr [measure::config::get current.reference.resistance 1.0] 
    		foreach c $cs {
    			lappend newcs [expr $c / $rr]
    		}
    		set cs $newcs
            # среднее значение и погрешность измерения
        	set c [expr abs([math::statistics::mean $cs])]; set sc [math::statistics::stdev $cs]; if { $sc == ""} { set sc 0 }
    		# инструментальная погрешность
	    	set vvalErr [hardware::agilent::mm34410a::dcvSystematicError $vval "" [measure::config::get cmm.nplc]]
    		set rrErr [measure::config::get current.reference.error 0.0] 
	    	set cErr [measure::sigma::div $vval $vvalErr $rr $rrErr]
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
puts "!!! c=$c"
puts "!!! sc=$sc"    
puts "!!! cErr=$cErr"

	# вычисляем сопротивление
	set rs [list]
	foreach vv $vs cc $cs {
		lappend rs [expr $vv / $cc]
	}
puts "!!! rs=$rs"	

	# вычисляем средние значения и сигмы
	set r [expr abs([math::statistics::mean $rs])]; set sr [math::statistics::stdev $rs]; if { $sr == ""} { set sr 0 }
puts "!!! r=$r"
puts "!!! sr=$sr"	
   	set rErr [measure::sigma::div $v $vErr $c $cErr]
puts "!!! rErr=$rErr"   	

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
    global mm
    
    # Подключаемся к мультиметру (ММ)
    set mm [hardware::agilent::mm34410a::open \
		-baud [measure::config::get mm.baud] \
		-parity [measure::config::get mm.parity] \
		[measure::config::get -required mm.addr] \
	]

    # Иниализируем и опрашиваем ММ
    hardware::agilent::mm34410a::init $mm

	# Настраиваем мультиметр для измерения постоянного напряжения
	hardware::agilent::mm34410a::configureDcVoltage \
		-nplc [measure::config::get mm.nplc 10] \
		-autoZero ONCE	\
		-sampleCount [measure::config::get measure.numOfSamples 1]	\
		 $mm
}

# Инициализация амперметра
proc setupCMM {} {
    global cmm
    
    # прочитаем из настроек режим измерения тока
    set method [measure::config::get current.method 0]
    
    if { $method == 2 } {
        # в ручном режиме второй мультиметр не используется
        return
    } 
    
    # Подключаемся к мультиметру (ММ)
    set cmm [hardware::agilent::mm34410a::open \
		-baud [measure::config::get cmm.baud] \
		-parity [measure::config::get cmm.parity] \
		[measure::config::get -required cmm.addr] \
	]

    # Иниализируем и опрашиваем ММ
    hardware::agilent::mm34410a::init $cmm

    switch -exact -- $method {
        0 {
            # Ток измеряется непосредственно амперметром
        	# Настраиваем мультиметр для измерения постоянного тока
        	hardware::agilent::mm34410a::configureDcCurrent \
        		-nplc [measure::config::get nplc 10] \
        		-autoZero ONCE	\
        		-sampleCount [measure::config::get measure.numOfSamples 1]	\
        		 $cmm
        }
        1 {
            # Ток измеряется измерением надения напряжения на эталонном сопротивлении
        	# Настраиваем мультиметр для измерения постоянного напряжения
        	hardware::agilent::mm34410a::configureDcVoltage \
        		-nplc [measure::config::get cmm.nplc 10] \
        		-autoZero ONCE	\
        		-sampleCount [measure::config::get measure.numOfSamples 1]	\
        		 $cmm
        }
    }
}

# Процедура производит одно измерение со всеми нужными переполюсовками
#   и сохраняет результаты в файле результатов
proc makeMeasurement {} {
	global mm cmm connectors settings

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
		set res [doMeasure]

		# Накапливаем суммы
		lassign $res v sv c sc r sr
		lappend vs $v; lappend svs $sv
		lappend cs $c; lappend scs $sc
		lappend rs $r; lappend srs $sr

        # Выводим результаты в окно программы
        display $v $sv $c $sc $r $sr          
	}

	# Вычисляем средние значения
	set c [math::statistics::mean $cs]; set sc [math::statistics::mean $scs]
	set v [math::statistics::mean $vs]; set sv [math::statistics::mean $svs]
	set r [math::statistics::mean $rs]; set sr [math::statistics::mean $srs]

    # Выводим результаты в результирующий файл
	measure::datafile::write $settings(result.fileName) $settings(result.format) [list TIMESTAMP 0.0 0.0 $c $sc $v $sv $r $sr]
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

# подключаем тестовое сопротивление если требуется
connectTestResistance

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

makeMeasurement

###############################################################################
# Завершение измерений
###############################################################################

if { [info exists settings(beepOnExit)] && $settings(beepOnExit) } {
    # подаём звуковой сигнал об окончании измерений
	scpi::cmd $mm "SYST:BEEP"
	after 500
}

finish

