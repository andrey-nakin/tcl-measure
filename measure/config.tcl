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
package require measure::interop

namespace eval measure::config {
  namespace export config read write get
}

set measure::config::configFileIsRead 0

proc measure::config::read { { cfgFileName "" } } {
	global measure::config::configFileIsRead log

    set cfgFileName [configFileName $cfgFileName]
#	set logConfig [measure::logger::init measure::config]

	if { [catch { set fd [ini::open $cfgFileName r] } rc ] } {
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

proc measure::config::write { { cfgFileName "" } } {
#	set logConfig [measure::logger::init measure::config]
	set arrays { settings measure }

	if { [catch { set fd [ini::open [configFileName $cfgFileName] w+] } rc ] } {
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

	set usage ": init \[options] optName ?defValue?\noptions:"
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

proc measure::config::configFileName { fn } {
    if { $fn == "" } {
        return [file join [pwd] "[file rootname [file tail [measure::interop::mainScriptFileName]]].ini"]
    }
    return $fn
}
