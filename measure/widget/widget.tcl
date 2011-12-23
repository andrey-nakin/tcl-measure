# widget.tcl --
#
# Widgets for measuring assemblies
#
# Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package provide measure::widget 0.1.0

package require Tcl 8.4
package require Tk
package require Ttk
package require measure::widget::images
package require startfile

namespace eval ::measure::widget {
  namespace export setDisabledByVar
}

#source "exit-button.tcl"

proc ::measure::widget::exit-button { w } {
	frame $w.fr
	pack $w.fr -fill x -side bottom
	pack [ttk::button $w.fr.bexit -text "\u0412\u044b\u0445\u043e\u0434" -image ::img::delete -compound left -command quit] -padx 5 -pady {20 5} -side right
}

proc ::measure::widget::std-bottom-panel { w } {
	frame $w.fr
	pack $w.fr -fill x -side bottom
	pack [ttk::button $w.fr.bexit -text "\u0412\u044b\u0445\u043e\u0434" -image ::img::delete -compound left -command quit] -padx 5 -pady {20 5} -side right

	set manual [file join [file dirname [info script]] doc manual.pdf]
	if { [file exists $manual] } {
		pack [ttk::button $w.fr.bmanual -text "\u0421\u043f\u0440\u0430\u0432\u043a\u0430" -image ::img::pdf -compound left -command [list startfile::start $manual]] -padx 5 -pady {20 5} -side left
	}
}

proc ::measure::widget::fileSaveDialog { w ent } {
	set file [tk_getSaveFile -parent $w]

	if {[string compare $file ""]} {
		$ent delete 0 end
		$ent insert 0 $file
		#$ent xview end
	}
}

proc ::measure::widget::setDisabled { v args } {
	foreach ctrl $args {
		if { $v } {
			$ctrl configure -state normal
		} else {
			$ctrl configure -state disabled
		}
	}
}

proc ::measure::widget::setDisabledByVar { varName args } {
	set v [getVarValue $varName]
	foreach ctrl $args {
		if { $v } {
			$ctrl configure -state normal
		} else {
			$ctrl configure -state disabled
		}
	}
}

proc ::measure::widget::setDisabledInv { v args } {
	foreach ctrl $args {
		if { $v } {
			$ctrl configure -state disabled
		} else {
			$ctrl configure -state normal
		}
	}
}

proc ::measure::widget::setDisabledByVarInv { varName args } {
	set v [getVarValue $varName]
	foreach ctrl $args {
		if { $v } {
			$ctrl configure -state disabled
		} else {
			$ctrl configure -state normal
		}
	}
}

proc ::measure::widget::getVarValue { varName } {
	set globalName $varName
	set p [string first "(" $globalName]
	if { $p > 0 } {
		set globalName [string range $globalName 0 [expr $p - 1]]
	}
	global $globalName

	if { [info exists $varName] } {
		eval "set v \$$varName"
	} else {
		set v 0
	}

	return $v
}

if { [info commands ttk::spinbox] == "" } {
	proc ::ttk::spinbox args {
		set cmd "set res \[::spinbox $args\]"
		eval $cmd
		return $res
	}
}

if { $tcl_platform(platform) == "unix" } {
	ttk::setTheme "clam"
}

