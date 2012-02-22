#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 004
# Процедуры общего назначения
###############################################################################

# Процедура проверяет правильность настроек, при необходимости вносит поправки
proc validateSettings {} {
    global settings

	# Число циклов питания на одно измерение напряжения
	if { ![info exists settings(mmtc.mm.nplc)] || !$settings(mmtc.mm.nplc) || $settings(mmtc.mm.nplc) < 0 } {
		# Если не указано в настройках, по умолчанию равно 10
		set settings(mmtc.mm.nplc) 10
	}
}

# Процедура возвращает список всех температурных схем, 
# обнаруженных в текущей директории
proc tschemeNames {} {
	set files [glob "./*.tsc"]
	set result [list]
	foreach f $files {
		set f [file tail $f]
		set ext [file extension $f]
		lappend result [string range $f 0 end-[string length $ext]]
	}
	return $result
}

proc createChildThread { scriptName } {
	global log

	${log}::debug "createChildThread: creating thread for script `$scriptName'"
	set tid [thread::create -joinable { 
		package require measure::logger
		set log [measure::logger::init pid::child]

		proc _start { senderId scriptFileName } {
			global log

			${log}::debug "createChildThread: starting child [thread::id] from script file $scriptFileName"
			source $scriptFileName
		}

		proc _stop {} {
			thread::exit
		}

		thread::wait
	}]

	${log}::debug "createChildThread: sending `start' to thread $tid"
	thread::send -async $tid "_start [thread::id] [file join [file dirname [info script]] ${scriptName}.tcl]"
	${log}::debug "createChildThread: sending `init' to thread $tid"
	thread::send -async $tid [list init [thread::id] childInitialized]

	return $tid
}

proc createChildren { } {
	global log temperatureThreadId powerThreadId validNum mutexVar

    set validNum 0
    
	${log}::debug "createChildren: enter, this thread id = [thread::id]"
    
	${log}::debug "createChildren: creating temperature module"
	set temperatureThreadId [createChildThread [measure::config::get tempmodule mmtc]]

	${log}::debug "createChildren: creating power module"
	set powerThreadId [createChildThread [measure::config::get powermodule ps]]
	
	# Ожидаем завершения инициализации
	while { $validNum < 2 } {
	   update
	   after 100
    }
}

proc finishChild { threadId } {
	global log

	if { [catch {
		${log}::debug "finishChild: sending `finish' to $threadId"
		thread::send -async $threadId finish
		${log}::debug "finishChild: sending `_stop' to $threadId"
		thread::send -async $threadId _stop
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
    thread::errorproc measure::interop::suppressedError
	
	# Отправим сообщение `finish` в дочерние модули
	foreach var $vars {
	   global $var
    	if { [info exists $var] } {
    		eval "finishChild \$$var"
    	}
    }
	
	# Ожидаем завершение дочерних модулей
	foreach var $vars {
    	if { [info exists $var] } {
    		eval "destroyChild \$$var"
    	}
    }
	
	# выдержим паузу
	after 500
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

