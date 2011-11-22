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

proc measure::config::read { { configFileName params.ini } } {
	set log [measure::logger::init measure::config]

	if { [catch { set fd [ini::open $configFileName r] } rc ] } {
		${log}::error "Ошибка открытия файла конфигурации: $rc"
		return
	}

	foreach section [::ini::sections $fd] {
		global $section
		array set $section [list]

		foreach {key value} [::ini::get $fd $section] {
			set ${section}($key) $value
		}
	}

	ini::close $fd
}

proc measure::config::write { { configFileName params.ini } } {
	set log [measure::logger::init measure::config]
	set arrays { settings measure }

	if { [catch { set fd [ini::open $configFileName r+] } rc ] } {
		${log}::error "Ошибка открытия файла конфигурации: $rc"
		return
	}

	foreach section $arrays {
		global $section

		if { [array exists $section] } {
			foreach {key value} [array get $section] {
				::ini::set $fd $section $key $value
			}
		}
	}

	::ini::commit $fd
	ini::close $fd
}

