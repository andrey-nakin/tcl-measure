# exit-button.tcl --
#
# Application exit button
#
# Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package require Tk
package require Ttk

proc ::measure::widget::exit-button { w } {
	frame $w.fr
	pack $w.fr -fill both -expand 1
	frame $w.fr.pnl -relief raised -borderwidth 1
	pack $w.fr.pnl -fill both -expand 1
	pack [ttk::button $w.fr.bexit -text "Выход!" -compound left -command quit] -padx 5 -pady 5 -side right
}

