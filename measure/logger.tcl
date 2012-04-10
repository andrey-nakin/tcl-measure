# logger.tcl --
#
#   Wrapper for standard logger package
#   Can be used in mutlithreading environment
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::logger 0.1.0

package require logger
package require Thread

namespace eval ::measure::logger {
  namespace export init	server shutdown
}

# Use this procedure in place of logger::init with the same semantics
# Arguments
#   service - logging service name (see documentation to logger::init procedure)
proc ::measure::logger::init { service } {
	set log [logger::init $service]

	foreach lvl [logger::levels] {
		interp alias {} log_to_file_$lvl {} ::measure::logger::log $lvl $service
		${log}::logproc $lvl log_to_file_$lvl
	}

	return $log
}

# Starts and configures logging thread.
# Call this procedure once at the application startup.
# Arguments
#   ?logfile? - name of the disk file to write log into.
proc ::measure::logger::server { {logfile "measure.log"} } {
	set t [thread::create -joinable {

		proc setLogFile { fn } {
			global logfile
			set logfile $fn
		}

		proc stop {} {
			thread::exit
		}

		proc log { level txt } {
			global logfile
			set msg "\[[clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]\]\t$level\t$txt"
			if { [string length $logfile] } {
				set f [open $logfile {WRONLY CREAT APPEND}] ;# instead of "a"
				fconfigure $f -encoding utf-8
				puts $f $msg
				close $f
			}
			catch {puts stderr $msg}
		}

		# enter to event loop
		thread::wait
	}]

	thread::send $t [list setLogFile $logfile]
	tsv::set measure-logger loggerThread $t
}

proc ::measure::logger::shutdown { } {
	if { [tsv::exists measure-logger loggerThread] } {
		global log

		if { [info exists log] } {
			#${log}::debug "Shutting log server down"
		}

		set tid [tsv::get measure-logger loggerThread]
		thread::send -async $tid stop
		thread::join $tid
		tsv::unset measure-logger loggerThread
	}
}

# INTERNAL PROCEDURES

proc ::measure::logger::log { level service txt } {
    if { ![tsv::exists measure-logger loggerThread] } {
        server
    }
	set t [tsv::get measure-logger loggerThread]
	thread::send -async $t [list log $level "$service\t$txt"]
}

