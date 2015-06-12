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
package require hardware::owen::mvu8

namespace eval ::measure::measure {
  namespace export resistance 
}

# Инициализация мультиметров для измерений сопротивления
# - mm - канал связи с первым мультиметром (вольтметр или омметр)
# - cmm - канал связи со вторым мультиметром (амперметр или вольтметр), может отсутствовать
proc ::measure::measure::setupMmsForResistance { args } {
    global mm cmm log
    
    set configOptions {
    	{noFrontCheck ""   "Do not check Front/Rear switch"}
    }
	set usage ": setupMmsForResistance \[options]\noptions:"
	array set params [::cmdline::getoptions args $configOptions $usage]
	
	# метод измерения
    set mmethod [measure::config::get current.method 0]
    
	# Настраиваем блок комутации
	set serialAddr [measure::config::get switch.serialAddr]
	set rs485Addr [measure::config::get switch.rs485Addr]
	if { $serialAddr != "" && $rs485Addr != "" } {
		# Положение переполюсовок по умолчанию
		set conns { 0 0 0 0 }

	    if { $mmethod == 3 } {
	    	# в данном режиме цепь всегда разомкнута
			lappend conns 1000
		} else {
			lappend conns 0
		}

	    if { $mmethod == 2 } {
	    	# в данном режиме нужно замкнуть цепь вместо амперметра
			lappend conns 1000
		} else {
			lappend conns 0
		}

        hardware::owen::mvu8::modbus::setChannels $serialAddr $rs485Addr 0 $conns
	}
	
    # Подключаемся к мультиметру (ММ)
    set mm [hardware::agilent::mm34410a::open \
		-baud [measure::config::get mm.baud] \
		-parity [measure::config::get mm.parity] \
		-name "MM1" \
		[measure::config::get -required mm.addr] \
	]

    # Иниализируем и опрашиваем ММ
    if { [info exists params(noFrontCheck)] } {
        hardware::agilent::mm34410a::init -noFrontCheck $mm
    } else {
        hardware::agilent::mm34410a::init $mm
    }    

    set mmNplc [measure::config::get mm.nplc 10]
    
    if { $mmethod != 3 } {
    	# Настраиваем мультиметр для измерения постоянного напряжения
    	hardware::agilent::mm34410a::configureDcVoltage \
    		-nplc $mmNplc \
    		-text2 "MM1 VOLTAGE" \
    		 $mm
    } else {
    	# Настраиваем мультиметр для измерения сопротивления
    	hardware::agilent::mm34410a::configureResistance4w \
    		-nplc $mmNplc \
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
        		-text2 "MM2 CURRENT" \
        		 $cmm
        }
        1 {
            # Ток измеряется измерением надения напряжения на эталонном сопротивлении
        	# Настраиваем мультиметр для измерения постоянного напряжения
        	hardware::agilent::mm34410a::configureDcVoltage \
        		-nplc $cmmNplc \
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
    global mm cmm ps log

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
	set timeout 5000
	catch { set timeout [fconfigure $mm -timeout] }
    set newTimeout [expr int(2.0 * [oneMeasurementDuration])]
    if { $newTimeout < 10000 } {
        set newTimeout 10000
    }
        
    # считываем параметры измерения в локальные переменные 
    set mmethod [measure::config::get current.method 0]
    set noSystErr [measure::config::get measure.noSystErr 0]
    set mmNplc [measure::config::get mm.nplc 10]
    set cmmNplc [measure::config::get cmm.nplc 10]
     
    if { $mmethod == 3 } {
        # особый случай - измерение сопротивления при помощи омметра
    	catch { fconfigure $mm -timeout $newTimeout } 
    	if { $params(n) != 1 } {
    	    set rs [split [scpi::query $mm ":SAMPLE:COUNT $params(n);:READ?;:SAMPLE:COUNT 1"] ","]
        } else {
    	    set rs [split [scpi::query $mm ":READ?"] ","]
        }
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
	if { $params(n) != 1 } {
    	scpi::cmd $mm "SAMPLE:COUNT $params(n);:INIT"
    } else {
    	scpi::cmd $mm ":INIT"
    }
	catch { fconfigure $mm -timeout $newTimeout } 

    if { [info exists cmm] } {
    	# запускаем измерение тока
    	if { $params(n) != 1 } {
        	scpi::cmd $cmm "SAMPLE:COUNT $params(n);:INIT"
        } else {
        	scpi::cmd $cmm ":INIT"
        }
    	catch { fconfigure $cmm -timeout $newTimeout }
    } elseif { [info exists ps] } {
        # ток в цепи измеряем при помощи ИП
        set c [scpi::query $ps MEASURE:CURR?]
        set cErr [hardware::agilent::pse3645a::dciSystematicError $c]
    }

	# ждём завершения измерения напряжения и восстанавливаем таймаут
	scpi::query $mm "*OPC?"
	catch { fconfigure $mm -timeout $timeout }

    if { [info exists cmm] } {
    	# ждём завершения измерения тока и восстанавливаем таймаут
        scpi::query $cmm "*OPC?"
    	catch { fconfigure $cmm -timeout $timeout }
	}

	# считываем значение напряжения и вычисляем погрешность измерений
	set vs [split [scpi::query $mm "FETCH?"] ","] 
	if { $params(n) != 1 } {
    	scpi::cmd $mm "SAMPLE:COUNT 1"
    } 
	# среднее значение и погрешность измерения
	lassign [measure::sigma::sample $vs] v sv
	set v [expr abs($v)]
	# инструментальная погрешность
   	set vErr [hardware::agilent::mm34410a::dcvSystematicError $v "" $mmNplc]
	
	# определяем силу тока
	switch -exact -- $mmethod {
        0 {
            # измеряем непосредственно ток
        	set cs [split [scpi::query $cmm "FETCH?"] ","] 
        	if { $params(n) != 1 } {
            	scpi::cmd $cmm "SAMPLE:COUNT 1"
            } 
            # среднее значение и погрешность измерения
			lassign [measure::sigma::sample $cs] c sc
        	set c [expr abs($c)]
            # инструментальная погрешность
            set cErr [hardware::agilent::mm34410a::dciSystematicError $c "" $cmmNplc]
        }
        1 {
            # измеряем падение напряжения на эталоне
            set rr [measure::config::get current.reference.resistance 1.0]
            if { $params(n) != 1 } {
                set vvs [split [scpi::query $cmm "DATA:REMOVE? $params(n);:SAMPLE:COUNT 1"] ","]
            } else {
                set vvs [split [scpi::query $cmm "DATA:REMOVE? $params(n)"] ","]
            } 
            set vv [expr abs([math::statistics::mean $vvs])] 
    		set cs [list]
    		foreach c $vvs {
    			lappend cs [expr $c / $rr]
    		}
            # среднее значение и погрешность измерения
			lassign [measure::sigma::sample $cs] c sc
        	set c [expr abs($c)]
    		# инструментальная погрешность
	    	set vvErr [hardware::agilent::mm34410a::dcvSystematicError $vv "" $cmmNplc]
	    	set cErr [measure::sigma::div $vv $vvErr $rr [measure::config::get current.reference.error 0.0]]
        }
        2 {
            if { ![info exists c] } {
                # ток измеряется вручную
                set c [expr 0.001 * [measure::config::get current.manual.current 1.0]]
                # инструментальная погрешность задаётся вручную
                set cErr [expr 0.001 * [measure::config::get current.manual.error 0.0]] 
            }
            set cs [list]
            for { set i 0 } { $i < $params(n) } { incr i } {
                lappend cs $c
            }
            # погрешности измерения нет
            set sc 0.0  
        }
    }

	# вычисляем сопротивление
	set rs [list]
	foreach vv $vs cc $cs {
	    set r [expr $vv / $cc]
	    if { isNaN($r) } {
	       set r 0.0
        }
		lappend rs $r 
	}

	# вычисляем средние значения и сигмы
	lassign [measure::sigma::sample $rs] r sr
	set r [expr abs($r)]
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

# Вычисляет удельное сопротивление по абсолютному сопротивлению.
# Параметры образца берутся из файла конфигурации.
# Параметры:
#   r - сопротивление (Ом)
#   rErr - погрешность определения сопротивления (Ом)
#   dutCfgPrefix - префикс с файле конфигурации, используемый для задания параметра образца
# Результат:
#   удельное сопротивление (Ом * см) или пустая строка, если вычислить УС невозможно    
#   погрешность (Ом * см) или пустая строка, если вычислить УС невозможно    
proc ::measure::measure::calcRho { r rErr { dutCfgPrefix dut } } {
    set pi 3.141592653589793238462643383279
    # расстояние между потенциальными контактами и погрешность, мм
    set l [measure::config::get "${dutCfgPrefix}.l"]
    set lErr [measure::config::get "${dutCfgPrefix}.lErr" 0.0]
    # ширина образца и погрешность, мм
    set w [measure::config::get "${dutCfgPrefix}.width"]
    set wErr [measure::config::get "${dutCfgPrefix}.widthErr" 0.0]
    # толщина образца и погрешность, мм
    set t [measure::config::get "${dutCfgPrefix}.thickness"]
    set tErr [measure::config::get "${dutCfgPrefix}.thicknessErr" 0.0]
    
    if { $l == "" } {
        # не указано расстояние между потенциальными контактами
        # определение УС невозможно
        return { {} {} }
    }
    
    # переведём в см
    set l [expr 0.1 * $l]
    set lErr [expr 0.1 * $lErr]
    
    if { $w == "" || $t == "" } {
        # указано расстояние между потенциальными контактами,
        # но не указано сечение
        set rho [expr $r * $l * 2 * $pi]
        set rhoErr [::measure::sigma::mul $r $rErr $l $lErr]
        return [list $rho $rhoErr]  
    }
    
    # переведём в см
    set w [expr 0.1 * $w]
    set wErr [expr 0.1 * $wErr]
    set t [expr 0.1 * $t]
    set tErr [expr 0.1 * $tErr]
    
    # сечение и его погрешность, см^2
    set s [expr $w * $t]
    set sErr [::measure::sigma::mul $w $wErr $t $tErr]
    
    # погонное сопротивление и погрешность (Ом/см)
    set a [expr $r / $l]
    set aErr [::measure::sigma::div $r $rErr $l $lErr]
    
    set rho [expr $a * $s]
    set rhoErr [::measure::sigma::mul $a $aErr $s $sErr]
    return [list $rho $rhoErr]  
}

# Считывает из файла конфигурации параметры образца
# и формирует строку с параметрами
# Аргументы
#   dutCfgPrefix - префикс с файле конфигурации, используемый для задания параметра образца
# Результат:
#   строка с параметрами или пустая строка, если параметры не заданы  
proc measure::measure::dutParams { { dutCfgPrefix dut } } {
    # расстояние между потенциальными контактами и погрешность, мм
    set l [measure::config::get "${dutCfgPrefix}.l"]
    set lErr [measure::config::get "${dutCfgPrefix}.lErr" 0.0]
    # длина образца и погрешность, мм
    set len [measure::config::get "${dutCfgPrefix}.length"]
    set lenErr [measure::config::get "${dutCfgPrefix}.lengthErr" 0.0]
    # ширина образца и погрешность, мм
    set w [measure::config::get "${dutCfgPrefix}.width"]
    set wErr [measure::config::get "${dutCfgPrefix}.widthErr" 0.0]
    # толщина образца и погрешность, мм
    set t [measure::config::get "${dutCfgPrefix}.thickness"]
    set tErr [measure::config::get "${dutCfgPrefix}.thicknessErr" 0.0]
    
    set s ""
    if { $l != "" } {
        append s "l=$l +/- $lErr mm"
    } 
    if { $len != "" } {
        if { [string length $s] > 0 } {
            append s ", "
        }
        append s "length=$len +/- $lenErr mm"
    } 
    if { $w != "" } {
        if { [string length $s] > 0 } {
            append s ", "
        }
        append s "width=$w +/- $wErr mm"
    } 
    if { $t != "" } {
        if { [string length $s] > 0 } {
            append s ", "
        }
        append s "thickness=$t +/- $tErr mm"
    } 
    
    return $s
}
