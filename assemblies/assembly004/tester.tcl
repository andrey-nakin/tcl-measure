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
package require hardware::agilent::pse3645a
package require hardware::agilent::mm34410a
package require tclvisa
package require measure::interop
package require measure::sigma
package require measure::measure

###############################################################################
# Подпрограммы
###############################################################################

# Инициализируем устройства
proc openDevices {} {
    global rm ps mm cmm settings

	# реле в исходное
	setConnectors { 0 0 0 0 }

	# Подключаемся к менеджеру ресурсов VISA
	set rm [visa::open-default-rm]

	# Производим подключение к устройствам и их настройку
	measure::measure::setupMmsForResistance -noFrontCheck
	if { !$settings(manualPower) } {
		setupPs

        after 500
		# Включаем подачу тока на выходы ИП
		hardware::agilent::pse3645a::setOutput $ps 1
	}
}

# Процедура производит периодический опрос приборов и выводит показания на экран
proc run {} {
	# инициализируем устройства
	openDevices

	# работаем в цикле пока не получен сигнал останова
	while { ![measure::interop::isTerminated] }	{
		set tm [clock milliseconds]

		# Снимаем показания
		lassign [measure::measure::resistance -n 1] v sv c sc r sr

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
