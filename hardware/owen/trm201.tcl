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
    array set thermoCoupleMapping { B 14 J 15 K 16 N 18 R 19 S 20 T 21 }  
}

proc ::hardware::owen::trm201::test { port addr } {
    ::owen::configure -com $port
    set res [::owen::readString $addr 0 DEV]
    if { [regexp "^...201$" $res] } {
        return 1
    }
    if { $res != "" } {
        return -1
    }
    return 0
}

proc ::hardware::owen::trm201::init { port addr } {
}

# Устанавливает тип термопары на устройстве
# Аргументы:
#   port - последовательный порт
#   addr - адрес устройства в сети RS-485
#   tcType - тип термопары (K, M и т.д.)
proc ::hardware::owen::trm201::setTcType { port addr tcType } {
    variable thermoCoupleMapping
    
    if { ![info exists thermoCoupleMapping($tcType)] } {
        error "Unsupported thermocopule type $tcType"
    }
    set tc $thermoCoupleMapping($tcType) 

    ::owen::configure -com $port
    set res [::owen::writeInt8 $addr 0 in.t 0 $tc]
    if { $res != $tc } {
        error "Cannot setup thermocouple type on TRM-201: $tc is set but $res is actually returned"
    } 
}

# Считывает температуру и возвращает значение в кельвинах вместе с инструментальной погрешностью 
# Аргументы:
#   port - последовательный порт
#   addr - адрес устройства в сети RS-485
# Результат
#    температура в К и инструментальная погрешность
proc ::hardware::owen::trm201::readTemperature { port addr } {
    ::owen::configure -com $port
    set t [::owen::readFloat24 $addr 0 PV]
    if {  $t != "" } {
        return [list [expr 273.15 + $t] [expr abs($t) * 0.005] ] 
    } else {
        return {0.0 0.0}
    } 
}
