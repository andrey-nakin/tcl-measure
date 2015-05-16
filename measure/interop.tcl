# interop.tcl --
#
#   Interthreading operations
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.5
package provide measure::interop 0.1.0

package require Thread

namespace eval measure::interop {
	namespace export \
		startWorker	\
		setVar
}

proc measure::interop::mainScriptFileName { } {
    global mainThreadId_
    
    if { [measure::interop::isAlone] } {
       set sn [info script] 
    } else {
        set sn [thread::send $mainThreadId_ { info script }]
    }
    
    return $sn
}

##############################################################################
# Procedures for main threads
##############################################################################

# Creates and runs a thread for background processing
# Arguments
#   workScript - script to run within worker thread.
#     Script cannot access any variables in parent thread.
#   ?stopScript? script to call when thread finishes.
#     Script runs in global scope.
#   ?errorProc? procedure with one argument to call when thread throws an error
# Return
#   Thread ID
proc measure::interop::startWorker { workScript { stopScript "" } { errorProc measure::interop::workerError } } {
	global log

	# create thread
	set measureThread [thread::create -joinable { 
		#rename source realsource

		proc ::source1 { f } {
			if {[catch {set fh [open $f r]; set b [read $fh]; close $fh} rc]} {
				return -code error -errorinfo $rc -errorcode $::errorCode $rc
			}
			set s [info script]
			info script $f
			if {[catch {uplevel 1 $b} rc]==1} {
				info script $s
				# the line below dumps errors in wish console
				catch {thread::send -async $mainthread [list puts $::errorInfo]}
				return -code error -errorinfo $rc -errorcode $::errorCode $rc
			}
			info script $s
			return $rc
		}

		proc notify { script { sync 0 } } {
			global log mainThreadId_

			if { $sync } {
				thread::send $mainThreadId_ $script
			} else {
				thread::send -async $mainThreadId_ $script
			}
		}

		proc interopConfig { mainThreadId workScript stopScript { errorProc "" } } {
			global workScript_ stopScript_  mainThreadId_ errorProc_

			set mainThreadId_ $mainThreadId
			set workScript_ $workScript
			set stopScript_ $stopScript
			set errorProc_ $errorProc
		}

		proc interopEnd_ {} {
			global log workScript_ stopScript_ errorProc_ finalizer_

			notify "measure::interop::doStop [thread::id] { $stopScript_ }"

    		tsv::lpop interop workers [tsv::lsearch interop workers [thread::id]]
			thread::exit
		}

		proc interopCatch_ { rc inf } {
			global log workScript_ stopScript_ errorProc_ finalizer_

			${log}::error "Error executing worker thread: $rc\n$inf"

			if { [info exists finalizer_] && $finalizer_ != "" } {
			    if { [catch { eval $finalizer_ } rc2] } {
    				${log}::error "Error executing finalizer: $rc2"
                }
            }
			
			if { $errorProc_ != "" } {
				notify "$errorProc_ {$rc}"
			}

			interopEnd_
		}

		proc interopStart {} {
			global log workScript_ stopScript_ errorProc_ finalizer_

			package require measure::logger
			# global logger to use within worker script
			set log [measure::logger::init measure::worker]

			if { [catch { uplevel 1 $workScript_ } rc inf] } {
				interopCatch_ $rc $inf
			} else {
				interopEnd_
			}
		}

		thread::wait
	}]

	tsv::set mainThread mainThread [thread::id]
	tsv::lappend interop workers $measureThread

	if {[info exists starkit::mode] && $starkit::mode ne "unwrapped"} {
        set self $starkit::topdir 
        thread::send $measureThread "vfs::mk4::Mount \"$self\" \"$self\" -readonly" 
    }
    thread::send $measureThread [list set ::auto_path $::auto_path]
	thread::send $measureThread "interopConfig [thread::id] { $workScript } { $stopScript } $errorProc"
	thread::send -async $measureThread "interopStart"

	return $measureThread
}

