#!/usr/bin/wish

###############################################################################
# Измерительная установка № 004
# Измеряем удельное сопротивление с варьированием тока, протекающего через 
#   образец, при постоянной температуре 4-х контактным методом.
# Количество одновременно измеряемых образцов: 1
# Переполюсовка напряжения и тока.
# Сила тока измеряется через падение напряжения на эталонном сопротивлении.
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
package require startfile
package require hardware::agilent::mm34410a

###############################################################################
# Константы
###############################################################################

###############################################################################
# Процедуры
###############################################################################

# Очищаем поля с результатами измерений
proc clearResults {} {
	global runtime

	set runtime(current) ""
	set runtime(voltage) ""
	set runtime(resistance) ""
	set runtime(power) ""
}

# Запускаем тестовый модуль
proc startTester {} {
	# Сохраняем параметры программы
	measure::config::write

    # Очищаем результаты в окне программы
	clearResults

    # Сбрасываем сигнал "прерван"
    measure::interop::clearTerminated

	# Запускаем на выполнение фоновый поток	с процедурой измерения
	measure::interop::startWorker [list source [file join [file dirname [info script]] tester.tcl] ] {} {}
}

# Прерываем работу тестового модуля
proc terminateTester {} {
	# Посылаем в измерительный поток сигнал об останове
	measure::interop::waitForWorkerThreads
}

# Процедура вызываеися из фонового рабочего потока по завершении его работы
proc stopMeasure {} {
	global w log

	# Запускаем тестер
	startTester

	# разрешаем кнопку запуска измерений
	$w.nb.m.ctl.start configure -state normal
     
    # Запрещаем кнопку останова измерений    
	$w.nb.m.ctl.stop configure -state disabled
}

# Запускаем измерения
proc startMeasure {} {
	global w log runtime

	# запрещаем кнопку запуска измерений
	$w.nb.m.ctl.start configure -state disabled

	# Останавливаем работу тестера
	terminateTester

	# Сохраняем параметры программы
	measure::config::write

    # Сбрасываем сигнал "прерван"
    measure::interop::clearTerminated
    
	# Запускаем на выполнение фоновый поток	с процедурой измерения
	measure::interop::startWorker [list source [file join [file dirname [info script]] measure.tcl] ] { stopMeasure }

    # Разрешаем кнопку останова измерений
	$w.nb.m.ctl.stop configure -state normal
	
    # Очищаем результаты в окне программы
	clearResults
}

# Прерываем измерения
proc terminateMeasure {} {
    global w log

    # Запрещаем кнопку останова измерений    
	$w.nb.m.ctl.stop configure -state disabled
	
	# Посылаем в измерительный поток сигнал об останове
	measure::interop::terminate
}

# Открываем файл с результами измерения
proc openResults {} {
    global measure
    
    startfile::start $measure(fileName)
}

# Завершение работы программы
proc quit {} {
	# Сохраняем параметры программы
	measure::config::write

	# завершаем измерительный поток, если он запущен
	measure::interop::waitForWorkerThreads

	exit
}

proc setDisabledInverse { value args } {
	foreach ctrl $args {
		if { $value } {
			$ctrl configure -state disabled
		} else {
			$ctrl configure -state normal
		}
	}
}

