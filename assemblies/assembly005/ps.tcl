#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 005
# Модуль управления током питания печки
# Использует управляемый источник постоянного тока Agilent E3645A 
#   или аналогичный по набору SCPI команд
###############################################################################

package require Thread
package require measure::logger
package require measure::config
package require scpi
package require hardware::agilent::pse3645a
package require measure::com

###############################################################################
# Подпрограммы
###############################################################################

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]

# Инициализация источника питания
proc setupPs {} {
    global ps
    
    # Подключаемся к источнику питания (ИП)
    set ps [hardware::agilent::pse3645a::open \
		-baud [measure::config::get ps.baud] \
		-parity [measure::config::get ps.parity] \
		[measure::config::get -required ps.addr] \
	]

    # Иниализируем и опрашиваем ИП
    hardware::agilent::pse3645a::init $ps

	# Работаем в области бОльших напряжений
    scpi::cmd $ps "VOLTAGE:RANGE HIGH"
    
	# Задаём пределы по напряжению и току
    scpi::cmd $ps "APPLY 60.000,0.001"
}

###############################################################################
# Обработчики событий
###############################################################################

# Процедура вызывается при инициализации модуля
proc init {} {
	global log settings

	# Читаем настройки программы
	${log}::debug "init: reading settings"
	measure::config::read

	# Проверяем правильность настроек
	${log}::debug "init: validating settings"
	validateSettings

	# Инициализируем ИП
	setupPs
}

# Процедура вызывается при завершени работы модуля
# Приводим устройства в исходное состояние
proc finish {} {
    global log ps

    if { [info exists ps] } {
    	# Переводим ИП в исходный режим
    	hardware::agilent::pse3645a::done $ps
    	close $ps
    	unset ps
    }
	
	# выдержим паузу
	after 500

	# завершаем работу потока
	thread::exit
}

# Процедура вызываетя для установки тока питания
# Аргументы:
#   current - ток
#   senderId - идентификатор управляющего потока
#   senderCallback - название процедуры-обработчика события для вызова
proc setCurrent { current senderId senderCallback } {
	global log ps hardware::agilent::pse3645a::MAX_CURRENT_HIGH_VOLTAGE

	${log}::debug "setCurrent: entering {$current $senderId $senderCallback}"

	if { $current > $MAX_CURRENT_HIGH_VOLTAGE } {
		set current $MAX_CURRENT_HIGH_VOLTAGE
	}

	# Задаём выходной ток с переводом из мА в А
    scpi::cmd $ps "CURRENT $current"

	# Измеряем напряжение на выходах ИП
    set v [scpi::query $ps "MEASURE:VOLTAGE?"

	# Отправляем сообщение в поток управления
	${log}::debug "setCurrent: sending response"
	thread::send -async $senderId [list $senderCallback $current $v]
}

###############################################################################
# Начало работы
###############################################################################

# Инициализируем протоколирование
set log [measure::logger::init ps]

# Входим в цикл обработки сообщений
thread::wait

