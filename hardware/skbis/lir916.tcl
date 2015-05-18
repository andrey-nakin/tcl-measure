# lir916.tcl --
#
#   Work with SKB IS LIR-916 angle decoder
#   12 bit precision is hardcoded
#   http://www.skbis.ru/index.php?p=3&c=8&d=56
#
#   Copyright (c) 2015 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide hardware::skbis::lir916 1.0.0

package require modbus
package require cmdline
package require Thread

namespace eval hardware::skbis::lir916 {
  namespace export init done test readAngle setZero
}

set ::hardware::skbis::lir916::configOptions {
	{com.arg		"/dev/ttyUSB0"	"Serial port"}
	{addr.arg		"1"	"RS-485 address"}
	{settings.arg	"9600,n,8,1"	"Baud, parity, data size, stop bits"}
	{baud.arg		""	"Baud"}
	{zero.arg		0	"Zero position"}
	{coeff.arg		1.0	"Multiplicator"}
}

set ::hardware::skbis::lir916::usage ": test \[options] port addr \noptions:"
set ::hardware::skbis::lir916::PI 3.1415926535897932384626433832795
set ::hardware::skbis::lir916::ERROR [expr $::hardware::skbis::lir916::PI / 0x1000]
set ::hardware::skbis::lir916::TO_RADIANS [expr 2.0 * $::hardware::skbis::lir916::PI / 0x1000]

proc ::hardware::skbis::lir916::test { args } {
	variable configOptions
	variable usage

	array set params [::cmdline::getoptions args $configOptions $usage]

	set settings $params(settings)
	if { $params(baud) } {
		set s [split $params(settings) ,]
		set params(settings) "$params(baud),[lindex $s 1],[lindex $s 2],[lindex $s 3]"
	}

	set ok 0
    catch {
		set res [readAbsolute $settings(com) $settings(addr)]
        set ok [expr [llength $res] >= 2]
    } 
	return $ok
}

proc ::hardware::skbis::lir916::init { args } {
	variable configOptions
	variable usage

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
		error "No measurements on device #$addr"
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
	variable TO_RADIANS
	variable ERROR
	
	# read digital angle
	lassign [readAbsolute $desc] hi lo
	set v [expr ($hi << 16) + $lo]

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

array set ::hardware::skbis::lir916::sampleData {}
proc ::hardware::skbis::lir916::readAbsolute { desc } {
#!!!
	variable sampleData
	set key "channel_[lindex $desc 2]"
	if { ![info exists sampleData($key)] } {
		set sampleData($key) 0
	}
	incr sampleData($key) [expr int(rand() * [lindex $desc 2])]
	return [list [expr $sampleData($key) >> 16] [expr $sampleData($key) & 0xFFFF] ]
#!!!	

	::modbus::configure -mode "RTU" -com [lindex $desc 0] -settings [lindex $desc 1]
	return [::modbus::cmd 0x03 [lindex $desc 2] 0 2]
}

proc ::hardware::skbis::lir916::channelId { desc } {
	return "channel_[lindex $desc 2]"
}

