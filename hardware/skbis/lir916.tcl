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

namespace eval hardware::skbis::lir916 {
  namespace export init done test readAngle
}

set ::hardware::skbis::lir916::configOptions {
	{com.arg		"/dev/ttyUSB0"	"Serial port"}
	{addr.arg		"1"	"RS-485 address"}
	{settings.arg	"9600,n,8,1"	"Baud, parity, data size, stop bits"}
	{baud.arg		""	"Baud"}
}

set ::hardware::skbis::lir916::usage ": test \[options] port addr \noptions:"

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

	return [list $params(com) $params(settings) $params(addr) 0 0]
}

proc ::hardware::skbis::lir916::done { desc } {
}

# Считывает абсолютное значение угла
# Аргументы:
#   port - последовательный порт
#   addr - адрес устройства в сети RS-485
# Результат
#    угол и абсолютная погрешность в радианах
proc ::hardware::skbis::lir916::readAngle { desc } {
# !!!
	if { [lindex $desc 2] == 100 } {
		global PHI1
		if { ![info exists PHI1] } { set PHI1 0 }
		set PHI1 [expr $PHI1 + 0.002 * rand() - 0.00075]
		return [list $PHI1 [expr $PHI1 * 0.0001] ]
	}
	if { [lindex $desc 2] == 200 } {
		global PHI2
		if { ![info exists PHI2] } { set PHI2 0 }
		set PHI2 [expr $PHI2 + 0.004 * rand() - 0.00150]
		return [list $PHI2 [expr $PHI2 * 0.0001] ]
	}
# !!!

	set pi 3.1415926535897932384626433832795
	set res [readAbsolute $desc]
	set hi [expr [lindex $res 0] - [lindex $desc 4] ]
	set lo [expr [lindex $res 1] - [lindex $desc 3] ]
	set counter [expr (($hi & 0xFF) << 4) + (($lo >> 12) & 0xF) ]
	set angle [expr ($lo & 0xFFF) * 2.0 * $pi / 0x1000 ]
	return [list [expr $angle + 2.0 * $pi * $counter] [expr $pi / 0x1000] ]
}

proc ::hardware::skbis::lir916::readAbsolute { desc } {
	::modbus::configure -mode "RTU" -com [lindex $desc 0] -settings [lindex $desc 1]
	return [::modbus::cmd 0x03 [lindex $desc 2] 0 2]
}

