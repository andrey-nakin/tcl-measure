# interop.tcl --
#
#   Interthreading operations
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::interop 0.1.0

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

		proc interopConfig { mainThreadId workScript stopScript errorProc } {
			global workScript_ stopScript_  mainThreadId_ errorProc_

			set mainThreadId_ $mainThreadId
			set workScript_ $workScript
			set stopScript_ $stopScript
			set errorProc_ $errorProc
		}

		proc interopStart {} {
			global log workScript_ stopScript_ errorProc_ finalizer_

			if { [catch { uplevel 1 $workScript_ } rc] } {
				${log}::error "Error executing worker thread: $rc"
				
				if { [info exists finalizer_] && $finalizer_ != "" } {
				    if { [catch { eval $finalizer_ } rc2] } {
        				${log}::error "Error executing finalizer: $rc2"
                    }
                }
				
				notify "$errorProc_ {$rc}"
			}

			notify "measure::interop::doStop [thread::id] { $stopScript_ }"

			thread::exit
		}

		thread::wait
	}]

	tsv::lappend interop workers $measureThread

	thread::send $measureThread "interopConfig [thread::id] { $workScript } { $stopScript } $errorProc"
	thread::send -async $measureThread "interopStart"
}

# Sends "stop" messages to worker threads and wait for them.
proc measure::interop::waitForWorkerThreads {} {
	global log

	if { [tsv::exists interop workers] } {
		foreach tid [tsv::get interop workers] {
			if { [catch { thread::join $tid } rc] } {
				${log}::error "Error joining thread $tid: $rc"
			}
		}
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

# Checks whether this thread should terminate
# Return
#   true - terminate
proc measure::interop::isTerminated {} {
    return [tsv::get interop stopped]
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
    
    set finalizer_ $script
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

