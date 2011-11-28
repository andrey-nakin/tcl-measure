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
	namespace export \
		init	\
		done	\
		setOutput
}

set hardware::agilent::pse3645a::IDN "Agilent Technologies,E3645A"
 
# Производит инициализацию и опрос устройства.
# Также переводит устройство в режим дистанционного управления.
# Аргументы
#   channel - канал с открытым портом для связи с устройством
proc hardware::agilent::pse3645a::init { channel } {
    global hardware::agilent::pse3645a::IDN

    # устанавливаем параметры канала
    hardware::scpi::configure $channel
    
    hardware::scpi::cmd $channel "*CLS"

    hardware::scpi::cmd $channel "*RST"
    
    hardware::scpi::cmd $channel "SYSTEM:REMOTE"

    # производим опрос устройства
	hardware::scpi::validateIdn $channel $IDN
	
	# отключаем выход ИП
	setOutput $channel 0
}

# Также переводит устройство в режим ручного управления.
# Аргументы
#   channel - канал с открытым портом для связи с устройством
proc hardware::agilent::pse3645a::done { channel } {
    hardware::scpi::cmd $channel "*CLS"

    hardware::scpi::cmd $channel "*RST"

    hardware::scpi::cmd $channel "SYSTEM:LOCAL"
}

# Включает/выключает выход ИП
# Аргументы
#   channel - канал устройства
#   on - true/false
proc hardware::agilent::pse3645a::setOutput { channel on } {
    set mode [expr $on ? "ON" : "OFF"]
    hardware::scpi::cmd $channel "OUTPUT $mode"

    set ans [hardware::scpi::query $channel "OUTPUT?"]
    set ans [expr $ans ? "ON" : "OFF"]
    if { $ans != $mode } {
        error "Error setting power supply output to $mode"
    }
}

