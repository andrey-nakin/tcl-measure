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
	thread::send -async $tid [list init [thread::id] childInitialized]

	return $tid
}

proc childThreadError { tid errorInfo } {
    global log childFailed
    
    ${log}::error "Error $errorInfo in thread $tid"
    set childFailed 1
}

proc createChildren { } {
	global log temperatureThreadId powerThreadId validNum mutexVar childFailed

    set validNum 0
    set childFailed 0
    
    thread::errorproc childThreadError 
    
	${log}::debug "createChildren: creating temperature module"
	set temperatureThreadId [createChildThread [measure::config::get tempmodule mmtc]]

	${log}::debug "createChildren: creating power module"
	set powerThreadId [createChildThread [measure::config::get powermodule ps]]
	
	# Ожидаем завершения инициализации
	while { !$childFailed && $validNum < 2 } {
	   update
	   after 100
    }
}

proc finishChild { threadId } {
	global log

	if { [catch {
		${log}::debug "finishChild: sending `finish' to $threadId"
		thread::send -async $threadId "finish"
	} rc] } {
		${log}::error "destroyChild: error finishing thread $threadId: $rc"
	}
}

proc destroyChild { threadId } {
	global log

	if { [catch {
		${log}::debug "destroyChild: joining $threadId"
		thread::join $threadId
		${log}::debug "destroyChild: $threadId joined"
	} rc] } {
		${log}::error "destroyChild: error finishing thread $threadId: $rc"
	}
}

proc destroyChildren {} {
	global log
	
	set vars { powerThreadId temperatureThreadId }
	
	# Отправим сообщение `finish` в дочерние модули
	foreach var $vars {
	   global $var
    	if { [info exists $var] } {
    		eval "finishChild \$$var"
    	}
    }
	
	# Ожидаем завершение дочерних модулей
	foreach var $vars {
	   global $var
    	if { [info exists $var] } {
    		eval "destroyChild \$$var"
    	}
    }
	
	# выдержим паузу
	after 500
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

	if { [measure::interop::isAlone] } {
    	after 2000
    }
}

###############################################################################
# Обработчики событий
###############################################################################

# Процедура вызывается при завершении инициализации дочернего модуля
proc childInitialized { childId } {
    global log validNum
    
    ${log}::debug "childInitialized: enter childId=$childId" 

    # увеличим счётчик проинициализированных модулей
    incr validNum
}

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

	${log}::debug "currentSet: enter, c=$current, v=$voltage"

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
		${log}::debug "childError: translate error to parent module"
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
while { !$childFailed && ![measure::interop::isTerminated] } {
	# отправляем команду на измерение текущей температуры
	thread::send -async $temperatureThreadId [list getTemperature $thisId setTemperature]

	# отправляем команду на установление тока питания
	thread::send -async $powerThreadId [list setCurrent [calcCurrent] $thisId currentSet]

	# ждём изменения переменной синхронизации дважды от двух источников событий
	vwait mutexVar; vwait mutexVar

	if { $mutexVar > 40 } {
		break
	}
}

# Завершаем работу
finish

