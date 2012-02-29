#!/usr/bin/wish

###############################################################################
# Измерительная установка № 006
# Измеряем удельное сопротивление в зависимости от температуры
#   4-х контактным методом.
# Количество одновременно измеряемых образцов: 1
# Переполюсовка напряжения и тока.
# Используется совместно с установкой-термостатом.
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
    global settings
    
    startfile::start $settings(fileName)
}

# Завершение работы программы
proc quit {} {
	# Сохраняем параметры программы
	measure::config::write

	# завершаем измерительный поток, если он запущен
	measure::interop::waitForWorkerThreads

	exit
}

# Процедура разрешает/запрещает элементы ввода эталонного сопротивления
proc toggleTestResistance {} {
	global w settings
	set p "$w.nb.ms.r.curr"
	::measure::widget::setDisabled [expr $settings(useTestResistance) == 1] $p.r $p.lr
	::measure::widget::setDisabled [expr $settings(useTestResistance) == 1] $p.rerr $p.lrerr
	::measure::widget::setDisabled [expr $settings(useTestResistance) == 2] $p.cur $p.lcur
	::measure::widget::setDisabled [expr $settings(useTestResistance) == 2] $p.curerr $p.lcurerr
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
wm title $w. "Установка № 6: Измерение УС в зависимости от температуры"

# При нажатии крестика в углу окна вызыватьспециальную процедуру завершения
wm protocol $w. WM_DELETE_WINDOW { quit }

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

# Закладка "Параметры измерения"
ttk::frame $w.nb.ms
$w.nb add $w.nb.ms -text " Параметры измерения "

grid [ttk::frame $w.nb.ms.l] -column 0 -row 0 -sticky nwe
grid [ttk::frame $w.nb.ms.r] -column 1 -row 0 -sticky nwe
grid columnconfigure $w.nb.ms { 0 1 } -weight 1

# Левая колонка

# Раздел управления питанием
set p [ttk::labelframe $w.nb.ms.l.curr -text " Управление температурой " -pad 10]

grid [ttk::label $p.lstart -text "Начальная, К:"] -row 0 -column 0 -sticky w
grid [ttk::spinbox $p.start -width 10 -textvariable settings(temp.start) -from 0 -to 1000 -increment 10 -validate key -validatecommand {string is double %P}] -row 0 -column 1 -sticky e

grid [ttk::label $p.lend -text "Конечная, К:"] -row 1 -column 0 -sticky w
grid [ttk::spinbox $p.end -width 10 -textvariable settings(temp.end) -from 0 -to 1000 -increment 10 -validate key -validatecommand {string is double %P}] -row 1 -column 1 -sticky e

grid [ttk::label $p.lstep -text "Приращение, К:"] -row 2 -column 0 -sticky w
grid [ttk::spinbox $p.step -width 10 -textvariable settings(temp.step) -from -1000 -to 1000 -increment 1 -validate key -validatecommand {string is double %P}] -row 2 -column 1 -sticky e

grid [ttk::label $p.lmaxerr -text "Пороговая ошибка, К:"] -row 3 -column 0 -sticky w
grid [ttk::spinbox $p.maxerr -width 10 -textvariable settings(temp.maxErr) -from 0 -to 10 -increment 0.1 -validate key -validatecommand {string is double %P}] -row 3 -column 1 -sticky e

grid [ttk::label $p.lmaxtrend -text "Пороговый тренд, К/мин:"] -row 4 -column 0 -sticky w
grid [ttk::spinbox $p.maxtrend -width 10 -textvariable settings(temp.maxTrend) -from 0 -to 10 -increment 0.01 -validate key -validatecommand {string is double %P}] -row 4 -column 1 -sticky e

grid columnconfigure $p {0 1} -pad 5
grid rowconfigure $p {0 1 2 3 4} -pad 5
grid columnconfigure $p { 1 } -weight 1

pack $p -fill x -padx 10 -pady 5

# Раздел настроек измерения
set p [ttk::labelframe $w.nb.ms.l.msr -text " Параметры измерения " -pad 10]

grid [ttk::label $p.lnsamples -text "Измерений на точку:"] -row 0 -column 0 -sticky w
grid [ttk::spinbox $p.nsamples -width 10 -textvariable settings(numberOfSamples) -from 1 -to 50000 -increment 10 -validate key -validatecommand {string is integer %P}] -row 0 -column 1 -sticky e

grid [ttk::label $p.lsystError -text "Игнорировать инстр. погрешность:"] -row 1 -column 0 -sticky w
grid [ttk::checkbutton $p.systError -variable settings(noSystErr)] -row 1 -column 1 -sticky e

grid columnconfigure $p {0 1} -pad 5
grid rowconfigure $p {0 1 2 3 4} -pad 5
grid columnconfigure $p { 1 } -weight 1

pack $p -fill x -padx 10 -pady 5

# Правая колонка

# Раздел настроек метода измерения тока
set p [ttk::labelframe $w.nb.ms.r.curr -text " Метод измерения тока " -pad 10]

grid [ttk::label $p.lamp -text "Амперметром:"] -row 0 -column 0 -sticky w
grid [ttk::radiobutton $p.amp -value 0 -variable settings(current.method) -command toggleTestResistance] -row 0 -column 1 -sticky e

grid [ttk::label $p.lvolt -text "Напряжением на эталоне:"] -row 1 -column 0 -sticky w
grid [ttk::radiobutton $p.volt -value 1 -variable settings(current.method) -command toggleTestResistance] -row 1 -column 1 -sticky e

grid [ttk::label $p.lr -text "Эталонное сопротивление, Ом:"] -row 2 -column 0 -sticky w
grid [ttk::spinbox $p.r -width 10 -textvariable settings(current.reference.resistance) -from 0 -to 10000000 -increment 100 -validate key -validatecommand {string is double %P}] -row 2 -column 1 -sticky e

grid [ttk::label $p.lrerr -text "Погрешность, Ом:"] -row 3 -column 0 -sticky w
grid [ttk::spinbox $p.rerr -width 10 -textvariable settings(current.reference.error) -from 0 -to 10000000 -increment 100 -validate key -validatecommand {string is double %P}] -row 3 -column 1 -sticky e

grid [ttk::label $p.lman -text "Вручную:"] -row 4 -column 0 -sticky w
grid [ttk::radiobutton $p.man -value 2 -variable settings(current.method) -command toggleTestResistance] -row 4 -column 1 -sticky e

grid [ttk::label $p.lcur -text "Сила тока, мА:"] -row 5 -column 0 -sticky w
grid [ttk::spinbox $p.cur -width 10 -textvariable settings(current.manual.current) -from 0 -to 10000000 -increment 100 -validate key -validatecommand {string is double %P}] -row 5 -column 1 -sticky e

grid [ttk::label $p.lcurerr -text "Погрешность, мА:"] -row 6 -column 0 -sticky w
grid [ttk::spinbox $p.curerr -width 10 -textvariable settings(current.manual.error) -from 0 -to 10000000 -increment 100 -validate key -validatecommand {string is double %P}] -row 6 -column 1 -sticky e

grid columnconfigure $p { 0 1 } -pad 5
grid rowconfigure $p { 0 1 2 3 4 5 } -pad 5
grid columnconfigure $p { 1 } -weight 1

pack $p -fill x -padx 10 -pady 5

grid columnconfigure $w.nb.m {0 1} -pad 5
grid rowconfigure $w.nb.m {0 1} -pad 5

# Раздел настроек переполюсовок
set p [ttk::labelframe $w.nb.ms.r.comm -text " Переполюсовки " -pad 10]

grid [ttk::label $p.lswitchVoltage -text "Переполюсовка напряжения:"] -row 1 -column 0 -sticky w
grid [ttk::checkbutton $p.switchVoltage -variable settings(switch.voltage)] -row 1 -column 1 -sticky e

grid [ttk::label $p.lswitchCurrent -text "Переполюсовка тока:"] -row 2 -column 0 -sticky w
grid [ttk::checkbutton $p.switchCurrent -variable settings(switch.current)] -row 2 -column 1 -sticky e

grid columnconfigure $p {0 1} -pad 5
grid rowconfigure $p {0 1 2 3} -pad 5
grid columnconfigure $p { 1 } -weight 1

pack $p -fill x -padx 10 -pady 5

grid columnconfigure $w.nb.m {0 1} -pad 5
grid rowconfigure $w.nb.m {0 1} -pad 5

# Раздел настроек вывода
set p [ttk::labelframe $w.nb.ms.r.msr -text " Файл результатов " -pad 10]

grid [ttk::label $p.lname -text "Имя файла: " -anchor e] -row 0 -column 0 -sticky w
grid [ttk::entry $p.name -textvariable settings(result.fileName)] -row 0 -column 1 -sticky we
grid [ttk::button $p.bname -text "Обзор..." -command "::measure::widget::fileSaveDialog $w. $p.name" -image ::img::open] -row 0 -column 2 -sticky w

grid [ttk::label $p.lformat -text "Формат файла:"] -row 2 -column 0 -sticky w
grid [ttk::combobox $p.format -width 10 -textvariable settings(result.format) -state readonly -values [list TXT CSV]] -row 2 -column 1 -columnspan 2 -sticky e

grid [ttk::label $p.lrewrite -text "Переписать файл:"] -row 3 -column 0 -sticky w
grid [ttk::checkbutton $p.rewrite -variable settings(result.rewrite)] -row 3 -column 1 -columnspan 2 -sticky e

grid columnconfigure $p {0 1} -pad 5
grid rowconfigure $p {0 1 2 3} -pad 5
grid columnconfigure $p { 1 } -weight 1

pack $p -fill x -padx 10 -pady 5

grid columnconfigure $w.nb.m {0 1} -pad 5
grid rowconfigure $w.nb.m {0 1} -pad 5

# Закладка "Параметры установки"
ttk::frame $w.nb.setup
$w.nb add $w.nb.setup -text " Параметры установки "

set p [ttk::labelframe $w.nb.setup.switch -text " Блок реле " -pad 10]
pack $p -fill x -padx 10 -pady 5

grid [ttk::label $p.lrs485 -text "Порт для АС4:"] -row 0 -column 0 -sticky w
grid [ttk::combobox $p.rs485 -width 10 -textvariable settings(switch.serialAddr) -values [measure::com::allPorts]] -row 0 -column 1 -sticky w

grid [ttk::label $p.lswitchAddr -text "Сетевой адрес МВУ-8:"] -row 0 -column 2 -sticky w
grid [ttk::spinbox $p.switchAddr -width 10 -textvariable settings(switch.rs485Addr) -from 1 -to 2040 -validate key -validatecommand {string is integer %P}] -row 0 -column 3 -sticky w

grid columnconfigure $p { 0 1 2 3 } -pad 5
grid columnconfigure $p { 1 3 } -weight 1
grid rowconfigure $p { 0 1 } -pad 5

set p [ttk::labelframe $w.nb.setup.mm -text " Вольтметр на образце " -pad 10]
pack $p -fill x -padx 10 -pady 5

::measure::widget::mmControls $p mm

set p [ttk::labelframe $w.nb.setup.cmm -text " Амперметр/вольтметр на эталоне " -pad 10]
pack $p -fill x -padx 10 -pady 5

::measure::widget::mmControls $p cmm

set p [ttk::labelframe $w.nb.setup.m -text " Общие параметры " -pad 10]
pack $p -fill x -padx 10 -pady 5

grid [ttk::label $p.lbeepOnExit -text "Звуковой сигнал по окончании:"] -row 7 -column 0 -sticky w
grid [ttk::checkbutton $p.beepOnExit -variable settings(beepOnExit)] -row 7 -column 1 -sticky w

grid columnconfigure $p { 0 1 } -pad 5
grid columnconfigure $p { 1 } -weight 1
grid rowconfigure $p { 0 1 2 3 4 5 6 7 8 } -pad 5

# Стандартная панель
::measure::widget::std-bottom-panel $w

# Читаем настройки
measure::config::read

# Настраиваем элементы управления
toggleTestResistance

# Запускаем тестер
startTester

#vwait forever
thread::wait
