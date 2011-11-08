# parallel.tcl --
#
#   Blocks of two or more scripts which are executed in different threads
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::parallel 0.1.0

package require Thread
package require measure::logger

namespace eval measure::parallel {
  namespace export parallel
}

# Runs code blocks in parallel threads
# Arguments (any number)
#   code blocks to execute
proc measure::parallel { args } {
	global measure::parallel::log

	if { ![info exists log] } {
		set log [measure::logger::init "measure::parallel"]
	}

	if { [llength $args] } {
		set threadIds [list]

		foreach script $args {
			set s {
				package require measure::logger
				set log [measure::logger::init "measure::parallel"]
				if { [catch { @ } rc] } {
					${log}::error "in thread [thread::id]: $rc"
				}
			}
			set i [string first "@" $s]
			set s "[string range $s 0 [expr $i - 1]]$script[string range $s [expr $i + 1] [string length $s]]"
			set t [thread::create -joinable $s]
			${log}::debug "created thead $t"
			lappend threadIds $t
		}

		foreach threadId $threadIds {
			thread::join $threadId
			${log}::debug "joined thead $threadId"
		}
	}
}

