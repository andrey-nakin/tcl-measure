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

namespace eval ::measure::widget {
}

image create photo ::img::delete -format GIF -data {
    R0lGODlhEAAQAIABAIQAAP///yH5BAEAAAEALAAAAAAQABAAAAIjjI+pmwAc3HGy
    PUSvqYpuvWQg40FfSVacBa5nN6JYDI3mzRQAOw==
}

#source "exit-button.tcl"

proc ::measure::widget::exit-button { w } {
	frame $w.fr
	pack $w.fr -fill both -expand 1
	pack [ttk::button $w.fr.bexit -text "\u0412\u044b\u0445\u043e\u0434" -image ::img::delete -compound left -command quit] -padx 5 -pady 5 -side right
}

proc ::measure::widget::fileSaveDialog { w ent } {
	set file [tk_getSaveFile -parent $w]

	if {[string compare $file ""]} {
		$ent delete 0 end
		$ent insert 0 $file
		$ent xview end
	}
}

