# pse3645a.tcl --
#
#   Work with Agilent E3645A power supply
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide hardware::agilent::pse3645a 0.1.0

package require hardware::scpi

namespace eval hardware::agilent::pse3645a {
#  namespace export resistanceSystematicError dcvSystematicError dciSystematicError
}

set hardware::agilent::pse3645a::IDN "Agilent Technologies,E3645A"
 
# Производит инициализацию и опрос устройства
# Аргументы
#   channel - канал с открытым портом для связи с устройством
proc hardware::agilent::pse3645a::init { channel } {
    global hardware::agilent::pse3645a::IDN

    # устанавливаем параметры канала
    hardware::scpi::configure $channel
    
    # производим опрос устройства
	hardware::scpi::validateIdn $channel $IDN
    
    puts $channel "*CLS"
    after 500
    puts $channel "*RST"
    after 500
}

# Включает/выключает выход ИП
# Аргументы
#   channel - канал устройства
#   on - true/false
proc hardware::agilent::pse3645a::setOutput { channel on } {
    set mode [expr $on ? "ON" : "OFF"]
    puts $channel "OUTPUT $mode"
    after 500
    set ans [hardware::scpi::query $channel "OUTPUT?"]
    set ans [expr $ans ? "ON" : "OFF"]
    if { $ans != $mode } {
        error "Error setting power supply output to $mode"
    }
    #after 500
}
