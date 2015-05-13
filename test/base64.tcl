#!/usr/bin/tclsh
package require base64

set f [open [lindex $argv 0] rb]
set data [read $f]
close $f

puts [::base64::encode $data]

