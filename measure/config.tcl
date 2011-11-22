# config.tcl --
#
#   Read, write configuration file
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::config 0.1.0

package require inifile
package require measure::logger

namespace eval measure::config {
  namespace export config
}

# Runs code blocks in parallel threads
# Arguments (any number)
#   code blocks to execute
proc measure::config::read { { configFileName params.ini } } {
	set log [measure::logger::init measure::config]

	if { [catch { set fd [ini::open $configFileName r] } rc ] } {
		${log}::error "Ошибка открытия файла конфигурации: $rc"
		return
	}

#	set pairs [ini::get $fd $CONFIG_SECTION_SETTINGS]
	ini::close $fd
}

# Runs code blocks in parallel threads
# Arguments (any number)
#   code blocks to execute
proc measure::config::write { { configFileName params.ini } } {
	set log [measure::logger::init measure::config]

	if { [catch { set fd [ini::open $configFileName r+] } rc ] } {
		${log}::error "Ошибка открытия файла конфигурации: $rc"
		return
	}

	ini::close $fd
}

