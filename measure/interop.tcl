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
		package require measure::logger

		# global logger to use within worker script
		set log [measure::logger::init measure::worker]

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

		proc interopCatch_ { rc } {
			global log workScript_ stopScript_ errorProc_ finalizer_

			${log}::error "Error executing worker thread: $rc"

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

			if { [catch { uplevel 1 $workScript_ } rc] } {
				interopCatch_ $rc
			} else {
				interopEnd_
			}
		}

		thread::wait
	}]

	tsv::lappend interop workers $measureThread

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

# Sends "terminate" signal to all child threads
proc measure::interop::terminate {} {
    tsv::set interop stopped 1
}

# Clears "terminated" signal
proc measure::interop::clearTerminated {} {
    tsv::set interop stopped 0
}

##############################################################################
# Procedures for child threads
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
	while { ![isTerminated] && [clock milliseconds] < $maxTime } {
		after 50
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
		interopCatch_ $errorInfo
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
		${log}::debug "Executing finalization script `$finalizer_'"
		if { [catch {$finalizer_} rc] } {
			${log}::error "Error executing finalization script `$finalizer_': $rc"
		}
	}
}

