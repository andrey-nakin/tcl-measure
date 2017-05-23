# lir916.tcl --
#
#   Work with SKB IS LIR-916 angle decoder
#   12 bit precision is hardcoded
#   http://www.skbis.ru/index.php?p=3&c=8&d=56
#
#   Copyright (c) 2015 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package provide hardware::skbis::lir916 1.0.0

namespace eval hardware::skbis::lir916 {
  namespace export init done test readAngle setZero setCoeff
}

package require Tcl 8.5
package require modbus
package require cmdline
package require Thread

set ::hardware::skbis::lir916::PI 3.1415926535897932384626433832795
set ::hardware::skbis::lir916::ERROR [expr $::hardware::skbis::lir916::PI / 0x1000]
set ::hardware::skbis::lir916::TO_RADIANS [expr 2.0 * $::hardware::skbis::lir916::PI / 0x1000]

proc ::hardware::skbis::lir916::test { args } {
	set ok 0
    catch {
		set desc [init {*}$args]
		set res [readAbsolute $desc]
        set ok [expr [llength $res] >= 2]
    } 
	return $ok
}

proc ::hardware::skbis::lir916::init { args } {
	set configOptions {
		{com.arg		"/dev/ttyUSB0"	"Serial port"}
		{addr.arg		"1"	"RS-485 address"}
		{settings.arg	"9600,n,8,1"	"Baud, parity, data size, stop bits"}
		{baud.arg		""	"Baud"}
		{zero.arg		0	"Zero position"}
		{coeff.arg		1.0	"Multiplicator"}
	}
	set usage ": init \[options]\noptions:"

	array set params [::cmdline::getoptions args $configOptions $usage]
	if { $params(baud) != "" } {
		set s [split $params(settings) ,]
		set params(settings) "$params(baud),[lindex $s 1],[lindex $s 2],[lindex $s 3]"
	}

	set desc [list $params(com) $params(settings) $params(addr) $params(coeff)]
	tsv::set lir16zero [channelId $desc] $params(zero)
	tsv::set lir16coeff [channelId $desc] $params(coeff)
	return $desc
}

proc ::hardware::skbis::lir916::done { desc } {
}

# Устанавливает последнее считанное значение за нулевую отметку
# Аргументы:
#   addr - адрес устройства (не дескриптор!)
# Результат
#    Значение нулевой отметки
proc ::hardware::skbis::lir916::setZero { addr } {
	set key "channel_$addr"
	if { [tsv::get lir16value $key zero] } {
		tsv::set lir16zero $key $zero
	} else {
		error "No measurements on device with address #$addr"
	}
	return $zero
}

# Set new angle recalculation coeff
# Arguments:
#   addr - device address (not descriptor!)
#   coeff - new coefficient
proc ::hardware::skbis::lir916::setCoeff { addr coeff } {
	set key "channel_$addr"
	tsv::set lir16coeff $key $coeff
}

# Read relative angle from device
# Arguments:
#   desc - device descriptor
#   ?noCoeff? - if true, do not recalc angle
# Result
#    angle and absolute error in radians
proc ::hardware::skbis::lir916::readAngle { desc { noCoeff 0 } } {
  global log

	variable TO_RADIANS
	variable ERROR
	
	# read digital angle
	lassign [readAbsolute $desc] hi lo
	set v [expr ($hi << 16) + ($lo & 0xFFFF)]

	# store last read value for later use
	set key [channelId $desc]
	tsv::set lir16value $key $v

	# shift  value to zero position if any
	if { [tsv::get lir16zero $key z] } {
		set v [expr $v - $z]
	}

	# convert 32-bit integer value to angle in radians
	if { $noCoeff } {
		return [list [expr $v * $TO_RADIANS] $ERROR]
	} else {
		set coeff [tsv::get lir16coeff $key]
		return [list [expr $v * $TO_RADIANS * $coeff] [expr $ERROR * $coeff] ]
	}
}

####### private procedures

proc ::hardware::skbis::lir916::readAbsolute { desc } {
	global log
	global ::modbus::LAST_RESPONSE
# for debug purposes
#	set v [expr int([clock milliseconds] / 10)]
#	return [list [expr ($v >> 16) && 0xFF] [expr $v & 0xFFFF] ]
#	

	# repeat several times until data are successfully read
	for { set attempts 0 } { $attempts < 3 } { incr attempts } {
		::modbus::configure -mode "RTU" -com [lindex $desc 0] -settings [lindex $desc 1]
		set res [::modbus::cmd 0x03 [lindex $desc 2] 0 2]
		if { $res != "" && [llength $res] >= 2 } {
			# successful attempt
			break
		}
	}

	if { $res == "" || [llength $res] < 2 } {
		${log}::error "Bad response from LIR-916: $res, desc=$desc, LAST_RESPONSE=$LAST_RESPONSE ([llength $LAST_RESPONSE])"
		error "No response from LIR-916"
	}

	return $res
}

proc ::hardware::skbis::lir916::channelId { desc } {
	return "channel_[lindex $desc 2]"
}

