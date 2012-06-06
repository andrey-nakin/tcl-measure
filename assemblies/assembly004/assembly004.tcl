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

# Процедура разрешает/запрещает элементы управления током
proc togglePowerControls { } {
	global w
	set p "$w.nb.ms.l.curr"
	::measure::widget::setDisabledByVarInv settings(manualPower) $p.start $p.lstart $p.lend $p.end $p.step $p.lstep
}

# Процедура разрешает/запрещает элементы ввода эталонного сопротивления
proc toggleTestResistance {} {
	global w
	set p "$w.nb.ms.r.curr"
	set mode [measure::config::get current.method 0]
	::measure::widget::setDisabled [expr $mode == 1] $p.r $p.lr
	::measure::widget::setDisabled [expr $mode == 1] $p.rerr $p.lrerr
	::measure::widget::setDisabled [expr $mode == 2] $p.cur $p.lcur
	::measure::widget::setDisabled [expr $mode == 2] $p.curerr $p.lcurerr
}

proc addValueToChart { v } {
	global canvas log

	lassign [::measure::chart::${canvas}::getYStat] mean _ _ n
	if { $n >= 5 && $mean/$v > 100.0 } {
    	measure::chart::${canvas}::clear
    }
	measure::chart::${canvas}::addPoint $v
}

###############################################################################
# Начало скрипта
###############################################################################

set log [measure::logger::init measure]
measure::logger::server

# Создаём окно программы
set w ""
wm title $w. "Установка № 4: Измерение R(I)"

# При нажатии крестика в углу окна вызыватьспециальную процедуру завершения
wm protocol $w. WM_DELETE_WINDOW { quit }

# Панель закладок
ttk::notebook $w.nb
pack $w.nb -fill both -expand 1 -padx 2 -pady 3
ttk::notebook::enableTraversal $w.nb

# Закладка "Измерение"
ttk::frame $w.nb.m
$w.nb add $w.nb.m -text " Измерение "

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
set canvas [canvas $p.c -width 400 -height 200]
pack $canvas -fill both -expand 1
place [ttk::button $p.cb -text "Очистить" -command "measure::chart::${canvas}::clear"] -anchor ne -relx 1.0 -rely 0.0
measure::chart::movingChart -ylabel "R, Ом" -xpoints 100 $canvas

# Закладка "Параметры измерения"
ttk::frame $w.nb.ms
$w.nb add $w.nb.ms -text " Параметры измерения "

grid [ttk::frame $w.nb.ms.l] -column 0 -row 0 -sticky nwe
grid [ttk::frame $w.nb.ms.r] -column 1 -row 0 -sticky nwe
grid [ttk::frame $w.nb.ms.b] -column 0 -columnspan 2 -row 1 -sticky we
grid columnconfigure $w.nb.ms { 0 1 } -weight 1

# Левая колонка

# Раздел управления питанием
set p [ttk::labelframe $w.nb.ms.l.curr -text " Питание образца " -pad 10]

grid [ttk::label $p.lmanualPower -text "Ручное управление:"] -row 0 -column 0 -sticky w
grid [ttk::checkbutton $p.manualPower -variable settings(manualPower) -command togglePowerControls] -row 0 -column 1 -sticky e

grid [ttk::label $p.lstart -text "Начальный ток, мА:"] -row 1 -column 0 -sticky w
grid [ttk::spinbox $p.start -width 10 -textvariable settings(startCurrent) -from 0 -to 2200 -increment 10 -validate key -validatecommand {string is double %P}] -row 1 -column 1 -sticky e

grid [ttk::label $p.lend -text "Конечный ток, мА:"] -row 2 -column 0 -sticky w
grid [ttk::spinbox $p.end -width 10 -textvariable settings(endCurrent) -from 0 -to 2200 -increment 10 -validate key -validatecommand {string is double %P}] -row 2 -column 1 -sticky e

grid [ttk::label $p.lstep -text "Приращение, мА:"] -row 3 -column 0 -sticky w
grid [ttk::spinbox $p.step -width 10 -textvariable settings(currentStep) -from -2200 -to 2200 -increment 10 -validate key -validatecommand {string is double %P}] -row 3 -column 1 -sticky e

grid columnconfigure $p {0 1} -pad 5
grid rowconfigure $p {0 1 2 3} -pad 5
grid columnconfigure $p { 1 } -weight 1

