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
package require hardware::agilent::mm34410a
package require measure::datafile

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

proc ::measure::widget::mmControls { prefix settingsVar } {
	grid [ttk::label $prefix.laddr -text "\u0410\u0434\u0440\u0435\u0441:"] -row 0 -column 0 -sticky w
	grid [ttk::combobox $prefix.addr -textvariable settings(${settingsVar}.addr) -values [measure::visa::allInstruments]] -row 0 -column 1 -columnspan 7 -sticky we

	grid [ttk::label $prefix.lmode -text "\u0421\u043A\u043E\u0440\u043E\u0441\u0442\u044C RS-232:"] -row 1 -column 0 -sticky w
	grid [ttk::combobox $prefix.mode -width 6 -textvariable settings(${settingsVar}.baud) -state readonly -values $hardware::agilent::mm34410a::baudRates] -row 1 -column 1 -sticky w

	grid [ttk::label $prefix.lparity -text "\u0427\u0451\u0442\u043D\u043E\u0441\u0442\u044C RS-232:"] -row 1 -column 3 -sticky w
	grid [ttk::combobox $prefix.parity -width 6 -textvariable settings(${settingsVar}.parity) -state readonly -values $measure::com::parities] -row 1 -column 4 -sticky w

	grid [ttk::label $prefix.lnplc -text "\u0426\u0438\u043A\u043B\u043E\u0432 50 \u0413\u0446 \u043D\u0430 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u0435:"] -row 1 -column 6 -sticky w
	grid [ttk::combobox $prefix.nplc -width 6 -textvariable settings(${settingsVar}.nplc) -state readonly -values $hardware::agilent::mm34410a::nplcs ] -row 1 -column 7 -sticky w

	grid columnconfigure $prefix { 0 1 3 4 6 } -pad 5
	grid columnconfigure $prefix { 2 5 } -weight 1
	grid rowconfigure $prefix { 0 1 2 3 4 5 6 7 8 } -pad 5
}

proc ::measure::widget::psControls { prefix settingsVar } {
	grid [ttk::label $prefix.laddr -text "\u0410\u0434\u0440\u0435\u0441:"] -row 0 -column 0 -sticky w
	grid [ttk::combobox $prefix.addr -textvariable settings(${settingsVar}.addr) -values [measure::visa::allInstruments]] -row 0 -column 1 -columnspan 7 -sticky we

	grid [ttk::label $prefix.lmode -text "\u0421\u043A\u043E\u0440\u043E\u0441\u0442\u044C RS-232:"] -row 1 -column 0 -sticky w
	grid [ttk::combobox $prefix.mode -width 6 -textvariable settings(${settingsVar}.baud) -state readonly -values $hardware::agilent::mm34410a::baudRates] -row 1 -column 1 -sticky w

	grid [ttk::label $prefix.lparity -text "\u0427\u0451\u0442\u043D\u043E\u0441\u0442\u044C RS-232:"] -row 1 -column 3 -sticky w
	grid [ttk::combobox $prefix.parity -width 6 -textvariable settings(${settingsVar}.parity) -state readonly -values $measure::com::parities] -row 1 -column 4 -sticky w

	grid [ttk::label $prefix.lnplc -text "\u041C\u0430\u043A\u0441\u0438\u043C\u0430\u043B\u044C\u043D\u044B\u0439 \u0442\u043E\u043A, \u043C\u0410:"] -row 1 -column 6 -sticky w
	grid [ttk::spinbox $prefix.fixedT -width 6 -textvariable settings(${settingsVar}.maxCurrent) -from 0 -to 1300 -increment 100 -validate key -validatecommand {string is double %P}] -row 1 -column 7 -sticky w

	grid columnconfigure $prefix { 0 1 2 3 4 5 6 } -pad 5
	grid columnconfigure $prefix { 2 5 } -weight 1
	grid rowconfigure $prefix { 0 1 } -pad 5
}

proc ::measure::widget::mvu8Controls { prefix settingsVar } {
    grid [ttk::label $prefix.lrs485 -text "\u041F\u043E\u0440\u0442 \u0434\u043B\u044F \u0410\u04214:"] -row 0 -column 0 -sticky w
    grid [ttk::combobox $prefix.rs485 -width 10 -textvariable settings(${settingsVar}.serialAddr) -values [measure::com::allPorts]] -row 0 -column 1 -sticky w
    
    grid [ttk::label $prefix.lswitchAddr -text "\u0421\u0435\u0442\u0435\u0432\u043E\u0439 \u0430\u0434\u0440\u0435\u0441 \u041C\u0412\u0423-8:"] -row 0 -column 2 -sticky w
    grid [ttk::spinbox $prefix.switchAddr -width 10 -textvariable settings(${settingsVar}.rs485Addr) -from 1 -to 2040 -validate key -validatecommand {string is integer %P}] -row 0 -column 3 -sticky w

	grid columnconfigure $prefix { 0 1 2 3 4 5 6 } -pad 5
	grid columnconfigure $prefix { 2 5 } -weight 1
	grid rowconfigure $prefix { 0 1 } -pad 5
}