# Sends "stop" messages to worker threads and wait for them.
proc measure::interop::waitForWorkerThreads {} {
	global log

	terminate

	if { [tsv::exists interop workers] } {
		foreach tid [tsv::get interop workers] {
			if { [catch { thread::join $tid } rc] } {
				${log}::error "Error joining thread $tid: $rc"
			}
		}
		tsv::set interop workers [list]
	}
}

# Sends "terminate" signal to all worker threads
proc measure::interop::terminate {} {
    tsv::set interop stopped 1
}

# Clears "terminated" signal
proc measure::interop::clearTerminated {} {
    tsv::set interop stopped 0
}

proc measure::interop::createChildren { scriptFiles } {
	global log _validNum

    # Создаём дочерние потоки
    set result [list]
    foreach scriptFile $scriptFiles {
    	set tid [createChildThread $scriptFile]
    	lappend result $tid
    }     
	
	# Ожидаем завершения инициализации
    set _validNum 0
	while { $_validNum < [llength $result] } {
	   update
	   after 100
    }
    
    return $result
}

proc measure::interop::destroyChildren { } {
	global log
	variable childThreadIds

    if { ![info exists childThreadIds] } {
        return
    }
	
    thread::errorproc measure::interop::suppressedError
	
	# Отправим сообщение `finish` в дочерние модули
    foreach tid $childThreadIds {               
		if { [ catch {eval "measure::interop::finishChild \$tid"} err errInfo ] } {
    		${log}::error "error calling finishChild on $tid: $err"
        }
    }
	
	# Ожидаем завершение дочерних модулей
	set tids $childThreadIds
    foreach tid $tids {               
		if { [ catch { eval "measure::interop::destroyChild $tid" } err errInfo ] } {
    		${log}::error "error calling destroyChild on $tid: $err"
        } else {
    		::measure::listutils::lremove childThreadIds $tid
        }
    }
	
	# выдержим паузу
	after 500
}

##############################################################################
# Procedures for worker threads
##############################################################################

# Sets value of the global variable within parent thread
# Arguments:
#   varName - variable name
#   value - variable value
proc measure::interop::setVar { varName value } {
	global log mainThreadId_

	if { [info exists mainThreadId_] } {
		if { [catch { thread::send -async $mainThreadId_ "set $varName \"$value\"" } rc] } {
			${log}::error "setVar $varName $value"
		}
	}
}

# Runs a command asynchronously in the context of the main thread
# Arguments:
#   cmd - command to run
proc measure::interop::cmd { args } {
	global log mainThreadId_

	if { [info exists mainThreadId_] } {
		if { [catch { thread::send -async $mainThreadId_ {*}$args } rc] } {
			${log}::error "Error executing command `$args': $rc"
		}
	}
}

# Runs a command synchronously in the context of the main thread
# Arguments:
#   cmd - command to run
proc measure::interop::sync-cmd { args } {
	global log mainThreadId_

	if { [info exists mainThreadId_] } {
		if { [catch { thread::send $mainThreadId_ {*}$args } rc] } {
			${log}::error "Error executing command `$args': $rc"
		}
	}
}

# Checks whether this thread should terminate
# Return
#   true - terminate
proc measure::interop::isTerminated {} {
    if { [tsv::exists interop stopped] } {
        return [tsv::get interop stopped]
    } else {
        return 0
    }
}

# Checks whether this thread should terminate
# If it should, throws an error
proc measure::interop::checkTerminated {} {
    if { [isTerminated] } {
        error "Terminated by user"
    }
}

# Register script which should be called on thread error
# Arguments
#   script - script to evaluate
proc measure::interop::registerFinalization { script } {
    global finalizer_
    
    set finalizer_ [string trim $script]
}

# Sleeps given number of milliseconds or until thread is terminated
# Arguments
#   delay - number of milliseconds to sleep
proc measure::interop::sleep { delay } {
	set maxTime [expr [clock milliseconds] + int($delay)]
	
	if { $delay < 500 } {
		# exact 
		while { [clock milliseconds] < $maxTime } {
		  update
		}
	} else {
		# rough
		while { ![isTerminated] && [clock milliseconds] < $maxTime } {
		    update
			after 50
		}
	}
}

