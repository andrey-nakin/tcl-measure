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
package require measure::datafile

###############################################################################
# Подпрограммы
###############################################################################

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

		# Измеряем сопротивление и выводим результаты в окно программы
		testMeasureAndDisplay

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