proc ::measure::widget::resistanceMethodControls { prefix settingsVar } {
    grid [ttk::label $prefix.lamp -text "Вольтметром/Амперметром:"] -row 0 -column 0 -sticky w
    grid [ttk::radiobutton $prefix.amp -value 0 -variable settings(${settingsVar}.method) -command toggleTestResistance] -row 0 -column 1 -sticky e
    
    grid [ttk::label $prefix.lvolt -text "Вольтметром/Вольтметром:"] -row 1 -column 0 -sticky w
    grid [ttk::radiobutton $prefix.volt -value 1 -variable settings(${settingsVar}.method) -command toggleTestResistance] -row 1 -column 1 -sticky e
    
    grid [ttk::label $prefix.lr -text "  Эталонное сопротивление, Ом:"] -row 2 -column 0 -sticky w
    grid [ttk::spinbox $prefix.r -width 10 -textvariable settings(${settingsVar}.reference.resistance) -from 0 -to 10000000 -increment 100 -validate key -validatecommand {string is double %P}] -row 2 -column 1 -sticky e
    
    grid [ttk::label $prefix.lrerr -text "  Погрешность, Ом:"] -row 3 -column 0 -sticky w
    grid [ttk::spinbox $prefix.rerr -width 10 -textvariable settings(${settingsVar}.reference.error) -from 0 -to 10000000 -increment 100 -validate key -validatecommand {string is double %P}] -row 3 -column 1 -sticky e
    
    grid [ttk::label $prefix.lman -text "Вольтметром/Вручную:"] -row 4 -column 0 -sticky w
    grid [ttk::radiobutton $prefix.man -value 2 -variable settings(${settingsVar}.method) -command toggleTestResistance] -row 4 -column 1 -sticky e
    
    grid [ttk::label $prefix.lcur -text "  Сила тока, мА:"] -row 5 -column 0 -sticky w
    grid [ttk::spinbox $prefix.cur -width 10 -textvariable settings(${settingsVar}.manual.current) -from 0 -to 10000000 -increment 100 -validate key -validatecommand {string is double %P}] -row 5 -column 1 -sticky e
    
    grid [ttk::label $prefix.lcurerr -text "  Погрешность, мА:"] -row 6 -column 0 -sticky w
    grid [ttk::spinbox $prefix.curerr -width 10 -textvariable settings(${settingsVar}.manual.error) -from 0 -to 10000000 -increment 100 -validate key -validatecommand {string is double %P}] -row 6 -column 1 -sticky e
    
    grid [ttk::label $prefix.lohm -text "Омметром:"] -row 7 -column 0 -sticky w
    grid [ttk::radiobutton $prefix.ohm -value 3 -variable settings(${settingsVar}.method) -command toggleTestResistance] -row 7 -column 1 -sticky e
    
    grid columnconfigure $prefix { 0 1 } -pad 5
    grid rowconfigure $prefix { 0 1 2 3 4 5 6 7 } -pad 5
    grid columnconfigure $prefix { 1 } -weight 1
}

proc ::measure::widget::switchControls { prefix settingsVar } {
    grid [ttk::label $prefix.lswitchVoltage -text "Переполюсовка напряжения:"] -row 0 -column 0 -sticky w
    grid [ttk::checkbutton $prefix.switchVoltage -variable settings(${settingsVar}.voltage)] -row 0 -column 1 -sticky e
    
    grid [ttk::label $prefix.lswitchCurrent -text "Переполюсовка тока:"] -row 1 -column 0 -sticky w
    grid [ttk::checkbutton $prefix.switchCurrent -variable settings(${settingsVar}.current)] -row 1 -column 1 -sticky e
    
    grid [ttk::label $prefix.ldelay -text "Пауза после переключения, мс:"] -row 2 -column 0 -sticky w
    grid [ttk::spinbox $prefix.delay -width 10 -textvariable settings(${settingsVar}.delay) -from 0 -to 10000 -increment 100 -validate key -validatecommand {string is integer %P}] -row 2 -column 1 -sticky e
    
    grid columnconfigure $prefix {0 1} -pad 5
    grid rowconfigure $prefix {0 1 2 3} -pad 5
    grid columnconfigure $prefix { 1 } -weight 1
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

