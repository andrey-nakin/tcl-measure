#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 004
# Тестовый модуль, работающий тогда, когда не работает измерительный модуль
# Его задача - периодически снимать показания приборов 
#   и выводить в окно программы
###############################################################################

package require measure::logger
package require measure::config
package require hardware::owen::mvu8
package require scpi
package require hardware::agilent::mm34410a
package require measure::interop
package require measure::sigma
package require measure::tsclient

###############################################################################
# Подпрограммы
###############################################################################

# Измеряет ток и напряжение на образце
# Возвращает напряжение, погрешность в милливольтах, ток и погрешность в миллиамперах, сопротивление и погрешность в омах
proc doMeasure { } {
    global mm cmm settings
    
	# измеряем напряжение на образце
	set v [expr abs([scpi::query $mm "READ?"])]
	# инструментальная погрешность
	set vErr [hardware::agilent::mm34410a::dcvSystematicError $v "" [measure::config::get mm.nplc]]

	# измеряем силу тока
	switch -exact -- $settings(current.method) {
        0 {
            # измеряем непосредственно ток
			set c [expr abs([scpi::query $cmm "READ?"])]
            # инструментальная погрешность
            set cErr [hardware::agilent::mm34410a::dciSystematicError $c "" [measure::config::get cmm.nplc]]
        }
        1 {
            # измеряем падение напряжения на эталоне
			set vv [expr abs([scpi::query $cmm "READ?"])] 
    		set rr [measure::config::get current.reference.resistance 1.0] 
			set c [expr $vv / $rr]
    		# инструментальная погрешность
            set vvErr [hardware::agilent::mm34410a::dcvSystematicError $vv "" [measure::config::get cmm.nplc]]
    		set rrErr [measure::config::get current.reference.error 0.0] 
	    	set cErr [measure::sigma::div $vv $vvErr $rr $rrErr]
        }
        2 {
            # ток измеряется вручную
            set c [expr 0.001 * [measure::config::get current.manual.current 1.0]]
            # инструментальная погрешность задаётся вручную
            set cErr [expr 0.001 * [measure::config::get current.manual.error 0.0]] 
        }
    }

	# вычисляем сопротивление
	set r [expr abs($v / $c)]
	# определяем инструментальную погрешность
	set rErr [measure::sigma::div $v $vErr $c $cErr]

	# возвращаем результат измерений, переведённый в милливольты и милливольты
	return [list [expr 1000.0 * $v] [expr 1000.0 * $vErr] [expr 1000.0 * $c] [expr 1000.0 * $cErr] $r $rErr]
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
    hardware::agilent::mm34410a::init -noFrontCheck $mm

	# Настраиваем мультиметр для измерения постоянного напряжения
	hardware::agilent::mm34410a::configureDcVoltage \
		-nplc [measure::config::get mm.nplc 10] \
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
    hardware::agilent::mm34410a::init -noFrontCheck $cmm

    switch -exact -- $settings(current.method) {
        0 {
            # Ток измеряется непосредственно амперметром
        	# Настраиваем мультиметр для измерения постоянного тока
			hardware::agilent::mm34410a::configureDcCurrent \
				-nplc [measure::config::get cmm.nplc 10] \
				-text2 "V2 CURRENT" \
				 $cmm
        }
        1 {
            # Ток измеряется измерением надения напряжения на эталонном сопротивлении
        	# Настраиваем мультиметр для измерения постоянного напряжения
			hardware::agilent::mm34410a::configureDcVoltage \
				-nplc [measure::config::get cmm.nplc 10] \
				-text2 "V2 VOLTAGE" \
				 $cmm
        }
    }
}

# Инициализируем устройства
proc openDevices {} {
	# реле в исходное
	setConnectors { 0 0 0 0 }

	# Производим подключение к устройствам и их настройку
	setupMM
	setupCMM
}

# Процедура производит периодический опрос приборов и выводит показания на экран
proc run {} {
	# инициализируем устройства
	openDevices

	# работаем в цикле пока не получен сигнал останова
	while { ![measure::interop::isTerminated] }	{
		set tm [clock milliseconds]

		# Снимаем показания
		lassign [doMeasure] v sv c sc r sr

        # Выводим результаты в окно программы
        display $v $sv $c $sc $r $sr          

		# Выдерживаем паузу
		measure::interop::sleep [expr int(500 - ([clock milliseconds] - $tm))]
	}
}

###############################################################################
# Начало работы
###############################################################################

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]

# Инициализируем протоколирование
set log [measure::logger::init measure]

# Читаем настройки программы
measure::config::read

# Проверяем правильность настроек
validateSettings

###############################################################################
# Основной цикл измерений
###############################################################################

# Эта команда будет вызваться в случае преждевременной остановки потока
measure::interop::registerFinalization { finish }

# Запускаем процедуру измерения
run

# Завершаем работу
finish

after 1000
