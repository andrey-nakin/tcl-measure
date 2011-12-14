# scpi.tcl --
#
#   Utilities working with SCPI devices
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.5
package provide hardware::scpi 0.1.0

namespace eval scpi {
	namespace export query setAndQuery validateIdn clear readError checkError
}

array set scpi::commandTimes {}
array set scpi::commandDelays {}

# Send a command to SCPI device. Does not wait for any answer.
# Checks when previous command was sent to the same device and makes a delay if needed.
# Arguments
#   channel - device channel
#   command - command to send. Should not end with "new line" character.
#   ?delay? - delay between commands to the same device
proc scpi::cmd { channel command { delay -1 } } {
	global scpi::commandTimes scpi::commandDelays

	# Check what time the prev. command was sent to the device
	if { [info exists commandTimes($channel)] } {
		set timeSpent [expr [clock milliseconds] - $commandTimes($channel)]
		if { $delay < 0 } {
    		set delay $commandDelays($channel) 
        }
		if { $timeSpent < $delay } {
			after [expr int($delay - $timeSpent)]
		}
	} else {
	   # determine delay for this channel
	   if { [isRs232 $channel] } {
	       # default delay for RS-232 connection type
	       set commandDelays($channel) 500 
       } else {
	       # default delay for other connection types
	       set commandDelays($channel) 50 
       }
    }

	# Send command to device
	puts $channel $command

	# Save the time the command is sent
	set commandTimes($channel) [clock milliseconds]
}

# Issues command to SCPI device and waits for answer.
# If answer is not received during several attempts, throws an exception.
# Arguments
#   channel - device channel
#   command - command to send. Should not end with "new line" character.
#   ?delay? - delay between command and query
# Return
#   Value returned by device. "Line end" character is removed from answer.
proc scpi::query { channel command { delay -1 } } {
    # We will do 3 attempt to contact with device
    for { set attempts 3 } { $attempts > 0 } { incr attempts -1 } {
		# Send command
		cmd $channel $command $delay

		# Read device's answer. Trailing new line char is removed by `gets`.
		set answer [gets $channel]
		if { $answer != "" } {
			return $answer
		}
    }

    error "Error quering `$command' on channel `$channel'"
}

# Sets some attribute to device, 
# then queries value to check whether it is really set. If values are not equal,
# throws exception.
# Arguments
#   channel - device channel
#   command - command to send. Should not end with "new line" character.
#   value - command argument
#   ?delay? - delay between command and query
proc scpi::setAndQuery { channel command value { delay -1 } } {
	cmd $channel "$command $value" $delay
	set answer [query $channel "${command}?" $delay]
	if { $answer != $value } {
		error "`value' expected but `$answer' read when setting parameter `$command' on channel `$channel'"
	}
}

# Requests device ID by *IDN command.
# Then compares answer with given expected ID.
# Throws an exception if ID's do not match.
# Arguments
#   channel - device channel
#   idn - expected device ID
proc scpi::validateIdn { channel idn } {
    set ans [query $channel "*IDN?"]
    if { [string compare -nocase -length [string length $idn] $ans $idn] } {
        error "`$idn' expected but found `$ans'"
    }
}

# Sets basic SCPI-compatible settings for channel
# Arguments
#   channel - device channel
proc scpi::configure { channel } {
    fconfigure $channel -timeout 3000 -buffering line -encoding binary -translation binary
}

# Clears device output buffer
# Arguments
#   channel - device channel
proc scpi::clear { channel } {
	# Save current device timeout
	set timeout [fconfigure $channel -timeout]

	# Make nonblocking reading
	fconfigure $channel -timeout 0

	# Read all from input buffer.
	while { [gets $channel ] != "" } {}

	# Restore the timeout
	fconfigure $channel -timeout $timeout
}

# Reads and parses first error from queue
# Arguments
#   channel - device channel
# Return
#   error code and message pair
proc scpi::readError { channel } {
	lassign [split [query $channel "SYSTEM:ERROR?"] ","] code msg
	set msg [string range $msg 1 [expr [string length $range] - 1]]
	return [list $code $msg]
}

# Checks whether device indicates an error
# If it does, throws error
# Arguments
#   channel - device channel
proc scpi::checkError { channel } {
	lassign [readError $channel] code msg
	if { $code != 0 } {
		error "Error ${code} on SCPI channel $channel: $msg"
	}
}

proc isRs232 { channel } {
    if { [ catch { fconfigure $channel -mode } ] } {
        return 0
    } else {
        return 1
    }
}

