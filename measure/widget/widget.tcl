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
package require measure::thermocouple
package require cmdline
package require math::statistics

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
			catch { $ctrl configure -state normal }
		} else {
			catch { $ctrl configure -state disabled }
		}
		
		foreach child [winfo children $ctrl] {
		    setDisabled $v $child
        }
	}
}

proc ::measure::widget::setDisabledByVar { varName args } {
	set v [getVarValue $varName]
	foreach ctrl $args {
		if { $v } {
			catch { $ctrl configure -state normal }
		} else {
			catch { $ctrl configure -state disabled }
		}

		foreach child [winfo children $ctrl] {
		    setDisabled $v $child
        }
	}
}

proc ::measure::widget::setDisabledInv { v args } {
	foreach ctrl $args {
		if { $v } {
			catch { $ctrl configure -state disabled }
		} else {
			catch { $ctrl configure -state normal }
		}

		foreach child [winfo children $ctrl] {
		    setDisabled $v $child
        }
	}
}

proc ::measure::widget::setDisabledByVarInv { varName args } {
	set v [getVarValue $varName]
	foreach ctrl $args {
		if { $v } {
			catch { $ctrl configure -state disabled }
		} else {
			catch { $ctrl configure -state normal }
		}
		
		foreach child [winfo children $ctrl] {
		    setDisabled $v $child
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

proc ::measure::widget::getVar { varName } {
    global settings
	set val ""
	catch { eval "set val $$varName" }
	return $val
}

proc ::measure::widget::mmControls { prefix settingsVar } {

    proc testMm { addrVar baudVar parityVar btn } {
	    $btn configure -state disabled
		after 100 [list ::measure::widget::testMmImpl [getVar $addrVar] [getVar $baudVar] [getVar $parityVar] $btn]
    } 

    proc testMmImpl { addr baud parity btn } {
        package require hardware::agilent::mm34410a

		set res [hardware::agilent::mm34410a::test -baud $baud -parity $parity $addr]
		if { $res > 0 } {
			tk_messageBox -icon info -type ok -title "\u041E\u043F\u0440\u043E\u0441" -parent . -message "\u0421\u0432\u044F\u0437\u044C \u0443\u0441\u0442\u0430\u043D\u043E\u0432\u043B\u0435\u043D\u0430"
		} elseif { $res == 0} {
			tk_messageBox -icon error -type ok -title "\u041E\u043F\u0440\u043E\u0441" -parent . -message "\u041D\u0435\u0442 \u0441\u0432\u044F\u0437\u0438"
		} else {
			tk_messageBox -icon error -type ok -title "\u041E\u043F\u0440\u043E\u0441" -parent . -message "Device is not a Hewlett Packard 34401A-compatible multumeter"
		}
	    $btn configure -state enabled
    } 

	grid [ttk::label $prefix.laddr -text "\u0410\u0434\u0440\u0435\u0441:"] -row 0 -column 0 -sticky w
	grid [ttk::combobox $prefix.addr -textvariable settings(${settingsVar}.addr) -values [measure::visa::allInstruments]] -row 0 -column 1 -columnspan 9 -sticky we

	grid [ttk::label $prefix.lmode -text "\u0421\u043A\u043E\u0440\u043E\u0441\u0442\u044C RS-232:"] -row 1 -column 0 -sticky w
	grid [ttk::combobox $prefix.mode -width 6 -textvariable settings(${settingsVar}.baud) -state readonly -values $hardware::agilent::mm34410a::baudRates] -row 1 -column 1 -sticky w

	grid [ttk::label $prefix.lparity -text "\u0427\u0451\u0442\u043D\u043E\u0441\u0442\u044C RS-232:"] -row 1 -column 3 -sticky w
	grid [ttk::combobox $prefix.parity -width 6 -textvariable settings(${settingsVar}.parity) -state readonly -values $measure::com::parities] -row 1 -column 4 -sticky w

	grid [ttk::label $prefix.lnplc -text "\u0426\u0438\u043A\u043B\u043E\u0432 50 \u0413\u0446 \u043D\u0430 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u0435:"] -row 1 -column 6 -sticky w
	grid [ttk::combobox $prefix.nplc -width 6 -textvariable settings(${settingsVar}.nplc) -state readonly -values $hardware::agilent::mm34410a::nplcs ] -row 1 -column 7 -sticky w

    grid [ttk::button $prefix.test -text "\u041E\u043F\u0440\u043E\u0441" -command [list ::measure::widget::testMm settings(${settingsVar}.addr) settings(${settingsVar}.baud) settings(${settingsVar}.parity) $prefix.test] ] -row 1 -column 9 -sticky e

	grid columnconfigure $prefix { 0 1 3 4 6 } -pad 5
	grid columnconfigure $prefix { 2 5 8 } -weight 1
	grid rowconfigure $prefix { 0 1 2 3 4 5 6 7 8 } -pad 5
}

proc ::measure::widget::psControls { prefix settingsVar } {

    proc testPs { addrVar baudVar parityVar btn } {
	    $btn configure -state disabled
		after 100 [list ::measure::widget::testPsImpl [getVar $addrVar] [getVar $baudVar] [getVar $parityVar] $btn]
    } 

    proc testPsImpl { addr baud parity btn } {
        package require hardware::agilent::pse3645a

		set res [hardware::agilent::pse3645a::test -baud $baud -parity $parity $addr]
		if { $res > 0 } {
			tk_messageBox -icon info -type ok -title "\u041E\u043F\u0440\u043E\u0441" -parent . -message "\u0421\u0432\u044F\u0437\u044C \u0443\u0441\u0442\u0430\u043D\u043E\u0432\u043B\u0435\u043D\u0430"
		} elseif { $res == 0} {
			tk_messageBox -icon error -type ok -title "\u041E\u043F\u0440\u043E\u0441" -parent . -message "\u041D\u0435\u0442 \u0441\u0432\u044F\u0437\u0438"
		} else {
			tk_messageBox -icon error -type ok -title "\u041E\u043F\u0440\u043E\u0441" -parent . -message "\u423\u441\u442\u440\u43E\u439\u441\u442\u432\u43E \u43D\u435 \u44F\u432\u43B\u44F\u435\u442\u441\u44F \u438\u441\u442\u43E\u447\u43D\u438\u43A\u43E\u43C \u43F\u438\u442\u430\u43D\u438\u44F Agilent E3645A \u438\u43B\u438 \u430\u43D\u430\u43B\u43E\u433\u43E\u43C"
		}
	    $btn configure -state enabled
    } 

	grid [ttk::label $prefix.laddr -text "\u0410\u0434\u0440\u0435\u0441:"] -row 0 -column 0 -sticky w
	grid [ttk::combobox $prefix.addr -textvariable settings(${settingsVar}.addr) -values [measure::visa::allInstruments]] -row 0 -column 1 -columnspan 9 -sticky we

	grid [ttk::label $prefix.lmode -text "\u0421\u043A\u043E\u0440\u043E\u0441\u0442\u044C RS-232:"] -row 1 -column 0 -sticky w
	grid [ttk::combobox $prefix.mode -width 6 -textvariable settings(${settingsVar}.baud) -state readonly -values $hardware::agilent::mm34410a::baudRates] -row 1 -column 1 -sticky w

	grid [ttk::label $prefix.lparity -text "\u0427\u0451\u0442\u043D\u043E\u0441\u0442\u044C RS-232:"] -row 1 -column 3 -sticky w
	grid [ttk::combobox $prefix.parity -width 6 -textvariable settings(${settingsVar}.parity) -state readonly -values $measure::com::parities] -row 1 -column 4 -sticky w

	grid [ttk::label $prefix.lnplc -text "\u041C\u0430\u043A\u0441\u0438\u043C\u0430\u043B\u044C\u043D\u044B\u0439 \u0442\u043E\u043A, \u043C\u0410:"] -row 1 -column 6 -sticky w
	grid [ttk::spinbox $prefix.fixedT -width 6 -textvariable settings(${settingsVar}.maxCurrent) -from 0 -to 1300 -increment 100 -validate key -validatecommand {string is double %P}] -row 1 -column 7 -sticky w

    grid [ttk::button $prefix.test -text "\u041E\u043F\u0440\u043E\u0441" -command [list ::measure::widget::testPs settings(${settingsVar}.addr) settings(${settingsVar}.baud) settings(${settingsVar}.parity) $prefix.test] ] -row 1 -column 9 -sticky e

	grid columnconfigure $prefix { 0 1 2 3 4 5 6 } -pad 5
	grid columnconfigure $prefix { 2 5 8 } -weight 1
	grid rowconfigure $prefix { 0 1 } -pad 5
}

proc ::measure::widget::mvu8Controls { prefix settingsVar } {

    proc testMvu8 { portVar idVar btn } {
        package require hardware::owen::mvu8
        global settings
        
	    $btn configure -state disabled
	    eval "set port $$portVar"
	    eval "set id $$idVar"
		after 100 [list ::measure::widget::testMvu8Impl $port $id $btn]
    } 

    proc testMvu8Impl { port id btn } {
		if { [::hardware::owen::mvu8::modbus::test $port $id] } {
			tk_messageBox -icon info -type ok -title "\u041E\u043F\u0440\u043E\u0441" -parent . -message "\u0421\u0432\u044F\u0437\u044C \u0443\u0441\u0442\u0430\u043D\u043E\u0432\u043B\u0435\u043D\u0430"
		} else {
			tk_messageBox -icon error -type ok -title "\u041E\u043F\u0440\u043E\u0441" -parent . -message "\u041D\u0435\u0442 \u0441\u0432\u044F\u0437\u0438"
		}
	    $btn configure -state enabled
	}

    grid [ttk::label $prefix.lrs485 -text "\u041F\u043E\u0440\u0442 \u0434\u043B\u044F \u0410\u04214:"] -row 0 -column 0 -sticky w
    grid [ttk::combobox $prefix.rs485 -width 10 -textvariable settings(${settingsVar}.serialAddr) -values [measure::com::allPorts]] -row 0 -column 1 -sticky w
    
    grid [ttk::label $prefix.lswitchAddr -text "\u0421\u0435\u0442\u0435\u0432\u043E\u0439 \u0430\u0434\u0440\u0435\u0441 \u041C\u0412\u0423-8:"] -row 0 -column 3 -sticky w
    grid [ttk::spinbox $prefix.switchAddr -width 10 -textvariable settings(${settingsVar}.rs485Addr) -from 1 -to 2040 -validate key -validatecommand {string is integer %P}] -row 0 -column 4 -sticky w

    grid [ttk::button $prefix.test -text "\u041E\u043F\u0440\u043E\u0441" -command [list ::measure::widget::testMvu8 settings(${settingsVar}.serialAddr) settings(${settingsVar}.rs485Addr) $prefix.test] ] -row 0 -column 6 -sticky e
    
	grid columnconfigure $prefix { 0 1 2 3 4 5 6 } -pad 5
	grid columnconfigure $prefix { 2 5 } -weight 1
	grid rowconfigure $prefix { 0 1 } -pad 5
}

proc ::measure::widget::trm201Controls { prefix settingsVar } {

    proc testTrm201 { portVar idVar btn } {
        global settings
        
	    $btn configure -state disabled
	    set port ""; set id ""
	    catch {
    	    eval "set port $$portVar"
    	    eval "set id $$idVar"
        }
		after 100 [list ::measure::widget::testTrm201Impl $port $id $btn]
    } 

    proc testTrm201Impl { port id btn } {
        package require hardware::owen::trm201
        set res [::hardware::owen::trm201::test $port $id] 
		if { $res > 0 } {
			tk_messageBox -icon info -type ok -title "\u041E\u043F\u0440\u043E\u0441" -parent . -message "\u0421\u0432\u044F\u0437\u044C \u0443\u0441\u0442\u0430\u043D\u043E\u0432\u043B\u0435\u043D\u0430"
        } elseif { $res < 0 } {			
			tk_messageBox -icon error -type ok -title "\u041E\u043F\u0440\u043E\u0441" -parent . -message "Attached device is not a TRM-201"
		} else {
			tk_messageBox -icon error -type ok -title "\u041E\u043F\u0440\u043E\u0441" -parent . -message "\u041D\u0435\u0442 \u0441\u0432\u044F\u0437\u0438"
		}
	    $btn configure -state enabled
	}

    grid [ttk::label $prefix.lrs485 -text "\u041F\u043E\u0440\u0442 \u0434\u043B\u044F \u0410\u04214:"] -row 0 -column 0 -sticky w
    grid [ttk::combobox $prefix.rs485 -width 10 -textvariable settings(${settingsVar}.serialAddr) -values [measure::com::allPorts]] -row 0 -column 1 -sticky w
    
    grid [ttk::label $prefix.lswitchAddr -text "\u0421\u0435\u0442\u0435\u0432\u043E\u0439 \u0430\u0434\u0440\u0435\u0441 TPM-201:"] -row 0 -column 3 -sticky w
    grid [ttk::spinbox $prefix.switchAddr -width 10 -textvariable settings(${settingsVar}.rs485Addr) -from 1 -to 2040 -validate key -validatecommand {string is integer %P}] -row 0 -column 4 -sticky w

    grid [ttk::button $prefix.test -text "\u041E\u043F\u0440\u043E\u0441" -command [list ::measure::widget::testTrm201 settings(${settingsVar}.serialAddr) settings(${settingsVar}.rs485Addr) $prefix.test] ] -row 0 -column 6 -sticky e
    
	grid columnconfigure $prefix { 0 1 2 3 4 5 6 } -pad 5
	grid columnconfigure $prefix { 2 5 } -weight 1
	grid rowconfigure $prefix { 0 1 } -pad 5
}

proc ::measure::widget::resistanceMethodControls { prefix settingsVar } {
    grid [ttk::label $prefix.lamp -text "\u0412\u043E\u043B\u044C\u0442\u043C\u0435\u0442\u0440\u043E\u043C/\u0410\u043C\u043F\u0435\u0440\u043C\u0435\u0442\u0440\u043E\u043C:"] -row 0 -column 0 -sticky w
    grid [ttk::radiobutton $prefix.amp -value 0 -variable settings(${settingsVar}.method) -command toggleTestResistance] -row 0 -column 1 -sticky e
    
    grid [ttk::label $prefix.lvolt -text "\u0412\u043E\u043B\u044C\u0442\u043C\u0435\u0442\u0440\u043E\u043C/\u0412\u043E\u043B\u044C\u0442\u043C\u0435\u0442\u0440\u043E\u043C:"] -row 1 -column 0 -sticky w
    grid [ttk::radiobutton $prefix.volt -value 1 -variable settings(${settingsVar}.method) -command toggleTestResistance] -row 1 -column 1 -sticky e
    
    grid [ttk::label $prefix.lr -text "  \u042D\u0442\u0430\u043B\u043E\u043D\u043D\u043E\u0435 \u0441\u043E\u043F\u0440\u043E\u0442\u0438\u0432\u043B\u0435\u043D\u0438\u0435, \u041E\u043C:"] -row 2 -column 0 -sticky w
    grid [ttk::spinbox $prefix.r -width 10 -textvariable settings(${settingsVar}.reference.resistance) -from 0 -to 10000000 -increment 100 -validate key -validatecommand {string is double %P}] -row 2 -column 1 -sticky e
    
    grid [ttk::label $prefix.lrerr -text "  \u041F\u043E\u0433\u0440\u0435\u0448\u043D\u043E\u0441\u0442\u044C, \u041E\u043C:"] -row 3 -column 0 -sticky w
    grid [ttk::spinbox $prefix.rerr -width 10 -textvariable settings(${settingsVar}.reference.error) -from 0 -to 10000000 -increment 100 -validate key -validatecommand {string is double %P}] -row 3 -column 1 -sticky e
    
    grid [ttk::label $prefix.lman -text "\u0412\u043E\u043B\u044C\u0442\u043C\u0435\u0442\u0440\u043E\u043C/\u0412\u0440\u0443\u0447\u043D\u0443\u044E:"] -row 4 -column 0 -sticky w
    grid [ttk::radiobutton $prefix.man -value 2 -variable settings(${settingsVar}.method) -command toggleTestResistance] -row 4 -column 1 -sticky e
    
    grid [ttk::label $prefix.lohm -text "\u041E\u043C\u043C\u0435\u0442\u0440\u043E\u043C:"] -row 5 -column 0 -sticky w
    grid [ttk::radiobutton $prefix.ohm -value 3 -variable settings(${settingsVar}.method) -command toggleTestResistance] -row 5 -column 1 -sticky e
    
    grid [ttk::label $prefix.lspc1 -text " "] -row 6 -column 0 -columnspan 2 -sticky w
    
    grid [ttk::label $prefix.lcur -text "\u0421\u0438\u043B\u0430 \u0442\u043E\u043A\u0430, \u043C\u0410:"] -row 7 -column 0 -sticky w
    grid [ttk::spinbox $prefix.cur -width 10 -textvariable settings(${settingsVar}.manual.current) -from 0 -to 10000000 -increment 100 -validate key -validatecommand {string is double %P}] -row 7 -column 1 -sticky e
    
    grid [ttk::label $prefix.lcurerr -text "\u041F\u043E\u0433\u0440\u0435\u0448\u043D\u043E\u0441\u0442\u044C, \u043C\u0410:"] -row 8 -column 0 -sticky w
    grid [ttk::spinbox $prefix.curerr -width 10 -textvariable settings(${settingsVar}.manual.error) -from 0 -to 10000000 -increment 100 -validate key -validatecommand {string is double %P}] -row 8 -column 1 -sticky e
    
    grid columnconfigure $prefix { 0 1 } -pad 5
    grid rowconfigure $prefix { 0 1 2 3 4 5 6 7 8 } -pad 5
    grid columnconfigure $prefix { 1 } -weight 1
}

proc ::measure::widget::switchControls { prefix settingsVar } {
    grid [ttk::label $prefix.lswitchVoltage -text "\u041F\u0435\u0440\u0435\u043F\u043E\u043B\u044E\u0441\u043E\u0432\u043A\u0430 \u043D\u0430\u043F\u0440\u044F\u0436\u0435\u043D\u0438\u044F:"] -row 0 -column 0 -sticky w
    grid [ttk::checkbutton $prefix.switchVoltage -variable settings(${settingsVar}.voltage)] -row 0 -column 1 -sticky e
    
    grid [ttk::label $prefix.lswitchCurrent -text "\u041F\u0435\u0440\u0435\u043F\u043E\u043B\u044E\u0441\u043E\u0432\u043A\u0430 \u0442\u043E\u043A\u0430:"] -row 1 -column 0 -sticky w
    grid [ttk::checkbutton $prefix.switchCurrent -variable settings(${settingsVar}.current)] -row 1 -column 1 -sticky e
    
    grid [ttk::label $prefix.ldelay -text "\u041F\u0430\u0443\u0437\u0430 \u043F\u043E\u0441\u043B\u0435 \u043F\u0435\u0440\u0435\u043A\u043B\u044E\u0447\u0435\u043D\u0438\u044F, \u043C\u0441:"] -row 2 -column 0 -sticky w
    grid [ttk::spinbox $prefix.delay -width 10 -textvariable settings(${settingsVar}.delay) -from 0 -to 10000 -increment 100 -validate key -validatecommand {string is integer %P}] -row 2 -column 1 -sticky e
    
    grid columnconfigure $prefix {0 1} -pad 5
    grid rowconfigure $prefix {0 1 2 3} -pad 5
    grid columnconfigure $prefix { 1 } -weight 1
}

proc ::measure::widget::thermoCoupleControls { args } {

	set options {
		{nb.arg "" "Id of the notebook control to navigate within"}
		{workingTs.arg ""	"Id of the notebook tabsheet to switch to when calibrating"}
		{currentTs.arg "" "Id of the notebook tabsheet to switch to when exiting"}
	}

	proc tcCalibrate { ctl btn paramList } {
		global tcCalParams

		array set params $paramList
		array set tcCalParams [list t1 "" t2 "" mt1 "\u41D\u435 \u441\u43D\u44F\u442\u430" mt2 "\u41D\u435 \u441\u43D\u44F\u442\u430" ctl $ctl btn $btn paramList $paramList]

	    $btn configure -state disabled
		measure::thermocouple::useCorrection 0

		set w .tccal
		tk::toplevel $w
		wm title $w "\u41A\u430\u43B\u438\u431\u440\u43E\u432\u43A\u430 \u442\u435\u440\u43C\u43E\u43F\u430\u440\u44B"
		wm protocol $w WM_DELETE_WINDOW [list ::measure::widget::tcCalibrateQuit $btn $paramList]
		wm attributes $w -topmost 1
		bind . <<ReadTemperature>> "::measure::widget::tcCalibrateRead %d"

		set p [ttk::frame $w.c]
	    grid [ttk::label $p.lexp -text "\u41E\u436\u438\u434\u430\u435\u43C\u430\u44F (\u41A)"] -row 0 -column 1 -sticky we
	    grid [ttk::label $p.lmea -text "\u418\u437\u43C\u435\u440\u435\u43D\u43D\u430\u44F (\u41A)"] -row 0 -column 2 -sticky we

	    grid [ttk::label $p.lt1 -text "\u422\u435\u43C\u43F\u435\u440\u430\u442\u443\u440\u43D\u430\u44F \u442\u43E\u447\u43A\u430 № 1:"] -row 1 -column 0 -sticky w
	    grid [ttk::spinbox $p.t1 -width 15 -textvariable tcCalParams(t1) -from 1 -to 1000 -increment 1 -validate key -validatecommand {string is double %P}] -row 1 -column 1 -sticky w
		grid [ttk::entry $p.e1 -width 15 -textvariable tcCalParams(mt1) -state readonly] -row 1 -column 2 -sticky w
	    grid [ttk::button $p.b1 -text "\u421\u43D\u44F\u442\u44C" -command {::measure::widget::tcCalibrateSet 1}] -row 1 -column 3 -sticky e

	    grid [ttk::label $p.lt2 -text "\u422\u435\u43C\u43F\u435\u440\u430\u442\u443\u440\u43D\u430\u44F \u442\u43E\u447\u43A\u430 № 2:"] -row 2 -column 0 -sticky w
	    grid [ttk::spinbox $p.t2 -width 15 -textvariable tcCalParams(t2) -from 0 -to 1000 -increment 1 -validate key -validatecommand {string is double %P}] -row 2 -column 1 -sticky w
		grid [ttk::entry $p.e2 -width 15 -textvariable tcCalParams(mt2) -state readonly] -row 2 -column 2 -sticky w
	    grid [ttk::button $p.b2 -text "\u421\u43D\u44F\u442\u44C" -command {::measure::widget::tcCalibrateSet 2} -state disabled] -row 2 -column 3 -sticky e

	    grid [ttk::label $p.le -text "\u412\u44B\u440\u430\u436\u435\u43D\u438\u435 \u434\u43B\u44F \u43A\u43E\u440\u440\u435\u43A\u446\u438\u438:"] -row 3 -column 0 -sticky w
		grid [ttk::entry $p.e -textvariable tcCalParams(e) -state readonly] -row 3 -column 1 -columnspan 3 -sticky we

		grid columnconfigure $p { 0 1 2 3 } -pad 5
		grid rowconfigure $p { 0 1 2 3 } -pad 5
		pack $p -fill both -expand 1 -padx 10 -pady 10

		set p [ttk::frame $w.b]
		pack $p -fill x -side bottom -padx 10 -pady 10
		pack [ttk::button $p.bcancel -text "\u41E\u442\u43C\u435\u43D\u430" -image ::img::delete -compound left -command ::measure::widget::tcCalibrateQuit] -side right
		pack [ttk::button $p.bok -text "\u421\u43E\u445\u440\u430\u43D\u438\u442\u44C" -state disabled -image ::img::apply -compound left -command ::measure::widget::tcCalibrateSave] -padx { 0 10 } -side right

		if { [info exist params(nb)] } {
			$params(nb) select $params(workingTs)
		}
	}

	proc tcCalibrateCalc { } {
		global tcCalParams

		set a [expr ($tcCalParams(t2) - $tcCalParams(t1)) / ($tcCalParams(mt2) - $tcCalParams(mt1))]
		set b [expr $tcCalParams(mt1) - $tcCalParams(t1) / $a]

		if { isNaN($a) || isNaN($b) } { 
			error "Cannot determine correction expression: t1=$tcCalParams(t1), t2=$tcCalParams(t2), mt1=$tcCalParams(mt1), mt2=$tcCalParams(mt2)" 
		}

		set tcCalParams(e) [format "%0.6g * (x - (%0.6g))" $a $b]
	}

	proc tcCalibrateSave { } {
		global tcCalParams

		$tcCalParams(ctl) delete 0 end
		$tcCalParams(ctl) insert 0 $tcCalParams(e)
		tcCalibrateQuit
	}

	proc tcCalibrateQuit { } {
		global tcCalParams
		array set params $tcCalParams(paramList)

		destroy .tccal
	    $tcCalParams(btn) configure -state enabled
		measure::thermocouple::useCorrection 1

		if { [info exist params(nb)] } {
			$params(nb) select $params(currentTs)
		}
	}

	proc tcCalibrateSet { idx } {
		global tcCalParams
		set tcCalParams(idx) $idx
		set tcCalParams(startTime) [clock milliseconds]
		set tcCalParams(values) [list]
		set tcCalParams(mt${idx}) "\u421\u43D\u438\u43C\u430\u435\u442\u441\u44F..."
		.tccal.c.b${idx} configure -state disabled
	}

	proc tcCalibrateRead { temp } {
		global tcCalParams log

		if { ![info exists tcCalParams(idx)] } {
			return
		}
		
		if { $temp == "??" } { set temp 0 }
		lappend tcCalParams(values) $temp

		set elapsed [expr [clock milliseconds] - $tcCalParams(startTime)]
		if { [llength $tcCalParams(values)] >= 25 || $elapsed > 30000 } {
			set idx $tcCalParams(idx)
			set tcCalParams(mt${idx}) [format %0.2f [::math::statistics::mean $tcCalParams(values)]]

			if { $idx == 1 } {
				.tccal.c.b2 configure -state normal
			} elseif { $idx == 2 } {
				if { [catch { tcCalibrateCalc } rc] } {
					${log}::error "tcCalibrateSave error $rc"
					tk_messageBox -icon error -type ok -title "\u41E\u448\u438\u431\u43A\u430" -parent .tccal -message "\u41D\u435\u432\u43E\u437\u43C\u43E\u436\u43D\u43E \u43E\u43F\u440\u435\u434\u435\u43B\u438\u442\u44C \u43F\u43E\u43F\u440\u430\u432\u43E\u447\u43D\u44B\u435 \u43A\u43E\u44D\u444\u444\u438\u446\u438\u435\u43D\u442\u44B. \u41F\u440\u43E\u432\u435\u440\u44C\u442\u435 \u43F\u440\u430\u432\u438\u43B\u44C\u43D\u43E\u441\u442\u44C \u432\u432\u435\u434\u451\u43D\u43D\u44B\u445 \u43E\u436\u438\u434\u430\u435\u43C\u44B\u445 \u442\u435\u43C\u43F\u435\u440\u430\u442\u443\u440."
				} else {
					.tccal.b.bok configure -state normal
				}	
			}

			unset tcCalParams(idx)
		}
	}

	set usage ": init \[options] channel\noptions:"
	array set params [::cmdline::getoptions args $options $usage]
	lassign $args prefix settingsVar

    grid [ttk::label $prefix.ltype -text "\u0422\u0438\u043F \u0442\u0435\u0440\u043C\u043E\u043F\u0430\u0440\u044B:"] -row 0 -column 0 -sticky w
    grid [ttk::combobox $prefix.type -width 6 -textvariable settings(${settingsVar}.type) -state readonly -values [measure::thermocouple::getTcTypes]] -row 0 -column 1 -sticky w
    
    grid [ttk::label $prefix.lfixedT -text "\u041E\u043F\u043E\u0440\u043D\u0430\u044F \u0442\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u0430, \u041A:"] -row 0 -column 3 -sticky w
    grid [ttk::spinbox $prefix.fixedT -width 6 -textvariable settings(${settingsVar}.fixedT) -from 0 -to 1200 -increment 1 -validate key -validatecommand {string is double %P}] -row 0 -column 4 -sticky w
    
    grid [ttk::label $prefix.lnegate -text "\u0418\u043D\u0432. \u043F\u043E\u043B\u044F\u0440\u043D\u043E\u0441\u0442\u044C:"] -row 0 -column 6 -sticky w
    grid [ttk::checkbutton $prefix.negate -variable settings(${settingsVar}.negate)] -row 0 -column 7 -sticky w
    
    grid [ttk::label $prefix.lcorrection -text "\u0412\u044B\u0440\u0430\u0436\u0435\u043D\u0438\u0435 \u0434\u043B\u044F \u043A\u043E\u0440\u0440\u0435\u043A\u0446\u0438\u0438:"] -row 1 -column 0 -sticky w
    grid [ttk::entry $prefix.correction -textvariable settings(${settingsVar}.correction)] -row 1 -column 1 -columnspan 7 -sticky we
    grid [ttk::label $prefix.lcorrectionexample -text "\u041D\u0430\u043F\u0440\u0438\u043C\u0435\u0440: (x - 77.4) * 1.1 + 77.4"] -row 2 -column 1 -columnspan 5 -sticky we
    grid [ttk::button $prefix.autocal -command [list ::measure::widget::tcCalibrate $prefix.correction $prefix.autocal [array get params]] -text "\u041A\u0430\u043B\u0438\u0431\u0440\u043E\u0432\u043A\u0430"] -row 2 -column 6 -columnspan 2 -sticky e
    
    grid columnconfigure $prefix { 0 3 6 } -pad 5
    grid columnconfigure $prefix { 2 5 } -weight 1
    grid rowconfigure $prefix { 0 1 2 3 4 5 6 7 8 } -pad 5
}

proc ::measure::widget::dutControls { prefix settingsVar } {
    grid [ttk::label $prefix.ll -text "\u0420\u0430\u0441\u0441\u0442\u043E\u044F\u043D\u0438\u0435 \u043C\u0435\u0436\u0434\u0443 \u043F\u043E\u0442\u0435\u043D\u0446\u0438\u0430\u043B\u044C\u043D\u044B\u043C\u0438 \u043A\u043E\u043D\u0442\u0430\u043A\u0442\u0430\u043C\u0438, \u043C\u043C:"] -row 0 -column 0 -sticky w
    grid [ttk::spinbox $prefix.l -width 10 -textvariable settings(${settingsVar}.l) -from 0 -to 100 -increment 0.1 -validate key -validatecommand {string is double %P}] -row 0 -column 1 -sticky e
    grid [ttk::label $prefix.lle -text "\u00b1"] -row 0 -column 2 -sticky e
    grid [ttk::spinbox $prefix.le -width 10 -textvariable settings(${settingsVar}.lErr) -from 0 -to 100 -increment 0.01 -validate key -validatecommand {string is double %P}] -row 0 -column 3 -sticky e
    
    grid [ttk::label $prefix.llen -text "\u0414\u043B\u0438\u043D\u0430, \u043C\u043C:"] -row 1 -column 0 -sticky w
    grid [ttk::spinbox $prefix.len -width 10 -textvariable settings(${settingsVar}.length) -from 0 -to 100 -increment 0.1 -validate key -validatecommand {string is double %P}] -row 1 -column 1 -sticky e
    grid [ttk::label $prefix.llene -text "\u00b1"] -row 1 -column 2 -sticky e
    grid [ttk::spinbox $prefix.lene -width 10 -textvariable settings(${settingsVar}.lengthErr) -from 0 -to 100 -increment 0.01 -validate key -validatecommand {string is double %P}] -row 1 -column 3 -sticky e
    
    grid [ttk::label $prefix.lwidth -text "\u0428\u0438\u0440\u0438\u043D\u0430, \u043C\u043C:"] -row 2 -column 0 -sticky w
    grid [ttk::spinbox $prefix.width -width 10 -textvariable settings(${settingsVar}.width) -from 0 -to 100 -increment 0.1 -validate key -validatecommand {string is double %P}] -row 2 -column 1 -sticky e
    grid [ttk::label $prefix.lwidthe -text "\u00b1"] -row 2 -column 2 -sticky e
    grid [ttk::spinbox $prefix.widthe -width 10 -textvariable settings(${settingsVar}.widthErr) -from 0 -to 100 -increment 0.01 -validate key -validatecommand {string is double %P}] -row 2 -column 3 -sticky e
    
    grid [ttk::label $prefix.lth -text "\u0422\u043E\u043B\u0449\u0438\u043D\u0430, \u043C\u043C:"] -row 3 -column 0 -sticky w
    grid [ttk::spinbox $prefix.th -width 10 -textvariable settings(${settingsVar}.thickness) -from 0 -to 100 -increment 0.1 -validate key -validatecommand {string is double %P}] -row 3 -column 1 -sticky e
    grid [ttk::label $prefix.lthe -text "\u00b1"] -row 3 -column 2 -sticky e
    grid [ttk::spinbox $prefix.the -width 10 -textvariable settings(${settingsVar}.thicknessErr) -from 0 -to 100 -increment 0.01 -validate key -validatecommand {string is double %P}] -row 3 -column 3 -sticky e
    
    grid columnconfigure $prefix {0 1 2 3} -pad 5
    grid rowconfigure $prefix {0 1 2 3 4} -pad 5
    grid columnconfigure $prefix { 0 } -weight 1
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

