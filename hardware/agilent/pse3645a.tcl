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
set hardware::agilent::pse3645a::supportedIds { "^Agilent Technologies,E3645A,.*" }

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

# Calculates and returns systematic DC voltage measure error
# Arguments
#   voltage - voltage value measured in volts
# Returns
#   Absolute error.
proc hardware::agilent::pse3645a::dcvSystematicError { voltage  } {
	return [expr $voltage * 0.0005]
}

# Calculates and returns systematic DC current measure error
# Arguments
#   current - current value measured in ampers
# Returns
#   Absolute error.
proc hardware::agilent::pse3645a::dciSystematicError { current } {
    return [expr $current * 0.0015]
}

# Производит опрос устройства и возвращает результат
# Аргументы:
#   args - параметры устройства, такие же, как в процедуре open
# Результат: целочисленное значение:
#   > 0 - опросо произведён успешно
#  0 - нет связи или неверные параметры устройства
#  -1 - устройство не является ИП
proc hardware::agilent::pse3645a::test { args } {
	set result 0
    variable supportedIds

	catch {
		set mm [open {*}$args]

		# производим опрос устройства
		set id [scpi::query $mm "*IDN?"]
		if { $id != "" } {
		    set result -1
    		foreach sid $supportedIds {
                if {[regexp -nocase $sid $id]} {
                    set result 1
                    break
                }
            }
        }

		close $mm
	} rc inf

	return $result
}

