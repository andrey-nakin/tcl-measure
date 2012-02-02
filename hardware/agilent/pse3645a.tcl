# pse3645a.tcl --
#
#   Work with Agilent E3645A power supply
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide hardware::agilent::pse3645a 0.1.0

package require scpi
package require hardware::agilent::utils

namespace eval hardware::agilent::pse3645a {
	namespace export \
		init	\
		done	\
		setOutput
}

set hardware::agilent::pse3645a::IDN "Agilent Technologies,E3645A"

set hardware::agilent::pse3645a::MAX_CURRENT_LOW_VOLTAGE 2.2
set hardware::agilent::pse3645a::MAX_CURRENT_HIGH_VOLTAGE 1.3

# Производит открытие устройства
proc hardware::agilent::pse3645a::open { args } {
	return [hardware::agilent::utils::open "n" {*}$args]
}
 
# Производит инициализацию и опрос устройства.
# Также переводит устройство в режим дистанционного управления.
# Аргументы
#   channel - канал с открытым портом для связи с устройством
proc hardware::agilent::pse3645a::init { channel } {
    global hardware::agilent::pse3645a::IDN

    # очищаем выходной буфер
	scpi::clear $channel

    # производим опрос устройства
	scpi::validateIdn $channel $IDN

	# в исходное состояние	с включённым удалённым доступом
    scpi::cmd $channel "*RST"
    after 500
    
	# включаем удалённый доступ
    scpi::cmd $channel "*CLS;SYSTEM:REMOTE"
}

# Также переводит устройство в режим ручного управления.
# Аргументы
#   channel - канал с открытым портом для связи с устройством
proc hardware::agilent::pse3645a::done { channel } {
	if { $channel == "" } {
		return
	}

    scpi::cmd $channel "*RST;SYSTEM:LOCAL"
}

# Включает/выключает выход ИП
# Аргументы
#   channel - канал устройства
#   on - true/false
proc hardware::agilent::pse3645a::setOutput { channel on } {
    set mode [expr $on ? 1 : 0]
	scpi::setAndQuery $channel "OUTPUT" $mode
}

