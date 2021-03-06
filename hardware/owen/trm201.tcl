# trm201.tcl --
#
#   Work with OWEN TRM201 single-channel temperature measurer/controller
#   http://www.owen.ru/en/catalog/28533238
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide hardware::owen::trm201 0.1.0

package require owen

namespace eval hardware::owen::trm201 {
  namespace export init
  
    variable thermoCoupleMapping
    array set thermoCoupleMapping { B 14 J 15 K 16 L 17 N 18 R 19 S 20 T 21 }  
}

proc ::hardware::owen::trm201::test { port addr } {
    set desc [::owen::configure -port $port -addr $addr -settings "9600,n,8,1"]
    set res [::owen::readString $desc DEV]
    if { [regexp "^...201$" $res] } {
        return 1
    }
    if { $res != "" } {
        return -1
    }
    return 0
}

proc ::hardware::owen::trm201::init { args } {
	set usage ": test \[options] port addr \noptions:"
	set configOptions {
		{settings.arg	"9600,n,8,1"	"Baud, parity, data size, stop bits"}
		{baud.arg		""	"Baud"}
	}

	array set params [::cmdline::getoptions args $configOptions $usage]
	lassign $args port addr
	if { $params(baud) != "" } {
		set s [split $params(settings) ,]
		set params(settings) "$params(baud),[lindex $s 1],[lindex $s 2],[lindex $s 3]"
	}

    return [::owen::configure -port $port -addr $addr -settings $params(settings)]
}

proc ::hardware::owen::trm201::done { desc } {
}

# Устанавливает тип термопары на устройстве
# Аргументы:
#   port - последовательный порт
#   addr - адрес устройства в сети RS-485
#   tcType - тип термопары (K, M и т.д.)
proc ::hardware::owen::trm201::setTcType { desc tcType } {
    variable thermoCoupleMapping
    
    if { ![info exists thermoCoupleMapping($tcType)] } {
        error "Unsupported thermocopule type $tcType"
    }
    set tc $thermoCoupleMapping($tcType) 

    set res [::owen::writeInt8 $desc in.t 0 $tc]
    if { $res != $tc } {
        error "Cannot setup thermocouple type on TRM-201: '$tc' is set but '$res' is actually returned"
    } 
}

# Считывает температуру и возвращает значение в кельвинах вместе с инструментальной погрешностью 
# Аргументы:
#   port - последовательный порт
#   addr - адрес устройства в сети RS-485
# Результат
#    температура в К и инструментальная погрешность
proc ::hardware::owen::trm201::readTemperature { desc } {
    set t [::owen::readFloat24 $desc PV]
    if {  $t != "" } {
        return [list [expr 273.15 + $t] 0.1 ] 
    } else {
        set status [::owen::lastStatus]
        if { $status == $::owen::STATUS_EXCEPTION } {
            return {0.0 0.0}
        }
        error "Error reading temperature from TRM201, status $status, error [::owen::lastError]"
    } 
}
