# trm201.tcl --
#
#   Work with OWEN TRM201 single-channel temperature measurer/controller
#   http://www.owen.ru/en/catalog/28533238
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide hardware::owen::trm201 0.1.0

namespace eval hardware::owen::trm201 {
  namespace export init
}

# addresses of registers
set hardware::owen::trm201::STAT	0x0000
set hardware::owen::trm201::PV		0x0001
set hardware::owen::trm201::SP		0x0002
set hardware::owen::trm201::dAC		0x0409
set hardware::owen::trm201::CtL		0x040C
set hardware::owen::trm201::DEV		0x1000

# possible values of dAC register
set hardware::owen::trm201::dAC-REGISTRATOR	0
set hardware::owen::trm201::dAC-CONTROLLER	1

# possible values of CtL register
set hardware::owen::trm201::CtL-HEATER	0
set hardware::owen::trm201::CtL-FREEZER 1

proc hardware::owen::trm201::init { service } {
	global hardware::owen::trm201::DEV
	set descriptor 32
	set res [::modbus::cmd 03 $descriptor DEV 4]
}

# Reads current temperature from device
# Blocking
# Arguments
#   descriptor - device descriptor
# Returns
#   temperature
proc hardware::owen::trm201::readTemperature { descriptor } {
	package require modbus
}

# Sets desired temperature on device
# Blocking
# Arguments
#   descriptor - device descriptor
#   temperature - desired temperature
proc hardware::owen::trm201::setTemperature { descriptor temperature } {
	package require modbus
	set res [::modbus::cmd 16 $descriptor 0x0002 ]
}

# Sends Modbus command to device, waits for and returns response
# Arguments
#   descriptor - device descriptor
#   cmd - Modbus command (decimal)
#   args - command arguments
# Returns
#   Modbus response (binary)
proc hardware::owen::trm201::cmd { descriptor cmd args } {
	package require modbus
	return [::modbus::cmd $cmd $descriptor {*} $args]
}

