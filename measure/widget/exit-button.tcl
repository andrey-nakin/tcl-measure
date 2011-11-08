# exit-button.tcl --
#
# Application exit button
#
# Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

proc ::measure::widget::exit-button { w } {
	pack [ttk::button $w.bexit -text "Выход" -image ::img::delete -compound left -command exit] -expand no -side right -side bottom
}

