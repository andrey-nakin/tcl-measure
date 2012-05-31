# measure.tcl --
#
#   Measurement utils
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::measure 0.1.0

package require cmdline
package require math::statistics
package require measure::config
package require measure::sigma

namespace eval ::measure::measure {
  namespace export resistance 
}

# Инициализация мультиметров для измерений сопротивления
# - mm - канал связи с первым мультиметром (вольтметр или омметр)
# - cmm - канал связи со вторым мультиметром (амперметр или вольтметр), может отсутствовать
proc ::measure::measure::setupMmsForResistance { args } {
    global mm cmm
    
    set configOptions {
    	{noFrontCheck ""   "Do not check Front/Rear switch"}
    }
	set usage ": setupMmsForResistance \[options]\noptions:"
	array set params [::cmdline::getoptions args $configOptions $usage]
	
    # Подключаемся к мультиметру (ММ)
    set mm [hardware::agilent::mm34410a::open \
		-baud [measure::config::get mm.baud] \
		-parity [measure::config::get mm.parity] \
		-name "MM1" \
		[measure::config::get -required mm.addr] \
	]

    # Иниализируем и опрашиваем ММ
    global log
    if { [info exists params(noFrontCheck)] } {
        hardware::agilent::mm34410a::init -noFrontCheck $mm
    } else {
        hardware::agilent::mm34410a::init $mm
    }    

    set mmethod [measure::config::get current.method 0]
    set mmNplc [measure::config::get mm.nplc 10]
    
    if { $mmethod != 3 } {
    	# Настраиваем мультиметр для измерения постоянного напряжения
    	hardware::agilent::mm34410a::configureDcVoltage \
    		-nplc $mmNplc \
    		-scpiVersion $hardware::agilent::mm34410a::SCPI_VERSION   \
    		-text2 "MM1 VOLTAGE" \
    		 $mm
    } else {
    	# Настраиваем мультиметр для измерения сопротивления
    	hardware::agilent::mm34410a::configureResistance4w \
    		-nplc $mmNplc \
    		-scpiVersion $hardware::agilent::mm34410a::SCPI_VERSION   \
    		-text2 "MM1 RESISTANCE" \
    		 $mm
    }

    if { $mmethod > 1 } {
        # в данном режиме второй мультиметр не используется
        return
    } 
    
    set cmmNplc [measure::config::get cmm.nplc 10]
    
    # Подключаемся к мультиметру (ММ)
    set cmm [hardware::agilent::mm34410a::open \
		-baud [measure::config::get cmm.baud] \
		-parity [measure::config::get cmm.parity] \
		-name "MM2" \
		[measure::config::get -required cmm.addr] \
	]

    # Иниализируем и опрашиваем ММ
    hardware::agilent::mm34410a::init $cmm

    switch -exact -- $mmethod {
        0 {
            # Ток измеряется непосредственно амперметром
        	# Настраиваем мультиметр для измерения постоянного тока
        	hardware::agilent::mm34410a::configureDcCurrent \
        		-nplc $cmmNplc \
        		-scpiVersion $hardware::agilent::mm34410a::SCPI_VERSION   \
        		-text2 "MM2 CURRENT" \
        		 $cmm
        }
        1 {
            # Ток измеряется измерением надения напряжения на эталонном сопротивлении
        	# Настраиваем мультиметр для измерения постоянного напряжения
        	hardware::agilent::mm34410a::configureDcVoltage \
        		-nplc $cmmNplc \
        		-scpiVersion $hardware::agilent::mm34410a::SCPI_VERSION   \
        		-text2 "MM2 VOLTAGE" \
        		 $cmm
        }
    }
}

# Процедура вычисляет продолжительность одного измерения напряжения/тока в мс
# Результат:
#   Время измерения в мс
proc ::measure::measure::oneMeasurementDuration {} {
	return [hardware::agilent::mm34410a::measDur	\
		-nplc [::tcl::mathfunc::max [measure::config::get mm.nplc 10] [measure::config::get cmm.nplc 10] ] \
		-sampleCount [measure::config::get measure.numOfSamples 1]	\
	]
}

