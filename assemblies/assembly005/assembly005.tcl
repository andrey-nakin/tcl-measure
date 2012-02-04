#!/usr/bin/wish

###############################################################################
# Измерительная установка № 005
# Термостат с фиксированной уставкой
# Управляется вручную в окне программы или программно по протоколу HTTP
# Температура измеряется термопарой
# К термопаре подключается SCPI-мультиметр 
#   или измеритель-регулятор ОВЕН ТРМ-201
# Температура "печки" регулируется управляемым источником постоянного тока
###############################################################################

package require Tcl 8.5
package require Tk 8.5
package require Ttk 8.5
package require Plotchart
package require Thread
package require inifile
package require math::statistics
package require measure::widget
package require measure::widget::images
package require measure::logger
package require measure::config
package require measure::visa
package require measure::com
package require measure::interop
package require measure::chart
package require startfile
package require hardware::agilent::mm34410a
package require measure::thermocouple

###############################################################################
# Константы
###############################################################################

###############################################################################
# Процедуры
###############################################################################

# Процедура вызывается при завершении работы модуля термостатирования
proc thermostatStopped {} {
	global w

	# Запрещаем кнопку "Стоп"
	$w.fr.stop configure -state disabled

	# Разрешаем кнопку "Старт"
	$w.fr.start configure -state normal
}

# Запускаем модуль термостатирования
proc startThermostat {} {
	global w

	# Сохраняем параметры программы
	measure::config::write

    # Сбрасываем сигнал "прерван"
    measure::interop::clearTerminated

	# Запускаем на выполнение фоновый поток	с процедурой измерения
	measure::interop::startWorker [list source [file join [file dirname [info script]] pid.tcl] ] {thermostatStopped} {}

	# Запрещаем кнопку "Старт"
	$w.fr.start configure -state disabled

	# Разрешаем кнопку "Стоп"
	$w.fr.stop configure -state normal
}

# Прерываем работу модуля термостатирования
proc stopThermostat { { wait 0} } {
	global w

	# Запрещаем кнопку "Стоп"
	$w.fr.stop configure -state disabled

	if { $wait } {
		# Посылаем в измерительный поток сигнал об останове
		# и ждём завершения
		measure::interop::waitForWorkerThreads
	} else {
		# Посылаем в измерительный поток сигнал об останове
		# без ожидания завершения
		measure::interop::terminate
	}
}

# Завершение работы программы
proc quit {} {
	# Сохраняем параметры программы
	measure::config::write

	# завершаем работу модуля термостатирования
	stopThermostat 1

	exit
}

proc addValueToChart { v } {
	global chartValues

	if { ![info exists chartValues] } {
		set chartValues [list]
	}

	if { [llength $chartValues] >= 200 } {
		set chartValues [lrange $chartValues [expr [llength $chartValues] - 199] end]
	}
	lappend chartValues $v

	doPlot	
}

###############################################################################
# Начало скрипта
###############################################################################

set log [measure::logger::init measure]
measure::logger::server

# Создаём окно программы
set w ""
wm title $w. "Установка № 5: Термостат"

# При нажатии крестика в углу окна вызыватьспециальную процедуру завершения
wm protocol $w. WM_DELETE_WINDOW { quit }

# Панель закладок
ttk::notebook $w.nb
pack $w.nb -fill both -expand 1 -padx 2 -pady 3
ttk::notebook::enableTraversal $w.nb

# Закладка "Параметры"
set frm $w.nb.setup
ttk::frame $frm
$w.nb add $frm -text " Параметры "

set p [ttk::labelframe $frm.ps -text " Источник тока " -pad 10]
pack $p -fill x -padx 10 -pady 5

grid [ttk::label $p.laddr -text "Адрес:"] -row 0 -column 0 -sticky w
grid [ttk::combobox $p.addr -textvariable settings(ps.addr) -values [measure::visa::allInstruments]] -row 0 -column 1 -columnspan 7 -sticky we

grid [ttk::label $p.lmode -text "Скорость RS-232:"] -row 1 -column 0 -sticky w
grid [ttk::combobox $p.mode -width 6 -textvariable settings(ps.baud) -state readonly -values $hardware::agilent::mm34410a::baudRates] -row 1 -column 1 -sticky w

grid [ttk::label $p.lparity -text "Чётность RS-232:"] -row 1 -column 3 -sticky w
grid [ttk::combobox $p.parity -width 6 -textvariable settings(ps.parity) -state readonly -values $measure::com::parities] -row 1 -column 4 -sticky w

grid [ttk::label $p.lnplc -text "Максимальный ток, мА:"] -row 1 -column 6 -sticky w
grid [ttk::spinbox $p.fixedT -width 6 -textvariable settings(ps.maxCurrent) -from 0 -to 1300 -increment 100 -validate key -validatecommand {string is double %P}] -row 1 -column 7 -sticky w

