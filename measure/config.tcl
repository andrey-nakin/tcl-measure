# config.tcl --
#
#   Read, write configuration file
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::config 0.1.0

package require inifile
package require cmdline
package require measure::logger

namespace eval measure::config {
  namespace export config read write get
}

set measure::config::configFileIsRead 0

proc measure::config::read { { configFileName params.ini } } {
	global measure::config::configFileIsRead

#	set logConfig [measure::logger::init measure::config]

	if { [catch { set fd [ini::open $configFileName r] } rc ] } {
		#${logConfig}::error "Ошибка открытия файла конфигурации: $rc"
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
	set configFileIsRead 1
}

proc measure::config::write { { configFileName params.ini } } {
#	set logConfig [measure::logger::init measure::config]
	set arrays { settings measure }

	if { [catch { set fd [ini::open $configFileName w+] } rc ] } {
#		${logConfig}::error "Ошибка открытия файла конфигурации: $rc"
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

proc measure::config::is-read {} {
	global measure::config::configFileIsRead
	return $configFileIsRead
}

proc measure::config::get { args } {
	set opts {
		{required	""	"Whether configuration settings required"}
	}

	set usage ": init \[options] channel\noptions:"
	array set options [::cmdline::getoptions args $opts $usage]

	set optName [lindex $args 0]
	if { [llength $args] > 1 } {
		set defValue [lindex $args 1]
	} else {
		set defValue ""
	}

	if { ![is-read] } {
		read
	}

	global settings

	if { [info exists settings($optName)] && $settings($optName) != "" } {
		return $settings($optName)
	} else {
		if { $options(required) } {
			error "Required `$optName' option is not found in configuration file"
		}
		return $defValue
	}
}

proc measure::config::validate { lst } {
    global settings
    
    foreach { name defValue } $lst {
        if { ![info exists settings($name)] || $settings($name) == "" } {
            set settings($name) $defValue
        }
    }
}
