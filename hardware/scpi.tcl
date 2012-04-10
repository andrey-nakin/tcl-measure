#!/usr/bin/tclsh
# scpi.tcl --
#
#   Utilities working with SCPI devices
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.5
package provide scpi 0.1.0

package require cmdline

namespace eval scpi {
	namespace export query setAndQuery validateIdn clear readError checkError
}

set scpi::ADDR_PREFIX_VISA "visa:"

set scpi::DELAY_SERIAL 50
set scpi::DELAY_DEFAULT 5

array set scpi::commandTimes {}
array set scpi::commandDelays {}
array set scpi::serialChannels {}
array set scpi::channelNames {}
set scpi::visaChannels [list]

# Opens a device and returns channel instance.
# Arguments
#   -mode mode - serial device mode
#   addr - device address
#   access - access level required
# Return
#   channel instance
proc scpi::open { args } {
	global scpi::ADDR_PREFIX_VISA 
    variable channelNames

	set opts {
		{mode.arg		""	"serial device mode"}
		{handshake.arg	""	"serial device handshake"}
		{name.arg	    ""	"arbitrary device name"}
	}

	set usage ": scpi::open \[options] addr ?access?\noptions:"
	array set options [::cmdline::getoptions args $opts $usage]

	set access rw
	lassign $args addr access

	if { [string first $ADDR_PREFIX_VISA $addr] == 0 || [isVisaAddr $addr]} {
		# this is a VISA instrument
		set channel [openVisaChannel $addr $access]
	} else {
		# open as a system device
		set channel [open $addr $access]
		# configure channel for SCPI message protocol
		configure $channel
	}

	if { [isSerialChannel $channel] } {
		# configure serial-specific options
		if { $options(mode) != "" } {
			fconfigure $channel -mode $options(mode)
		}
		if { $options(handshake) != "" } {
			fconfigure $channel -handshake $options(handshake)
		}
	}

    # store device customized names or adder for later diagnostics
    set name $options(name)
    if { $name == "" } {
        set name $addr
    }
    set channelNames($channel) $name

	return $channel
}

# Send a command to SCPI device. Does not wait for any answer.
# Checks when previous command was sent to the same device and makes a delay if needed.
# Arguments
#   channel - device channel
#   command - command to send. Should not end with "new line" character.
#   ?delay? - delay between commands to the same device
proc scpi::cmd { channel command { delay -1 } } {
	global scpi::commandTimes scpi::commandDelays scpi::DELAY_SERIAL scpi::DELAY_DEFAULT

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
	   if { [isSerialChannel $channel] } {
	       # default delay for RS-232 connection type
	       set commandDelays($channel) $DELAY_SERIAL
       } else {
	       # default delay for other connection types
	       set commandDelays($channel) $DELAY_DEFAULT
       }
    }

	# Send command to device
    if { [catch { puts $channel $command } err errInfo] } {
        error [makeChannelError $channel $err $errInfo]
    }

	# Save the time the command is sent
	set commandTimes($channel) [clock milliseconds]
}