pack $p -fill x -padx 10 -pady 5

# Раздел настроек измерения
set p [ttk::labelframe $w.nb.ms.l.msr -text " Параметры измерения " -pad 10]

grid [ttk::label $p.lnsamples -text "Измерений на точку:"] -row 1 -column 0 -sticky w
grid [ttk::spinbox $p.nsamples -width 10 -textvariable settings(measure.numOfSamples) -from 1 -to 50000 -increment 10 -validate key -validatecommand {string is integer %P}] -row 1 -column 1 -sticky e

grid [ttk::label $p.lsystError -text "Игнорировать инстр. погрешность:"] -row 2 -column 0 -sticky w
grid [ttk::checkbutton $p.systError -variable settings(measure.noSystErr)] -row 2 -column 1 -sticky e

grid columnconfigure $p {0 1} -pad 5
grid rowconfigure $p {0 1 2 3 4} -pad 5
grid columnconfigure $p { 1 } -weight 1

pack $p -fill x -padx 10 -pady 5

# Раздел настроек вывода
set p [ttk::labelframe $w.nb.ms.b.res -text " Файл результатов " -pad 10]

grid [ttk::label $p.lname -text "Имя файла: " -anchor e] -row 0 -column 0 -sticky w
grid [ttk::entry $p.name -textvariable settings(fileName)] -row 0 -column 1 -columnspan 4 -sticky we

grid [ttk::label $p.lformat -text "Формат файлов:"] -row 3 -column 0 -sticky w
grid [ttk::combobox $p.format -width 10 -textvariable settings(fileFormat) -state readonly -values [list TXT CSV]] -row 3 -column 1 -columnspan 2 -sticky w

grid [ttk::label $p.lrewrite -text "Переписать файлы:"] -row 3 -column 3 -sticky e
grid [ttk::checkbutton $p.rewrite -variable settings(fileRewrite)] -row 3 -column 4 -sticky e

grid [ttk::label $p.lcomment -text "Комментарий: " -anchor e] -row 4 -column 0 -sticky w
grid [ttk::entry $p.comment -textvariable settings(fileComment)] -row 4 -column 1 -columnspan 4 -sticky we

grid columnconfigure $p {0 1} -pad 5
grid rowconfigure $p {0 1 2 3 4} -pad 5
grid columnconfigure $p { 1 } -weight 1

pack $p -fill x -padx 10 -pady 5

# Правая колонка

# Раздел настроек метода измерения тока
set p [ttk::labelframe $w.nb.ms.r.curr -text " Метод измерения сопротивления " -pad 10]
pack $p -fill x -padx 10 -pady 5
measure::widget::resistanceMethodControls $p current

grid columnconfigure $w.nb.m {0 1} -pad 5
grid rowconfigure $w.nb.m {0 1} -pad 5

# Раздел настроек переполюсовок
set p [ttk::labelframe $w.nb.ms.r.comm -text " Переполюсовки " -pad 10]
pack $p -fill x -padx 10 -pady 5
::measure::widget::switchControls $p "switch"

grid columnconfigure $w.nb.m {0 1} -pad 5
grid rowconfigure $w.nb.m {0 1} -pad 5

grid columnconfigure $w.nb.m {0 1} -pad 5
grid rowconfigure $w.nb.m {0 1} -pad 5

# Закладка "Образец"
ttk::frame $w.nb.dut
$w.nb add $w.nb.dut -text " Образец "

# Настройки параметров образца
set p [ttk::labelframe $w.nb.dut.dut -text " Параметры образца " -pad 10]
pack $p -fill x -padx 10 -pady 5
::measure::widget::dutControls $p dut

# Закладка "Параметры установки"
ttk::frame $w.nb.setup
$w.nb add $w.nb.setup -text " Параметры установки "

set p [ttk::labelframe $w.nb.setup.switch -text " Блок реле " -pad 10]
pack $p -fill x -padx 10 -pady 5
::measure::widget::mvu8Controls $p "switch"

set p [ttk::labelframe $w.nb.setup.ps -text " Источник тока " -pad 10]
pack $p -fill x -padx 10 -pady 5
::measure::widget::psControls $p ps

set p [ttk::labelframe $w.nb.setup.mm -text " Вольтметр/омметр на образце " -pad 10]
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
togglePowerControls
toggleTestResistance

# Запускаем тестер
startTester

#vwait forever
thread::wait

