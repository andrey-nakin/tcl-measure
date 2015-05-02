# lir916.tcl --
#
#   Work with SKB IS LIR-916 angle decoder
#   http://www.skbis.ru/index.php?p=3&c=8&d=56
#
#   Copyright (c) 2015 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide hardware::skbis::lir916 1.0.0

package require modbus

namespace eval hardware::skbis::lir916 {
  namespace export init done test readAngle
}

proc ::hardware::skbis::lir916::test { port addr } {
	set ok 0
    catch {
		set res [readAbsolute $port $addr]
        set ok [expr [llength $res] == 2]
    } 
	return $ok
}

proc ::hardware::skbis::lir916::init { port addr } {
}

proc ::hardware::skbis::lir916::done { port addr } {
}

# Считывает абсолютное значение угла
# Аргументы:
#   port - последовательный порт
#   addr - адрес устройства в сети RS-485
# Результат
#    угол в радианах
proc ::hardware::skbis::lir916::readAngle { port addr } {
	set res [readAbsolute $port $addr]
	return [expr 65536.0 * [lindex $res 0] + [lindex $res 1] ]
}

proc ::hardware::skbis::lir916::readAbsolute { port addr } {
	::modbus::configure -mode "RTU" -com $port -settings "9600,n,8,1"
	return [::modbus::cmd 0x03 $addr 0 2]
}

