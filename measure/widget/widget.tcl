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
	pack [ttk::button $w.bexit -text "Выход" -image ::img::delete -compound left -command exit] -expand no -side right -side bottom
}

