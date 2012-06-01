#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 004
# Тестовый модуль, работающий тогда, когда не работает измерительный модуль
# Его задача - периодически снимать показания приборов 
#   и выводить в окно программы
###############################################################################

package require measure::logger
package require measure::config
package require scpi
package require hardware::agilent::mm34410a
package require measure::interop
package require measure::sigma
package require measure::tsclient
package require measure::datafile
package require measure::measure

set DELAY 500

###############################################################################
# Подпрограммы
###############################################################################

# Процедура производит периодический опрос приборов и выводит показания на экран
proc run {} {
    global DELAY

	# инициализируем устройства
	setup

	# работаем в цикле пока не получен сигнал останова
    while { ![measure::interop::isTerminated] } {
        # считываем температуру
        lassign [readTemp] temp tempErr tempDer
        
        # регистрируем сопротивление
        readResistanceAndWrite $temp $tempErr $tempDer
        
        after $DELAY
    }
}

###############################################################################
# Начало работы
###############################################################################

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]

# Инициализируем протоколирование
set log [measure::logger::init tester]

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
