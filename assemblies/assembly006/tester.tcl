#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 006
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
package require measure::measure

###############################################################################
# Подпрограммы
###############################################################################

# Инициализируем устройства
proc openDevices {} {
	# реле в исходное
	setConnectors { 0 0 0 0 }

	# Производим подключение к устройствам и их настройку
	measure::measure::setupMmsForResistance -noFrontCheck
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