grid columnconfigure $p { 0 3 6 } -pad 5
grid columnconfigure $p { 2 5 } -weight 1
grid rowconfigure $p { 0 1 2 3 4 5 6 7 8 } -pad 5

set p [ttk::labelframe $frm.pid -text " ПИД-регулятор " -pad 10]
pack $p -fill x -padx 10 -pady 5

grid [ttk::label $p.ltp -text "Пропорциональный коэффициент:"] -row 0 -column 0 -sticky w
grid [ttk::spinbox $p.tp -width 10 -textvariable settings(pid.tp) -from 0 -to 100000 -increment 1 -validate key -validatecommand {string is double %P}] -row 0 -column 1 -sticky w

grid [ttk::label $p.ltd -text "Дифференциальный коэффициент:"] -row 0 -column 3 -sticky w
grid [ttk::spinbox $p.td -width 10 -textvariable settings(pid.td) -from 0 -to 100000 -increment 1 -validate key -validatecommand {string is double %P}] -row 0 -column 4 -sticky w

grid [ttk::label $p.lti -text "Интегральный коэффициент:"] -row 1 -column 0 -sticky w
grid [ttk::spinbox $p.ti -width 10 -textvariable settings(pid.ti) -from 0 -to 100000 -increment 1 -validate key -validatecommand {string is double %P}] -row 1 -column 1 -sticky w

grid columnconfigure $p { 0 3 } -pad 5
grid columnconfigure $p { 2 } -weight 1 -pad 20
grid rowconfigure $p { 0 1 2 3 4 5 6 7 8 } -pad 5

# Закладка "Вольметр+Термопара"
set frm $w.nb.mmtc
ttk::frame $frm
$w.nb add $frm -text " Параметры вольметра и термопары "

set p [ttk::labelframe $frm.mm -text " Вольтметр " -pad 10]
pack $p -fill x -padx 10 -pady 5

grid [ttk::label $p.laddr -text "Адрес:"] -row 0 -column 0 -sticky w
grid [ttk::combobox $p.addr -textvariable settings(mmtc.mm.addr) -values [measure::visa::allInstruments]] -row 0 -column 1 -columnspan 7 -sticky we

grid [ttk::label $p.lmode -text "Скорость RS-232:"] -row 1 -column 0 -sticky w
grid [ttk::combobox $p.mode -width 6 -textvariable settings(mmtc.mm.baud) -state readonly -values $hardware::agilent::mm34410a::baudRates] -row 1 -column 1 -sticky w

grid [ttk::label $p.lparity -text "Чётность RS-232:"] -row 1 -column 3 -sticky w
grid [ttk::combobox $p.parity -width 6 -textvariable settings(mmtc.mm.parity) -state readonly -values $measure::com::parities] -row 1 -column 4 -sticky w

grid [ttk::label $p.lnplc -text "Циклов 50 Гц на измерение:"] -row 1 -column 6 -sticky w
grid [ttk::combobox $p.nplc -width 6 -textvariable settings(mmtc.mm.nplc) -state readonly -values $hardware::agilent::mm34410a::nplcs ] -row 1 -column 7 -sticky w

grid columnconfigure $p { 0 1 3 4 6 } -pad 5
grid columnconfigure $p { 2 5 } -weight 1
grid rowconfigure $p { 0 1 2 3 4 5 6 7 8 } -pad 5

set p [ttk::labelframe $frm.tc -text " Термопара " -pad 10]
pack $p -fill x -padx 10 -pady 5

grid [ttk::label $p.ltype -text "Тип термопары:"] -row 0 -column 0 -sticky w
grid [ttk::combobox $p.type -width 6 -textvariable settings(mmtc.tc.type) -state readonly -values [measure::thermocouple::getTcTypes]] -row 0 -column 1 -sticky w

grid [ttk::label $p.lfixedT -text "Опорная температура, К:"] -row 0 -column 3 -sticky w
grid [ttk::spinbox $p.fixedT -width 6 -textvariable settings(mmtc.tc.fixedT) -from 0 -to 1200 -increment 1 -validate key -validatecommand {string is double %P}] -row 0 -column 4 -sticky w

grid [ttk::label $p.lnegate -text "Инв. полярность:"] -row 0 -column 6 -sticky w
grid [ttk::checkbutton $p.negate -variable settings(mmtc.tc.negate)] -row 0 -column 7 -sticky w

grid [ttk::label $p.lcorrection -text "Выражение для коррекции:"] -row 1 -column 0 -sticky w
grid [ttk::entry $p.correction -textvariable settings(mmtc.tc.correction)] -row 1 -column 1 -columnspan 7 -sticky we
grid [ttk::label $p.lcorrectionexample -text "Например: (x - 77.4) * 1.1 + 77.4"] -row 2 -column 1 -columnspan 7 -sticky we