# Checks whether thread is working under a "parent"
# Return
#   true - thread is not working under a parent
proc measure::interop::isAlone {} {
	global mainThreadId_
	return [expr [info exists mainThreadId_] ? 0 : 1]
}

# Start thead work
# Arguments
#   finalizer - finalization script
proc measure::interop::start { {finalizer ""} } {
	registerFinalization $finalizer
	thread::errorproc measure::interop::criticalError
}

# Stop thread work
# If thread is "alone", stops entire application
proc measure::interop::exit {} {
    global log

	finalize

	if { [isAlone] } {
		::measure::logger::shutdown
		::exit
	}
}

# Terminates thread execution due to critical error
# Arguments
#   errorInfo - error information
proc measure::interop::criticalError { tid errorInfo } {
    global log

    ${log}::error "Error in thread $tid\n$errorInfo "

	if { [isAlone] } {
		finalize
		::measure::logger::shutdown
		::exit
	} else {
		interopCatch_ $errorInfo {}
	}
}

# Процедура вызывается при возникновении ошибки в обработчике события
# Процедура просто протоколирует ошибку без её дальнейшей обработки
proc measure::interop::suppressedError { tid errorInfo } {
    global log
    ${log}::error "Suppressed error in thread $tid\n$errorInfo "
}

##############################################################################
# Internal usage procedures
##############################################################################

proc measure::interop::doStop { threadId stopProc } {
	global log

#	if { [catch { thread::join $threadId } rc] } {
#		${log}::error "Error joining working thread: $rc"
#	}

	if { $stopProc != "" } {
		if { [catch { uplevel 1 $stopProc } rc] } {
			${log}::error "Error executing closing script: $rc"
		}
	}
}

proc measure::interop::updateWidgets { arrName } {
	global $arrName log

	array set $arrName [tsv::array get $arrName]
}

# Процедура вызывается из фонового рабочего потока при возникновении в нём ошибки
proc measure::interop::workerError { err } {
	tk_messageBox -icon error -type ok -title Message -parent . -message $err
}

proc measure::interop::finalize { } {
    global finalizer_ log

	if { [info exists finalizer_] && $finalizer_ != "" } {
		if { [catch {$finalizer_} rc] } {
			${log}::error "Error executing finalization script `$finalizer_': $rc"
		}
	}
}

# Процедура вызывается при завершении инициализации дочернего модуля
proc measure::interop::childInitialized { childId } {
    global log _validNum
    
    # увеличим счётчик проинициализированных модулей
    incr _validNum
}

proc measure::interop::createChildThread { scriptName } {
	global log mainThreadId_
	variable childThreadIds

	if { ![info exists childThreadIds] } {
	   set childThreadIds [list]
    }
	
	set tid [thread::create -joinable { 
		package require measure::logger
		set log [measure::logger::init pid::child]

		proc _start { senderId scriptFileName } {
			global log
			source $scriptFileName
		}

		proc _stop {} {
			thread::exit
		}

        proc applySettings { lst } {
            global settings
            array set settings $lst
        }

		thread::wait
	}]
	
	lappend childThreadIds $tid

    if { [info exists mainThreadId_] } {
    	thread::send $tid [list set mainThreadId_ $mainThreadId_]
    }
	thread::send -async $tid "_start [thread::id] [file join [file dirname [info script]] ${scriptName}.tcl]"
	thread::send -async $tid [list init [thread::id] ::measure::interop::childInitialized]

	return $tid
}

proc measure::interop::finishChild { threadId } {
	global log

	if { [catch {
		thread::send -async $threadId finish
		thread::send -async $threadId _stop
	} rc] } {
		${log}::error "destroyChild: error finishing thread $threadId: $rc"
	}
}

proc measure::interop::destroyChild { threadId } {
	global log

	if { [catch {
		thread::join $threadId
	} rc] } {
		${log}::error "destroyChild: error finishing thread $threadId: $rc"
	}
}