# Issues command to SCPI device and waits for answer.
# If answer is not received during several attempts, throws an exception.
# Arguments
#   channel - device channel
#   command - command to send. Should not end with "new line" character.
#   ?delay? - delay between sending of command and reading of answer
# Return
#   Value returned by device. "Line end" character is removed from answer.
proc scpi::query { channel command { delay -1 } } {
	# Send command
	cmd $channel $command $delay

    if { $delay > 0 } {
        after $delay
    }
    
	# Read device's answer. Trailing new line char is removed by `gets`.
    if { [catch { set answer [gets $channel] } err errInfo] } {
        error [makeChannelError $channel $err $errInfo]
    }
	
	if { $answer != "" } {
		return $answer
	}

    if { [isVisaChannel $channel] } {
        lassign [visa::last-error $channel] code
        if { $code < 0 } {
            error [makeChannelError $channel $err $errInfo]
        }
    }
    
    error "Empty response for command `$command' on device `[channelName $channel]'"
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

# Requests device SCPI version and compares it to min required one
# Throws an exception if version is not available or less than required
# Arguments
#   channel - device channel
#   minVer - min version required as real number, e.g. 1994.0
proc scpi::validateScpiVersion { channel minVer } {
    set ans [query $channel "SYSTEM:VERSION?"]
    if { $ans == "" } {
        error "Cannot determine instrument version on channel $channel"
    }
    if { $ans < $minVer } {
        error "SCPI version `$ans` is less than required `$minVer` on channel $channel"
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
	set msg [string range $msg 1 [expr [string length $msg] - 1]]
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

# Determines whether a given channel represents serial port device
# Arguments
#   channel - channel to check
# Return
#   0 - channel is not a serial port device
proc scpi::isSerialChannel { channel } {
	global scpi::serialChannels

	if { [info exists serialChannels($channel)] } {
		return $serialChannels($channel)
	}

	if { ![catch {
		# try to use VISA to detect interface type
		package require tclvisa

		if { [visa::get-attribute $channel $visa::ATTR_INTF_TYPE] == $visa::INTF_ASRL } {
			set res 1
		} else {
			set res 0
		}
	} ] } {
		set serialChannels($channel) $res
		return $res
	}

	# try to read COM port mode
    if { [ catch { fconfigure $channel -mode } ] } {
        set res 0
    } else {
        set res 1
    }

	set serialChannels($channel) $res
	return $res
}

proc scpi::isVisaChannel { channel } {
    variable visaChannels
    return [expr [lsearch $visaChannels $channel] >= 0 ]
}

proc scpi::channelName { channel } {
    variable channelNames
    
    if { [info exists channelNames($channel)] } {
        return $channelNames($channel)
    } else {
        return $channel
    }
}

##############################################################################
# private
##############################################################################

proc scpi::isVisaAddr { addr } {
	set parts [split $addr "::"]
	if { [llength $parts] >= 2 } {
		set itypes { INSTR INTFC SERVANT BACKPLANE MEMACC SOCKET }
		set t [lindex $parts [llength $parts]-1]
		if { [lsearch -nocase -exact $itypes $t] < 0 } {
			return 0
		}

		set btypes { ASRL USB TCPIP "GPIB-VXI" GPIB VXI PXI }
		set t [lindex $parts 0]
		foreach bt $btypes {
			if { [regexp -nocase "^$bt\[0-9a-f\]*\$" $t] } {
				return 1
			}
		}
	}

	return 0
}

proc scpi::openVisaChannel { addr mode } {
	global scpi::ADDR_PREFIX_VISA scpi::visaResourceManager scpi::visaChannels
	global scpi::commandDelays scpi::DELAY_SERIAL scpi::DELAY_DEFAULT scpi::serialChannels

	package require tclvisa

	if { ![info exists visaResourceManager] } {
		set visaResourceManager [visa::open-default-rm]
	}

	if { [string first $ADDR_PREFIX_VISA $addr] == 0 } {
		set addr [string range $addr [string length $ADDR_PREFIX_VISA] end]
	}

	set channel [visa::open $visaResourceManager $addr $visa::EXCLUSIVE_LOCK]
	if { [visa::get-attribute $channel $visa::ATTR_INTF_TYPE] == $visa::INTF_ASRL } {
		# default delay for serial bus type
		set commandDelays($channel) $DELAY_SERIAL
		set serialChannels($channel) 1
	} else {
		# default delay for other bus types
		set commandDelays($channel) $DELAY_DEFAULT
		set serialChannels($channel) 0
	}

	lappend visaChannels $channel
	return $channel
}

proc scpi::makeChannelError { channel err { errInfo "" } } {
    if { [isVisaChannel $channel] } {
        lassign [visa::last-error $channel] num c msg
        return "Error on device `[channelName $channel]': $msg"
    } else {
        return "Error on device `[channelName $channel]': $err"
    }
}
