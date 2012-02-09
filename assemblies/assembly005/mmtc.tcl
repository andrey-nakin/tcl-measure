#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 005
# Модуль измерения температуры при помощи мультиметра, 
#   управляемому по протоколу SCPI, и термопары.
###############################################################################

package require measure::logger
package require measure::config
package require scpi
package require hardware::agilent::mm34410a
package require measure::thermocouple
package require measure::com

###############################################################################
# Подпрограммы
###############################################################################

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]

# Измеряет напряжение на термопаре
# Возвращает напряжение и погрешность в вольтах
proc measureVoltage { } {
    global mm log
    
	# считываем значение напряжения
	set v [scpi::query $mm "READ?"]

	if { [measure::config::get mmtc.tc.negate 0] } {
		set v [expr -1.0 * $v]
	}

	# определяем инструментальную погрешность
	set vErr [hardware::agilent::mm34410a::dcvSystematicError $v "" [measure::config::get mmtc.mm.nplc]]

	# Возвращаем результат
	return [list $v $vErr]
}

# Вычисляем температуру по напряжению на термопаре
proc calcTemperature { v vErr } {
	return [measure::thermocouple::calcKelvin [measure::config::get mmtc.tc.type K] [measure::config::get mmtc.tc.fixedT 77.4] $v $vErr]
}

# Инициализация вольтметра
proc setupMM {} {
    global mm log
    
    # Подключаемся к мультиметру (ММ)
	${log}::debug "setupMM: opening multimeter"
    set mm [hardware::agilent::mm34410a::open \
		-baud [measure::config::get mmtc.mm.baud] \
		-parity [measure::config::get mmtc.mm.parity] \
		[measure::config::get -required mmtc.mm.addr] \
	]

    # Иниализируем и опрашиваем ММ
	${log}::debug "setupMM: initializing multimeter $mm"
    hardware::agilent::mm34410a::init -noFrontCheck $mm

	# Настраиваем мультиметр для измерения постоянного напряжения
	${log}::debug "setupMM: setting multimeter up"
	hardware::agilent::mm34410a::configureDcVoltage \
		-nplc [measure::config::get mmtc.mm.nplc 10] \
		 $mm
}

# Приведение мультиметра в исходное состояние
proc closeMM {} {
	global log mm

	${log}::debug "finish: closing multimeter"
	hardware::agilent::mm34410a::done $mm

	close $mm
}

###############################################################################
# Обработчики событий
###############################################################################

# Процедура вызывается при инициализации модуля
proc init { senderId senderCallback } {
	global log

	# Читаем настройки программы
	${log}::debug "init: reading settings"
	measure::config::read

	# Проверяем правильность настроек
	${log}::debug "init: validating settings"
	validateSettings

	# Инициализируем мультиметр
	${log}::debug "init: setting up multimeter"
	setupMM

	# Холостое измерение для "прогрева" мультиметра
	${log}::debug "init: dummy measure"
	measureVoltage 

	# Отправляем сообщение в поток управления
	thread::send -async $senderId [list $senderCallback [thread::id]]
}

# Процедура вызывается при завершени работы модуля
# Приводим устройства в исходное состояние
proc finish {} {
    global mm log

    ${log}::debug "finish: enter"
    
    if { [info exists mm] } {
    	# Переводим вольтметр в исходный режим
		closeMM
    }

    ${log}::debug "finish: exit"
}

# Процедура вызывается для чтения температуры
# Аргументы:
#   senderId - идентификатор управляющего потока
#   senderCallback - название процедуры-обработчика события для вызова
proc getTemperature { senderId senderCallback } {
	global log

	# Измеряем напряжение
	lassign [measureVoltage] v vErr

	# Переводим напряжение на термопаре в температуру
	lassign [calcTemperature $v $vErr] t tErr

	# Отправляем сообщение в поток управления
	thread::send -async $senderId [list $senderCallback $t $tErr]
}

###############################################################################
# Начало работы
###############################################################################

# Инициализируем протоколирование
set log [measure::logger::init mmtc]

