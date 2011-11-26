# scpi.tcl --
#
#   Utilities working with SCPI devices
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.5
package provide hardware::scpi 0.1.0

namespace eval hardware::scpi {
	namespace export query setAndQuery validateIdn
}

array set hardware::scpi::commandTimes {}

# Send a command to SCPI device. Does not wait for any answer.
# Checks when previous command was sent to the same device and makes a delay if needed.
# Arguments
#   channel - device channel
#   command - command to send. Should not end with "new line" character.
#   ?delay? - delay between commands to the same device
proc hardware::scpi::cmd { channel command { delay 500 } } {
	global hardware::scpi::commandTimes

	# Check what time the prev. command was sent to the device
	if { [info exists commandTimes($channel)] } {
		set timeSpent [expr [clock milliseconds] - $commandTimes($channel)]
		if { $timeSpent < $delay } {
			after [expr int($delay - $timeSpent)]
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
proc hardware::scpi::query { channel command { delay 500 } } {
	# Save current device timeout
	set timeout [fconfigure $channel -timeout]

    # We will do 3 attempt to contact with device
    for { set attempts 3 } { $attempts > 0 } { incr attempts -1 } {
		# Make nonblocking reading
		fconfigure $channel -timeout 0

		# Read all from input buffer.
		while { [gets $channel ] != "" } {}

		# Restore the timeout
		fconfigure $channel -timeout $timeout

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
proc hardware::scpi::setAndQuery { channel command value { delay 500 } } {
	cmd $channel "$command $value" $delay
	set answer [query $channel "${command}?" $delay]
	if { $answer != $value } {
		error "`value' expected but `$answer' read when setting parameter `$command' on channel `$channel'"
	}
}

# Requests device ID by *IDN command.
# Then compares answer with given expected ID.
# Throws an exception if ID's do not match.
proc hardware::scpi::validateIdn { channel idn } {
    set ans [query $channel "*IDN?"]
    if { [string compare -nocase -length [string length $idn] $ans $idn] } {
        error "`$idn' expected but found `$ans'"
    }
}

# Sets basic SCPI-compatible settings for channel
proc hardware::scpi::configure { channel } {
    fconfigure $channel -timeout 500 -buffering line -encoding binary -translation binary
}

