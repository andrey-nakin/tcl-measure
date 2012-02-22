#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 005
# Модуль термостатирования
# Алгоритм управления: ПИД-регулятор
###############################################################################

package require Thread
package require measure::logger
package require measure::config
package require measure::interop

###############################################################################
# Константы
###############################################################################

# Переменная, используемая для синхронизации
set mutexVar 0

# Переменная для хранения состояния ПИД-регулятора
array set pidState [list lastError 0.0 lastResult 0.0 setPoint 0.0 iaccum 0.0 currentTemperature 0.0]

set lastTime ""

###############################################################################
# Подпрограммы
###############################################################################

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]

# процедура, реализующая алгоритм ПИД
proc pidCalc { dt } {
	global pidState settings log

	if { ![info exists pidState(currentTemperature)] || ![info exists pidState(setPoint)] || ![info exists pidState(lastTemperature)] } {
		return 0.0
	}

#!!!
#	return [expr 0.001 * $pidState(setPoint)]

	# текущее значение невязки	
	set err [expr $pidState(setPoint) - $pidState(currentTemperature)]

    # calculate the proportional term
    set pTerm [expr $settings(pid.tp) * $err]
    
    # calculate the integral state with appropriate limiting
    set pidState(iaccum) [expr $pidState(iaccum) + $err]
    set maxi [measure::config::get pid.maxi]
    if { $maxi != "" } {
        if { $pidState(iaccum) > $maxi } {
            set pidState(iaccum) $maxi 
        } 
        if { $pidState(iaccum) < -$maxi } {
            set pidState(iaccum) [expr -1.0 * $maxi] 
        } 
    }
    
    # calculate the integral term
    set iTerm [expr $settings(pid.ti) * $pidState(iaccum)]
    
    # calculate differential term
    set dTerm [expr $settings(pid.td) * ($pidState(currentTemperature) - $pidState(lastTemperature))]
    set pidState(lastTemperature) $pidState(currentTemperature)  

	set result [expr $pTerm + $iTerm - $dTerm]
    ${log}::debug "pidCalc result:\t$result\t$pTerm\t$iTerm\t$dTerm"

	# сохраним невязку для использования на следующем шаге
	set pidState(lastError) $err

	# сохраним текущий результат для использования на следующем шаге
	set pidState(lastResult) $result

	return $result
}

# вычисляет новое значение тока
proc calcCurrent {} {
	global settings lastTime

	set curTime [clock milliseconds]

	if { $lastTime != "" } {
		# время в мс, прошедшее с момента предыдущего измерения
		set dt [expr $curTime - $lastTime]

		# определим новое значение тока питания
		set result [pidCalc $dt]
	} else {
		# это первое измерение
		set result 0.0
	}

	set lastTime $curTime

	return [expr 0.001 * $result]
}

proc finish {} {
	global log

	# закрываем дочерние модули
	destroyChildren
}

###############################################################################
# Обработчики событий
###############################################################################

# Процедура вызывается модулем измерения температуры
proc setTemperature { t tErr } {
	global mutexVar pidState log

    set pidState(lastTemperature) $pidState(currentTemperature)
	set pidState(currentTemperature) $t

	# Выводим температуру в окне
	measure::interop::cmd [list setTemperature $t $tErr [expr $pidState(setPoint) - $t]]

	# Изменяем значение переменной синхронизации для остановки ожидания
	incr mutexVar
}

# Процедура вызывается модулем регулировки тока питания печки
proc currentSet { current voltage } {
	global mutexVar log

	# Выводим параметры питания в окне
	measure::interop::cmd [list setPower $current $voltage]

	# Изменяем значение переменной синхронизации для остановки ожидания
	incr mutexVar
}

# Процедура изменяет значение уставки
proc setPoint { t } {
	global pidState log

	${log}::debug "setPoint: enter, t=$t"
	set pidState(setPoint) $t
	set pidState(iaccum) 0.0

	measure::interop::setVar runtime(setPoint) [format "%0.1f" $t]
}

# Процедура изменяет параметры ПИДа
proc setPid { tp td ti maxi } {
    global settings
    
    set settings(pid.tp) $tp
    set settings(pid.td) $td
    set settings(pid.ti) $ti
    set settings(pid.maxi) $maxi 
}

###############################################################################
# Начало работы
###############################################################################

# Эта команда будет вызваться в случае преждевременной остановки потока
measure::interop::start { finish }

# Читаем настройки программы
measure::config::read

# Инициализируем протоколирование
set log [measure::logger::init "pid"]

# Проверяем правильность настроек
validateSettings

# Запускаем дочерние модули
createChildren

set thisId [thread::id]

# Текущее значение уставки
setPoint [measure::config::get newSetPoint 0.0]

# Основной цикл регулировки
${log}::debug "starting main loop"
while { ![measure::interop::isTerminated] } {
	# отправляем команду на измерение текущей температуры
	thread::send -async $temperatureThreadId [list getTemperature $thisId setTemperature]

	# отправляем команду на установление тока питания
	thread::send -async $powerThreadId [list setCurrent [calcCurrent] $thisId currentSet]

	# ждём изменения переменной синхронизации дважды от двух источников событий
	vwait mutexVar; vwait mutexVar

#	if { $mutexVar > 100 } {
#		break
#	}
}

# Завершаем работу
measure::interop::exit

