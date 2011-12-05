# startfile.tcl --
#
#   Open file in proper application
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide startfile 0.1.0

namespace eval startfile {
  namespace export start
}

# Starts file
# Arguments
#   fileName - name pf the file to start
#   args - optional arguments
# Return
#   0 - file is started
#   -1 - file type is not detected
#   -2 - platform is not supported
proc startfile::start { fileName args } {
	global tcl_platform

	if { $tcl_platform(platform) == "windows" } {
		return [startfile::startWin $fileName $args]
	}

	if { $tcl_platform(platform) == "unix" } {
		# not implemented yet
		foreach n [array names tcl_platform] {
			puts "$n=$tcl_platform($n)"
		}
	}

	return -2
}

# Start file in 32- and -64-bit Windows
proc startfile::startWin { fileName args } {
	package require registry
	global env

	set cmd [getCommandFromRegistry [file extension $fileName]]
	if { $cmd != "" } {

		# substitute arguments
		while { [regexp "\%(\[0-9\\*\]+)" $cmd m v] } {
			if { $v == 1 } {
				set cmd [regsub "\%$v" $cmd $fileName ]
				continue
			}
			if { $v == "*" } {
				set cmd [regsub "\%\\$v" $cmd $args ]
				continue
			}
			set cmd [regsub "\%$v" $cmd [lindex $args [expr $v - 2]]]
		}

		# substitute environment variables
		while { [regexp "\%(\[^\%\]+)\%" $cmd m v] } {
			set cmd [regsub "\%$v\%" $cmd $env($v) ]
		}

		# substitute backslashes
		set cmd [regsub -all "\\\\" $cmd "/"]

		eval "exec $cmd &"
		return 0
	}

	return -1
}

proc startfile::getCommandFromRegistry { ext } {
	if { ![catch { set k [registry get "HKEY_CLASSES_ROOT\\$ext" {}] } ] } {
		if { ![catch { set k [registry get "HKEY_CLASSES_ROOT\\$k\\shell\\open\\command" {}] } ] } {
			return $k
		}
	}

	if { ![catch { set k [registry get "HKEY_CLASSES_ROOT\\$ext" "PerceivedType"] } ] } {
		if { [string equal -nocase $k "text"] } {
			return [startfile::getCommandFromRegistry ".txt"]
		}
	}

	return ""
}