proc togglePowerControls { } {
	global settings w

	set p "$w.nb.ms.l.curr"
	setDisabledInverse $settings(manualPower) $p.start $p.lstart $p.lend $p.end $p.step $p.lstep
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
wm title $w. "Установка № 4: Измерение УС"

# Панель закладок
ttk::notebook $w.nb
pack $w.nb -fill both -expand 1 -padx 2 -pady 3
ttk::notebook::enableTraversal $w.nb

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
	set max [lindex $stats 2]
	if { $max <= 0 } {
		set max 1
	}
	set limit [expr 10 ** int(log10($max) + 1)]
	if { $max < $limit / 2 } {
		set max [expr $limit / 2]
	} else {
		set max $limit
	}
	set s [::Plotchart::createXYPlot $w.nb.m.c.c { 0 200 20 } [list 0 $max [expr 0.2 * $max]]]

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

# Закладка "Параметры измерения"
ttk::frame $w.nb.ms
$w.nb add $w.nb.ms -text " Параметры измерения "

grid [ttk::frame $w.nb.ms.l] -column 0 -row 0 -sticky nwe
grid [ttk::frame $w.nb.ms.r] -column 1 -row 0 -sticky nwe
grid columnconfigure $w.nb.ms { 0 1 } -weight 1

# Левая колонка

# Раздел управления питанием
set p [ttk::labelframe $w.nb.ms.l.curr -text " Питание образца " -pad 10]

grid [ttk::label $p.lmanualPower -text "Ручное управление:"] -row 0 -column 0 -sticky w
grid [ttk::checkbutton $p.manualPower -variable settings(manualPower) -command togglePowerControls] -row 0 -column 1 -sticky w
bind $p.manualPower <Configure> {doResize}

grid [ttk::label $p.lstart -text "Начальный ток, мА:"] -row 1 -column 0 -sticky w
grid [ttk::spinbox $p.start -textvariable measure(startCurrent) -from 0 -to 2200 -increment 10 -validate key -validatecommand {string is double %P}] -row 1 -column 1 -sticky we

grid [ttk::label $p.lend -text "Конечный ток, мА:"] -row 2 -column 0 -sticky w
grid [ttk::spinbox $p.end -textvariable measure(endCurrent) -from 0 -to 2200 -increment 10 -validate key -validatecommand {string is double %P}] -row 2 -column 1 -sticky we

grid [ttk::label $p.lstep -text "Приращение, мА:"] -row 3 -column 0 -sticky w
grid [ttk::spinbox $p.step -textvariable measure(currentStep) -from -2200 -to 2200 -increment 10 -validate key -validatecommand {string is double %P}] -row 3 -column 1 -sticky we

grid columnconfigure $p {0 1} -pad 5
grid rowconfigure $p {0 1 2 3} -pad 5
grid columnconfigure $p { 1 } -weight 1

pack $p -fill x -padx 10 -pady 5

# Раздел настроек измерения
set p [ttk::labelframe $w.nb.ms.l.msr -text " Параметры измерения " -pad 10]

grid [ttk::label $p.lnplc -text "Циклов 50 Гц на измерение:"] -row 0 -column 0 -sticky w
grid [ttk::combobox $p.nplc -textvariable settings(nplc) -state readonly -values $hardware::agilent::mm34410a::nplcs ] -row 0 -column 1 -sticky we

grid [ttk::label $p.lnsamples -text "Измерений на точку:"] -row 1 -column 0 -sticky w
grid [ttk::spinbox $p.nsamples -textvariable measure(numberOfSamples) -from 1 -to 50000 -increment 10 -validate key -validatecommand {string is integer %P}] -row 1 -column 1 -sticky we

grid [ttk::label $p.lswitchVoltage -text "Переполюсовка напряжения:"] -row 2 -column 0 -sticky w
grid [ttk::checkbutton $p.switchVoltage -variable measure(switchVoltage)] -row 2 -column 1 -sticky w

grid [ttk::label $p.lswitchCurrent -text "Переполюсовка тока:"] -row 3 -column 0 -sticky w
grid [ttk::checkbutton $p.switchCurrent -variable measure(switchCurrent)] -row 3 -column 1 -sticky w

grid [ttk::label $p.lsystError -text "Игнорировать инстр. погрешность:"] -row 4 -column 0 -sticky w
grid [ttk::checkbutton $p.systError -variable settings(noSystErr)] -row 4 -column 1 -sticky w

grid columnconfigure $p {0 1} -pad 5
grid rowconfigure $p {0 1 2 3 4} -pad 5
grid columnconfigure $p { 1 } -weight 1

pack $p -fill x -padx 10 -pady 5

# Правая колонка

# Раздел настроек вывода
set p [ttk::labelframe $w.nb.ms.r.msr -text " Файл результатов " -pad 10]

grid [ttk::label $p.lname -text "Имя файла: " -anchor e] -row 0 -column 0 -sticky w
grid [ttk::entry $p.name -textvariable measure(fileName)] -row 0 -column 1 -sticky we
grid [ttk::button $p.bname -text "Обзор..." -command "::measure::widget::fileSaveDialog $w. $p.name" -image ::img::open] -row 0 -column 2 -sticky w

grid [ttk::label $p.lformat -text "Формат файла:"] -row 2 -column 0 -sticky w
grid [ttk::combobox $p.format -textvariable measure(fileFormat) -state readonly -values [list TXT CSV]] -row 2 -column 1 -columnspan 2 -sticky we

grid [ttk::label $p.lrewrite -text "Переписать файл:"] -row 3 -column 0 -sticky w
grid [ttk::checkbutton $p.rewrite -variable measure(fileRewrite)] -row 3 -column 1 -sticky w

grid columnconfigure $p {0 1} -pad 5
grid rowconfigure $p {0 1 2 3} -pad 5
grid columnconfigure $p { 1 } -weight 1

pack $p -fill x -padx 10 -pady 5

grid columnconfigure $w.nb.m {0 1} -pad 5
grid rowconfigure $w.nb.m {0 1} -pad 5

# Закладка "Параметры установки"
ttk::frame $w.nb.setup
$w.nb add $w.nb.setup -text " Параметры установки "

set p [ttk::labelframe $w.nb.setup.m -text " Общие параметры " -pad 10]
pack $p -fill x -padx 10 -pady 5

grid [ttk::label $p.lrs485 -text "Порт для АС4:"] -row 0 -column 0 -sticky w
grid [ttk::combobox $p.rs485 -width 40 -textvariable settings(rs485Port) -values [measure::com::allPorts]] -row 0 -column 1 -sticky we

grid [ttk::label $p.lswitchAddr -text "Сетевой адрес МВУ-8:"] -row 1 -column 0 -sticky w
grid [ttk::spinbox $p.switchAddr -width 40 -textvariable settings(switchAddr) -from 1 -to 2040 -width 10 -validate key -validatecommand {string is integer %P}] -row 1 -column 1 -sticky we

grid [ttk::label $p.lps -text "VISA адрес источника питания:"] -row 2 -column 0 -sticky w
grid [ttk::combobox $p.ps -width 40 -textvariable settings(psAddr) -values [measure::visa::allInstruments]] -row 2 -column 1 -sticky we

grid [ttk::label $p.lmm -text "VISA адрес вольтметра на образце:"] -row 4 -column 0 -sticky w
grid [ttk::combobox $p.mm -width 40 -textvariable settings(mmAddr) -values [measure::visa::allInstruments]] -row 4 -column 1 -sticky we

grid [ttk::label $p.lcmm -text "VISA адрес вольтметра на эталоне:"] -row 5 -column 0 -sticky w
grid [ttk::combobox $p.cmm -width 40 -textvariable settings(cmmAddr) -values [measure::visa::allInstruments]] -row 5 -column 1 -sticky we

grid [ttk::label $p.lbeepOnExit -text "Звуковой сигнал по окончании:"] -row 7 -column 0 -sticky w
grid [ttk::checkbutton $p.beepOnExit -variable settings(beepOnExit)] -row 7 -column 1 -sticky w

grid columnconfigure $p { 0 1 } -pad 5
grid columnconfigure $p { 1 } -weight 1
grid rowconfigure $p { 0 1 2 3 4 5 6 7 8 } -pad 5

# Кнопка закрытия приложения
::measure::widget::exit-button $w

# Читаем настройки
measure::config::read

# Настраиваем элементы управления
togglePowerControls

# Запускаем тестер
startTester

#vwait forever
thread::wait

