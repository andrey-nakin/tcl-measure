# exit-button.tcl --
#
# Application exit button
#
# Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package provide measure::widget::fullscreen 0.1.0

package require Tcl 8.4
package require Tk

set full_screen_mode 0

bind . <F11> {
    global full_screen_mode
    if { $full_screen_mode } {
        set full_screen_mode 0
    } else {
        set full_screen_mode 1
    }
    wm attributes . -fullscreen $full_screen_mode
}
