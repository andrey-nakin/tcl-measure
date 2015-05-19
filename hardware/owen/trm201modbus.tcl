# trm201modbus.tcl --
#
#   Work with OWEN TRM201 single-channel temperature measurer/controller via Modbus-RTU protocol
#   http://www.owen.ru/en/catalog/28533238
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide hardware::owen::trm201::modbus 1.0.0

package require modbus

namespace eval hardware::owen::trm201::modbus {
	namespace export init
  
	variable thermoCoupleMapping
	array set thermoCoupleMapping { B 14 J 15 K 16 L 17 N 18 R 19 S 20 T 21 }  
}

proc ::hardware::owen::trm201::modbus::test { args } {
    set desc [init {*}$args]
	if {[catch {readTemperature $desc}]} {
		return 0
	}
	return 1
}

proc ::hardware::owen::trm201::modbus::init { args } {
	set configOptions {
		{com.arg		"/dev/ttyUSB0"	"Serial port"}
		{addr.arg		"1"	"RS-485 address"}
		{settings.arg	"9600,n,8,1"	"Baud, parity, data size, stop bits"}
		{baud.arg		""	"Baud"}
	}
	set usage ": init \[options]\noptions:"

	array set params [::cmdline::getoptions args $configOptions $usage]
	if { $params(baud) != "" } {
		set s [split $params(settings) ,]
		set params(settings) "$params(baud),[lindex $s 1],[lindex $s 2],[lindex $s 3]"
	}

	set desc [list $params(com) $params(settings) $params(addr)]
	return $desc
}

proc ::hardware::owen::trm201::modbus::done { desc } {
}

# Считывает температуру и возвращает значение в кельвинах вместе с инструментальной погрешностью 
# Аргументы:
#   desc - дескриптор
# Результат
#    температура в К и инструментальная погрешность
#array set ::hardware::owen::trm201::modbus::sampleData {}
proc ::hardware::owen::trm201::modbus::readTemperature { desc } {
#!!!
#	variable sampleData
#	set key "channel_[lindex $desc 2]"
#	if { ![info exists sampleData($key)] } {
#		set sampleData($key) 0
#	}
#	incr sampleData($key) [expr int(rand() * [lindex $desc 2])]
#	return [list [expr 293.0 + 0.1 * $sampleData($key)] 0.1 ]
#!!!	

	::modbus::configure -mode "RTU" -com [lindex $desc 0] -settings [lindex $desc 1]
	set v [::modbus::cmd 0x03 [lindex $desc 2] 0x1009 2]
	if { [llength $v] < 2 } {
        error "Error reading temperature from TRM-201"
	}
	set s [binary format SS [lindex $v 0] [lindex $v 1] ]
	binary scan [string reverse $s] f t
    return [list [expr 273.15 + $t] 0.1] 
}

