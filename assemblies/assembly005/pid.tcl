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
array set pidState [list lastError 0.0 lastResult 0.0 setPoint 0.0]

set lastTime ""

###############################################################################
# Подпрограммы
###############################################################################

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]

proc createChildThread { scriptName } {
	global log

	${log}::debug "createChildThread: creating thread for script `$scriptName'"
	set tid [thread::create -joinable { 
		package require measure::logger
		set log [measure::logger::init pid::child]

		proc _start { senderId scriptFileName } {
			global log

			${log}::debug "createChildThread: starting child [thread::id] from script file $scriptFileName"
			if { [catch { source $scriptFileName } rc] } {
				${log}::error "Error executing child thread [thread::id]: $rc"
				
			    if { [catch { finish } rc2] } {
    				${log}::error "Error executing finalizer for thread [thread::id]: $rc2"
                }

				${log}::debug "createChildThread: notifying parent about error in thread [thread::id]"
				thread::send -async $senderId "childError [thread::id] { $rc }"
			}

			${log}::debug "createChildThread: exiting child [thread::id]"
			thread::exit
		}

		thread::wait
	}]

	${log}::debug "createChildThread: sending `start' to thread $tid"
	thread::send -async $tid "_start [thread::id] [file join [file dirname [info script]] ${scriptName}.tcl]"
	thread::send -async $tid init

	return $tid
}

proc createChildren { } {
	global log temperatureThreadId powerThreadId

	${log}::debug "createChildren: creating temperature module"
	set temperatureThreadId [createChildThread [measure::config::get tempmodule mmtc]]

	${log}::debug "createChildren: creating power module"
	set powerThreadId [createChildThread [measure::config::get powermodule ps]]
}

proc destroyChild { threadId } {
	global log

	if { [catch {
		${log}::debug "destroyChild: sending `finish' to $threadId"
		thread::send -async $threadId "finish"

		${log}::debug "destroyChildren: joining $threadId"
		thread::join $threadId
	} rc] } {
		${log}::error "destroyChild: error finishing thread $threadId: $rc"
	}
}

proc destroyChildren {} {
	global temperatureThreadId log powerThreadId
	
	if { [info exists powerThreadId] } {
		${log}::debug "destroyChildren: destroying power module $powerThreadId"
		destroyChild $powerThreadId
	}

	if { [info exists temperatureThreadId] } {
		${log}::debug "destroyChildren: destroying temperature module $temperatureThreadId"
		destroyChild $temperatureThreadId
	}
}

# процедура, реализующая алгоритм ПИД
proc pidCalc { dt } {
	global pidState settings

	if { ![info exists pidState(currentTemperature)] || ![info exists pidState(setPoint)] } {
		return 0.0
	}

	# текущее значение невязки	
	set err [expr $pidState(setPoint) - $pidState(currentTemperature)]

	set result [expr $settings(pid.tp) * $err]

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
		
		# проверим правильность тока
		if { $result < 0.0 } {
			set result 0.0
		}
		if { [info exists settings(pid.maxCurrent)] && $settings(pid.maxCurrent) > 0 && $result > $settings(pid.maxCurrent) } {
			set result $settings(pid.maxCurrent)
		}
	} else {
		# это первое измерение
		set result 0.0
	}

	set lastTime $curTime

	return $result
}

proc finish {} {
	global log

	# закрываем дочерние модули
	destroyChildren

	after 2000
}

###############################################################################
# Обработчики событий
###############################################################################

# Процедура вызывается модулем измерения температуры
proc setTemperature { t tErr } {
	global mutexVar pidState log

	${log}::debug "setTemperature: enter {$t $tErr}"

	set pidState(currentTemperature) $t

	# Изменяем значение переменной синхронизации для остановки ожидания
	incr mutexVar
}

# Процедура вызывается модулем регулировки тока питания печки
proc currentSet { current voltage } {
	global mutexVar log

	${log}::debug "currentSet: enter"

	# Изменяем значение переменной синхронизации для остановки ожидания
	incr mutexVar
}

# Процедуры вызывается при возникновении ошибки в дочернем модуле
proc childError { childId err } {
	global log

	${log}::debug "childError: entering from child $childId by error $err"

	if { [measure::interop::isAlone] } {
		${log}::debug "childError: finishing module"
		if { [catch { finish } rc] } {
			${log}::error "childError: error finishing module: $rc"
		}
		exit
	} else {
		${log}::debug "childError: trasnlate error to parent module"
		error $err
	}
}

# Процедура изменяет значение уставки
proc setPoint { t } {
	global pidState

	set pidState(setPoint) $t
}

###############################################################################
# Начало работы
###############################################################################

# Эта команда будет вызваться в случае преждевременной остановки потока
measure::interop::registerFinalization { finish }

# Читаем настройки программы
measure::config::read

# Инициализируем протоколирование
set log [measure::logger::init "pid"]

# Проверяем правильность настроек
validateSettings

# Запускаем дочерние модули
createChildren

set thisId [thread::id]

# имитация уставки
setPoint 300.0

# Основной цикл регулировки
${log}::debug "starting main loop"
while { ![measure::interop::isTerminated] } {
	# отправляем команду на измерение текущей температуры
	${log}::debug "requesting temperature"
	thread::send -async $temperatureThreadId [list getTemperature $thisId setTemperature]

	# отправляем команду на установление тока питания
	${log}::debug "setting current"
	thread::send -async $powerThreadId [list setCurrent [calcCurrent] $thisId currentSet]

	# ждём изменения переменной синхронизации дважды от двух источников событий
	${log}::debug "wait for answers"
	vwait mutexVar; vwait mutexVar
}

# Завершаем работу
finish