grid columnconfigure $p { 0 3 6 } -pad 5
grid columnconfigure $p { 2 5 } -weight 1
grid rowconfigure $p { 0 1 2 3 4 5 6 7 8 } -pad 5

# Закладка "Измерение"
ttk::frame $w.nb.m
$w.nb add $w.nb.m -text " Измерение "

proc doPlot {} {
	global w
	global chartValues chartBgColor

    $w.nb.m.c.c delete all
	if { ![info exists chartValues] } {
		return
	}

	set stats [::math::statistics::basic-stats $chartValues]
	set s [::Plotchart::createXYPlot $w.nb.m.c.c { 0 200 20 } [measure::chart::limits [lindex $stats 1] [lindex $stats 2]]]

	$s dataconfig series1 -colour green
	$s ytext "R, \u03a9"

	if { ![info exists chartBgColor] } {
		set chartBgColor [$w.nb.m.c.c cget -bg]
	}
	$s background plot black
	$s background axes $chartBgColor

	set x 0
	set xx [list]
	foreach y $chartValues {
		$s plot series1 $x $y
		lappend xx $x
		incr x
	}

	if { [llength $xx] > 10 } {
		lassign [::math::statistics::linear-model $xx $chartValues] a b
		set lll [expr [llength $xx] - 1]
		$s dataconfig series2 -colour magenta
		$s plot series2 [lindex $xx 0] [expr [lindex $xx 0] * $b + $a]
		$s plot series2 [lindex $xx $lll] [expr [lindex $xx $lll] * $b + $a]
	}
}

proc doResize {} {
    global redo

    #
    # To avoid redrawing the plot many times during resizing,
    # cancel the callback, until the last one is left.
    #
    if { [info exists redo] } {
        after cancel $redo
    }

    set redo [after 50 doPlot]
}

# Раздел "Управление"
set p [ttk::labelframe $w.nb.m.ctl -text " Управление " -pad 10]
pack $p -fill x -side bottom -padx 10 -pady 5

grid [ttk::button $p.open -text "Открыть файл результатов" -command openResults -image ::img::open -compound left] -row 0 -column 0 -sticky w
grid [ttk::button $p.stop -text "Остановить измерения" -command terminateMeasure -state disabled -image ::img::stop -compound left] -row 0 -column 1 -sticky e
grid [ttk::button $p.start -text "Начать измерения" -command startMeasure -image ::img::start -compound left] -row 0 -column 2 -sticky e

grid columnconfigure $p { 0 1 2 } -pad 10
grid columnconfigure $p { 0 } -weight 1

# Раздел "Результаты измерения"
set p [ttk::labelframe $w.nb.m.v -text " Результаты измерения " -pad 10]
pack $p -fill x -side bottom -padx 10 -pady 5

grid [ttk::label $p.lc -text "Ток, мА:"] -row 0 -column 0 -sticky w
grid [ttk::entry $p.ec -textvariable runtime(current) -state readonly] -row 0 -column 1 -sticky we

grid [ttk::label $p.lv -text "Напряжение, мВ:"] -row 0 -column 3 -sticky w
grid [ttk::entry $p.ev -textvariable runtime(voltage) -state readonly] -row 0 -column 4 -sticky we

grid [ttk::label $p.lr -text "Сопротивление, Ом:"] -row 1 -column 0 -sticky w
grid [ttk::entry $p.er -textvariable runtime(resistance) -state readonly] -row 1 -column 1 -sticky we

grid [ttk::label $p.lp -text "Мощность, мВт:"] -row 1 -column 3 -sticky w
grid [ttk::entry $p.ep -textvariable runtime(power) -state readonly] -row 1 -column 4 -sticky we

grid columnconfigure $p { 2 } -minsize 20
grid columnconfigure $p { 1 4 } -weight 1
grid rowconfigure $p { 0 1 } -pad 5

# Раздел "График"
set p [ttk::labelframe $w.nb.m.c -text " Временная зависимость " -pad 2]
pack $p -fill both -padx 10 -pady 5 -expand 1
pack [canvas $p.c -width 400 -height 200] -fill both -expand 1
#pack [canvas $p.c -background gray -width 400 -height 200] -fill both -expand 1
bind $p.c <Configure> {doResize}

# Стандартная панель
::measure::widget::std-bottom-panel $w

pack [ttk::button $w.fr.start -text "Старт" -command startThermostat -image ::img::start -compound left] -padx 5 -pady {20 5} -side left
pack [ttk::button $w.fr.stop -text "Стоп" -command stopThermostat -state disabled -image ::img::stop -compound left] -padx 5 -pady {20 5} -side left

# Читаем настройки
measure::config::read

# Запускаем модуль термостатирования
if { [measure::config::get autoStart 0] } {
	startThermostat
}

#vwait forever
thread::wait