# Измеряет сопротивление образца
# Использует следующие глобальные переменные
# - mm - канал связи с первым мультиметром (вольтметр или омметр)
# - cmm - канал связи со вторым мультиметром (амперметр или вольтметр), может отсутствовать
# Опции:
#   n - кол-во отсчётов. Если не указано, использует значение из конфигурации
# Результат:
#   Напряжение, погрешность в милливольтах, ток и погрешность в миллиамперах, сопротивление и погрешность в омах
proc ::measure::measure::resistance { args } {
    global mm cmm

    set configOptions {
    	{n.arg ""   "number of samples"}
    }
	set usage ": resistance \[options]\noptions:"
	array set params [::cmdline::getoptions args $configOptions $usage]

    # кол-во отсчётов
    if { $params(n) == "" } {
    	set params(n) [measure::config::get measure.numOfSamples 1]
    }
	
    # сохраняем текущее значение таймаута и вычисляем новое
	set timeout [fconfigure $mm -timeout]
    set newTimeout [expr int(2.0 * [oneMeasurementDuration])]
        
    # считываем параметры измерения в локальные переменные 
    set mmethod [measure::config::get current.method 0]
    set noSystErr [measure::config::get measure.noSystErr 0]
    set mmNplc [measure::config::get mm.nplc 10]
    set cmmNplc [measure::config::get cmm.nplc 10]
     
    if { $mmethod == 3 } {
        # особый случай - измерение сопротивления при помощи омметра
    	fconfigure $mm -timeout $newTimeout 
	    set rs [split [scpi::query $mm ":SAMPLE:COUNT $params(n);:READ?;:SAMPLE:COUNT 1"] ","]
	    lassign [math::statistics::basic-stats $rs] r _ _ _ _ _ sr
        if { !$noSystErr } {
            # вычислим и добавим инструментальную погрешность
            set rErr [hardware::agilent::mm34410a::resistanceSystematicError $r "" $mmNplc]
            set sr [measure::sigma::add $sr $rErr]
        }
        
        # значение тестового тока зависит от сопротивления образца
        # подразумевается, что мультиметр - в режиме автовыбора диапазона
        set c [hardware::agilent::mm34410a::testCurrent $r]; set sc 0.0
        set v [expr $c * $r]; set sv 0.0
        
    	return [list $v $sv $c $sc $r $sr]
    }
    
	# запускаем измерение напряжения
	scpi::cmd $mm "SAMPLE:COUNT $params(n);:INIT"
	fconfigure $mm -timeout $newTimeout 

    if { [info exists cmm] } {
    	# запускаем измерение тока
    	scpi::cmd $cmm "SAMPLE:COUNT $params(n);:INIT"
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
	set vs [split [scpi::query $mm "DATA:REMOVE? $params(n);:SAMPLE:COUNT 1"] ","]
	# среднее значение и погрешность измерения
	set v [expr abs([math::statistics::mean $vs])]; set sv [math::statistics::stdev $vs]; if { $sv == ""} { set sv 0 }
	# инструментальная погрешность
   	set vErr [hardware::agilent::mm34410a::dcvSystematicError $v "" $mmNplc]
	
	# определяем силу тока
	switch -exact -- $mmethod {
        0 {
            # измеряем непосредственно ток
            set cs [split [scpi::query $cmm "DATA:REMOVE? $params(n);:SAMPLE:COUNT 1"] ","]
            # среднее значение и погрешность измерения
        	set c [expr abs([math::statistics::mean $cs])]; set sc [math::statistics::stdev $cs]; if { $sc == ""} { set sc 0 }
            # инструментальная погрешность
            set cErr [hardware::agilent::mm34410a::dciSystematicError $c "" $cmmNplc]
        }
        1 {
            # измеряем падение напряжения на эталоне
            set rr [measure::config::get current.reference.resistance 1.0] 
            set vvs [split [scpi::query $cmm "DATA:REMOVE? $params(n);:SAMPLE:COUNT 1"] ","]
            set vv [expr abs([math::statistics::mean $vvs])] 
    		set cs [list]
    		foreach c $vvs {
    			lappend cs [expr $c / $rr]
    		}
            # среднее значение и погрешность измерения
        	set c [expr abs([math::statistics::mean $cs])]; set sc [math::statistics::stdev $cs]; if { $sc == ""} { set sc 0 }
    		# инструментальная погрешность
	    	set vvErr [hardware::agilent::mm34410a::dcvSystematicError $vv "" $cmmNplc]
	    	set cErr [measure::sigma::div $vv $vvErr $rr [measure::config::get current.reference.error 0.0]]
        }
        2 {
            # ток измеряется вручную
            set c [expr 0.001 * [measure::config::get current.manual.current 0.0]]
            set cs [list]
            for { set i 0 } { $i < $params(n) } { incr i } {
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

    if { !$noSystErr } {
    	# суммируем инструментальную и измерительную погрешности
       	set sv [measure::sigma::add $vErr $sv]
       	set sc [measure::sigma::add $cErr $sc]
    	set sr [measure::sigma::add $rErr $sr]
    }

	# возвращаем результат измерений, переведённый в милливольты и амперывольты
	return [list [expr 1000.0 * $v] [expr 1000.0 * $sv] [expr 1000.0 * $c] [expr 1000.0 * $sc] $r $sr]
}
