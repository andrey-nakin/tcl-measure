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

proc hardware::owen::trm201::init { service } {
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
}

