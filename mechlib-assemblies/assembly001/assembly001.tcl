#!/usr/bin/wish

###############################################################################
# Измерительная установка № 008
# Измеряем деформацию и напряжение в скручиваемом образце
# Количество одновременно измеряемых образцов: 1
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
package require measure::datafile
package require measure::format
package require startfile
package require hardware::agilent::mm34410a
package require measure::widget::fullscreen

###############################################################################
# Константы
###############################################################################

###############################################################################
# Процедуры
###############################################################################

# Очищаем поля с результатами измерений
proc clearResults {} {
    global runtime chartTau_gamma chartT_t chartGamma_T chartTau_T

	set runtime(phi1) ""
	set runtime(phi2) ""
	set runtime(tau) ""
	set runtime(gamma) ""
	set runtime(temperature) ""

	measure::chart::${chartT_t}::clear
   	measure::chart::${chartTau_gamma}::clear
   	measure::chart::${chartGamma_T}::clear
   	measure::chart::${chartTau_T}::clear
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
	global w log workerId

	unset workerId

	# Запускаем тестер
	startTester

	# разрешаем кнопку запуска измерений
	$w.nb.m.ctl.start configure -state normal
     
    # Запрещаем кнопку останова измерений    
	$w.nb.m.ctl.stop configure -state disabled
	$w.nb.m.ctl.measure configure -state disabled
}

# Запускаем измерения
proc startMeasure {} {
	global w log runtime chartTau_gamma workerId

	# запрещаем кнопку запуска измерений
	$w.nb.m.ctl.start configure -state disabled

	# Останавливаем работу тестера
	terminateTester

	# Сохраняем параметры программы
	measure::config::write

    # Сбрасываем сигнал "прерван"
    measure::interop::clearTerminated
    
	# Запускаем на выполнение фоновый поток	с процедурой измерения
	set workerId [measure::interop::startWorker [list source [file join [file dirname [info script]] measure.tcl] ] { stopMeasure } ]

    # Разрешаем кнопку останова измерений
	$w.nb.m.ctl.stop configure -state normal
	$w.nb.m.ctl.measure configure -state normal
	
    # Очищаем результаты в окне программы
	clearResults

	# Очищаем график
	measure::chart::${chartTau_gamma}::clear
}

# Прерываем измерения
proc terminateMeasure {} {
    global w log

    # Запрещаем кнопку останова измерений    
	$w.nb.m.ctl.stop configure -state disabled
	$w.nb.m.ctl.measure configure -state disabled
	
	# Посылаем в измерительный поток сигнал об останове
	measure::interop::terminate
}

# Открываем файл с результами измерения
proc openResults {} {
    global settings

	if { [info exists settings(result.fileName)] } {
	    set fn [::measure::datafile::parseFileName $settings(result.fileName)]
	    if { [file exists $fn] } {
    	    startfile::start $fn
        }
	}
}

# Завершение работы программы
proc quit {} {
	# Сохраняем параметры программы
	::measure::config::write

	# завершаем измерительный поток, если он запущен
	::measure::interop::waitForWorkerThreads

    # останавливаем поток записи данных
    ::measure::datafile::shutdown
     
    # останавливаем поток протоколирования
	::measure::logger::shutdown

	exit
}

# Процедура разрешает/запрещает элементы ввода эталонного сопротивления
proc toggleProgControls {} {
	global w
	set p "$w.nb.ms.l.prog"
	set mode [measure::config::get prog.method 0]
	::measure::widget::setDisabled [expr $mode == 0] $p.timeStep
	::measure::widget::setDisabled [expr $mode == 1] $p.tempStep
}

proc changeMeasureMethod {} {
	set mode [measure::config::get measure.method 0]
# TODO
}

proc makeMeasurement {} {
	global workerId

	if { [info exists workerId] } {
		thread::send -async $workerId makeMeasurement
	}
}

proc testLir916Impl { lir btn } {
    global settings
	package require hardware::skbis::lir916

	if { [catch {
		set res [::hardware::skbis::lir916::test -com $settings(rs485.serialPort) -addr $settings(${lir}.addr) -baud $settings(${lir}.baud)]
	} ] } {
		set res 0
	}

	if { $res > 0 } {
		tk_messageBox -icon info -type ok -title "\u041E\u043F\u0440\u043E\u0441" -parent . -message "\u0421\u0432\u044F\u0437\u044C \u0443\u0441\u0442\u0430\u043D\u043E\u0432\u043B\u0435\u043D\u0430"
	} elseif { $res == 0} {
		tk_messageBox -icon error -type ok -title "\u041E\u043F\u0440\u043E\u0441" -parent . -message "\u041D\u0435\u0442 \u0441\u0432\u044F\u0437\u0438"
	} else {
		tk_messageBox -icon error -type ok -title "\u041E\u043F\u0440\u043E\u0441" -parent . -message "\u423\u441\u442\u440\u43E\u439\u441\u442\u432\u43E \u43D\u435 \u44F\u432\u43B\u44F\u435\u442\u441\u44F \u438\u441\u442\u43E\u447\u43D\u438\u43A\u43E\u43C \u43F\u438\u442\u430\u43D\u438\u44F Agilent E3645A \u438\u43B\u438 \u430\u43D\u430\u43B\u43E\u433\u43E\u43C"
	}
    $btn configure -state enabled
} 

proc testLir916 { lir btn } {
    $btn configure -state disabled
	after 100 [list testLir916Impl $lir $btn]
}

###############################################################################
# Обработчики событий
###############################################################################

proc display { phi1 phi1Err phi2 phi2Err temp tempErr tempDer gamma gammaErr tau tauErr write } {
    global runtime chartTau_gamma chartGamma_T chartTau_T chartT_t w
    
    # Выводим результаты в окно программы
	set runtime(phi1) [::measure::format::valueWithErr -noScale -- $phi1 $phi1Err ""]
	set runtime(phi2) [::measure::format::valueWithErr -noScale -- $phi2 $phi2Err ""]
	set runtime(gamma) [::measure::format::valueWithErr -noScale -- $gamma $gammaErr ""]
	set runtime(tau) [::measure::format::valueWithErr -noScale -mult 1.0e-6 -- $tau $tauErr ""]
	set runtime(temperature) [::measure::format::valueWithErr -- $temp $tempErr ""]

    measure::chart::${chartT_t}::addPoint $temp

	set tau [expr 1.0e-6 * $tau]
	if { $write } {
    	measure::chart::${chartTau_gamma}::addPoint $gamma $tau result
    	measure::chart::${chartGamma_T}::addPoint $temp $gamma result
    	measure::chart::${chartTau_T}::addPoint $temp $tau result
    } else {
    	measure::chart::${chartTau_gamma}::addPoint $gamma $tau test
    	measure::chart::${chartGamma_T}::addPoint $temp $gamma test
    	measure::chart::${chartTau_T}::addPoint $temp $tau test
    }

	event generate ${w}. <<ReadTemperature>> -data $temp
}

###############################################################################
# Начало скрипта
###############################################################################

set log [measure::logger::init measure]
# запускаем выделенный поток протоколирования
::measure::logger::server

# запускаем выделенный поток записи данных
::measure::datafile::startup

# Создаём окно программы
set w ""
wm title $w. "Установка № 1: измерение деформации и напряжения. Версия 1.0.0"

# При нажатии крестика в углу окна вызыватьспециальную процедуру завершения
wm protocol $w. WM_DELETE_WINDOW { quit }

# Виртуальное событие, генерируемое при каждом чтении температуры
event add <<ReadTemperature>> <Control-p>

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

grid [ttk::button $p.measure -text "Снять точку" -state disabled -command makeMeasurement -image ::img::next -compound left] -row 0 -column 0 -sticky w
grid [ttk::button $p.stop -text "Остановить запись" -command terminateMeasure -state disabled -image ::img::stop -compound left] -row 0 -column 3 -sticky e
grid [ttk::button $p.start -text "Начать запись" -command startMeasure -image ::img::start -compound left] -row 0 -column 4 -sticky e

grid columnconfigure $p { 1 3 4 } -pad 10
grid columnconfigure $p { 0 2 } -pad 50
grid columnconfigure $p { 1 } -weight 1
grid rowconfigure $p { 0 1 } -pad 5

# Раздел "Результаты измерения"
set p [ttk::labelframe $w.nb.m.v -text " Результаты измерения " -pad 10]
pack $p -fill x -side bottom -padx 10 -pady 5

grid [ttk::label $p.lc -text "φ1, град:"] -row 0 -column 0 -sticky w
grid [ttk::entry $p.ec -textvariable runtime(phi1) -state readonly] -row 0 -column 1 -sticky we

grid [ttk::label $p.lv -text "φ2, град:"] -row 0 -column 3 -sticky w
grid [ttk::entry $p.ev -textvariable runtime(phi2) -state readonly] -row 0 -column 4 -sticky we

grid [ttk::label $p.lt -text "Напряжение γ, %:"] -row 1 -column 0 -sticky w
grid [ttk::entry $p.et -textvariable runtime(gamma) -state readonly] -row 1 -column 1 -sticky we

grid [ttk::label $p.lder -text "Деформация τ, МПа:"] -row 1 -column 3 -sticky w
grid [ttk::entry $p.eder -textvariable runtime(tau) -state readonly] -row 1 -column 4 -sticky we

grid [ttk::label $p.lr -text "T, К:"] -row 1 -column 6 -sticky w
grid [ttk::entry $p.er -textvariable runtime(temperature) -state readonly] -row 1 -column 7 -sticky we

grid columnconfigure $p { 0 1 3 4 5 6 7 8 9 10 } -pad 5
grid columnconfigure $p { 2 5 8 } -minsize 20
grid columnconfigure $p { 1 4 7 } -weight 1
grid rowconfigure $p { 0 1 2 3 } -pad 5

# Раздел "График"
set p [ttk::labelframe $w.nb.m.c -text " Оперативный контроль " -pad 2]
pack $p -fill both -padx 10 -pady 5 -expand 1

set chartT_t [canvas $p.t_t -width 200 -height 200]
grid $chartT_t -row 0 -column 0 -sticky news
measure::chart::movingChart -ylabel "T, К" -linearTrend $chartT_t

set chartTau_gamma [canvas $p.r_T -width 200 -height 200]
grid $chartTau_gamma -row 0 -column 1 -sticky news
measure::chart::staticChart -xlabel "Напряжение γ, %" -ylabel "τ, МПа" -dots 1 -lines 1 $chartTau_gamma
measure::chart::${chartTau_gamma}::series test -order 1 -maxCount 10 -color #7f7fff
measure::chart::${chartTau_gamma}::series result -order 2 -maxCount 200 -thinout -color green

set chartGamma_T [canvas $p.gamma_T -width 200 -height 200]
grid $chartGamma_T -row 1 -column 0 -sticky news
measure::chart::staticChart -xlabel "Температура T, К" -ylabel "γ, %" -dots 1 -lines 1 $chartGamma_T
measure::chart::${chartGamma_T}::series test -order 1 -maxCount 10 -color #7f7fff
measure::chart::${chartGamma_T}::series result -order 2 -maxCount 200 -thinout -color green

set chartTau_T [canvas $p.tau_T -width 200 -height 200]
grid $chartTau_T -row 1 -column 1 -sticky news
measure::chart::staticChart -xlabel "Температура T, К" -ylabel "τ, МПа" -dots 1 -lines 1 $chartTau_T
measure::chart::${chartTau_T}::series test -order 1 -maxCount 10 -color #7f7fff
measure::chart::${chartTau_T}::series result -order 2 -maxCount 200 -thinout -color green

grid columnconfigure $p { 0 1 } -weight 1
grid rowconfigure $p { 0 1 } -weight 1

place [ttk::button $p.cb -text "Очистить" -command clearResults] -anchor ne -relx 1.0 -rely 0.0

# Закладка "Параметры измерения"
ttk::frame $w.nb.ms
$w.nb add $w.nb.ms -text " Параметры измерения "

grid [ttk::frame $w.nb.ms.l] -column 0 -row 0 -sticky nwe
grid [ttk::frame $w.nb.ms.r] -column 1 -row 0 -sticky nwe
grid [ttk::frame $w.nb.ms.b] -column 0 -columnspan 2 -row 1 -sticky we

grid columnconfigure $w.nb.ms { 0 1 } -weight 1

# Левая колонка

# Настройки способа регистрации
set p [ttk::labelframe $w.nb.ms.l.prog -text " Метод регистрации " -pad 10]

grid [ttk::label $p.ltime -text "Временная зависимость:"] -row 0 -column 0 -sticky w
grid [ttk::radiobutton $p.time -value 0 -variable settings(prog.method) -command toggleProgControls] -row 0 -column 1 -sticky e

grid [ttk::label $p.ltimeStep -text "  Временной шаг, мс:"] -row 1 -column 0 -sticky w
grid [ttk::spinbox $p.timeStep -width 10 -textvariable settings(prog.time.step) -from 0 -to 1000000 -increment 100 -validate key -validatecommand {string is double %P}] -row 1 -column 1 -sticky e

grid [ttk::label $p.ltemp -text "Температурная зависимость:"] -row 2 -column 0 -sticky w
grid [ttk::radiobutton $p.temp -value 1 -variable settings(prog.method) -command toggleProgControls] -row 2 -column 1 -sticky e

grid [ttk::label $p.ltempStep -text "  Температурный шаг, К:"] -row 3 -column 0 -sticky w
grid [ttk::spinbox $p.tempStep -width 10 -textvariable settings(prog.temp.step) -from 0 -to 1000 -increment 1 -validate key -validatecommand {string is double %P}] -row 3 -column 1 -sticky e

grid [ttk::label $p.lman -text "Вручную:"] -row 4 -column 0 -sticky w
grid [ttk::radiobutton $p.man -value 2 -variable settings(prog.method) -command toggleProgControls] -row 4 -column 1 -sticky e

grid columnconfigure $p {0 1} -pad 5
grid rowconfigure $p {0 1 2 3 4} -pad 5
grid columnconfigure $p { 1 } -weight 1

pack $p -fill x -padx 10 -pady 5

# Правая колонка

set p [ttk::labelframe $w.nb.ms.r.measure -text " Метод измерения " -pad 10]

grid [ttk::label $p.ltime -text "Динамический момент:"] -row 0 -column 0 -sticky w
grid [ttk::radiobutton $p.dynamic -value 0 -variable settings(measure.method) -command changeMeasureMethod] -row 0 -column 1 -sticky e

grid [ttk::label $p.ltemp -text "Постоянный момент:"] -row 1 -column 0 -sticky w
grid [ttk::radiobutton $p.const -value 1 -variable settings(measure.method) -command changeMeasureMethod] -row 1 -column 1 -sticky e

grid columnconfigure $p {0 1} -pad 5
grid rowconfigure $p {0 1 2 3 4} -pad 5
grid columnconfigure $p { 1 } -weight 1

pack $p -fill x -padx 10 -pady 5

# Закладка "Образец"
ttk::frame $w.nb.dut
$w.nb add $w.nb.dut -text " Образец "

# Настройки параметров образца
set p [ttk::labelframe $w.nb.dut.dut -text " Геометрические параметры " -pad 10]
pack $p -fill x -padx 10 -pady 5

grid [ttk::label $p.llen -text "\u0414\u043B\u0438\u043D\u0430, \u043C\u043C:"] -row 0 -column 0 -sticky w
grid [ttk::spinbox $p.len -width 10 -textvariable settings(dut.length) -from 0 -to 1000 -increment 1 -validate key -validatecommand {string is double %P}] -row 0 -column 1 -sticky e
grid [ttk::label $p.llene -text "\u00b1"] -row 0 -column 2 -sticky e
grid [ttk::spinbox $p.lene -width 10 -textvariable settings(dut.lengthErr) -from 0 -to 100 -increment 0.1 -validate key -validatecommand {string is double %P}] -row 0 -column 3 -sticky e

grid [ttk::label $p.lr -text "\u0420\u0430\u0434\u0438\u0443\u0441, \u043C\u043C:"] -row 1 -column 0 -sticky w
grid [ttk::spinbox $p.r -width 10 -textvariable settings(dut.r) -from 0 -to 1000 -increment 1 -validate key -validatecommand {string is double %P}] -row 1 -column 1 -sticky e
grid [ttk::label $p.lre -text "\u00b1"] -row 1 -column 2 -sticky e
grid [ttk::spinbox $p.re -width 10 -textvariable settings(dut.rErr) -from 0 -to 100 -increment 0.1 -validate key -validatecommand {string is double %P}] -row 1 -column 3 -sticky e

grid [ttk::label $p.lmomentum -text "\u041C\u043E\u043C\u0435\u043D\u0442, \u041D/\u043C:"] -row 2 -column 0 -sticky w
grid [ttk::spinbox $p.momentum -width 10 -textvariable settings(dut.momentum) -from 0 -to 1000 -increment 1 -validate key -validatecommand {string is double %P}] -row 2 -column 1 -sticky e
grid [ttk::label $p.lmomentume -text "\u00b1"] -row 2 -column 2 -sticky e
grid [ttk::spinbox $p.momentume -width 10 -textvariable settings(dut.momentumErr) -from 0 -to 100 -increment 0.1 -validate key -validatecommand {string is double %P}] -row 2 -column 3 -sticky e

grid columnconfigure $p { 0 1 2 3 } -pad 5
grid rowconfigure $p { 0 1 2 } -pad 5
grid columnconfigure $p { 0 } -weight 1

# Раздел настроек вывода
set p [ttk::labelframe $w.nb.dut.reg -text " Файлы " -pad 10]

grid [ttk::label $p.lname -text "Имя файла результатов: " -anchor e] -row 0 -column 0 -sticky w
grid [ttk::entry $p.name -textvariable settings(result.fileName)] -row 0 -column 1 -columnspan 4 -sticky we

grid [ttk::label $p.lformat -text "Формат файлов:"] -row 3 -column 0 -sticky w
grid [ttk::combobox $p.format -width 10 -textvariable settings(result.format) -state readonly -values [list TXT CSV]] -row 3 -column 1 -columnspan 2 -sticky w

grid [ttk::label $p.lrewrite -text "Переписать файлы:"] -row 3 -column 3 -sticky e
grid [ttk::checkbutton $p.rewrite -variable settings(result.rewrite)] -row 3 -column 4 -sticky e

grid [ttk::label $p.lcomment -text "Комментарий: " -anchor e] -row 4 -column 0 -sticky w
grid [ttk::entry $p.comment -textvariable settings(result.comment)] -row 4 -column 1  -columnspan 4 -sticky we

grid [ttk::button $p.open -text "Открыть файл" -command openResults -image ::img::open -compound left] -row 5 -column 0 -columnspan 5 -sticky e

grid columnconfigure $p {0 1 3 4} -pad 5
grid columnconfigure $p { 2 } -weight 1
grid rowconfigure $p { 0 1 2 3 4 } -pad 5
grid rowconfigure $p { 5 } -pad 10

pack $p -fill x -padx 10 -pady 5

# Закладка "Параметры приборов"
ttk::frame $w.nb.tsetup
$w.nb add $w.nb.tsetup -text " Параметры приборов "

set p [ttk::labelframe $w.nb.tsetup.rs485 -text " Преобразователь интерфейсов RS-485/USB АС4" -pad 10]
pack $p -fill x -padx 10 -pady 5

grid [ttk::label $p.lrs485 -text "\u041F\u043E\u0441\u043b\u0435\u0434\u043e\u0432\u0430\u0442\u0435\u043b\u044c\u043d\u044b\u0439 \u043f\u043e\u0440\u0442:"] -row 0 -column 0 -sticky w
grid [ttk::combobox $p.rs485 -width 10 -textvariable settings(rs485.serialPort) -values [measure::com::allPorts]] -row 0 -column 1 -sticky w

grid [ttk::button $p.test -text "\u041E\u043F\u0440\u043E\u0441" -command [list ::measure::widget::testAc4 settings(rs485.serialPort) $p.test] ] -row 0 -column 2 -sticky e

grid columnconfigure $p { 0 1 2 } -pad 5
grid columnconfigure $p { 2 } -weight 1
grid rowconfigure $p { 0 1 } -pad 5

set p [ttk::labelframe $w.nb.tsetup.tcm -text " Измеритель температуры ТРМ-201 " -pad 10]
pack $p -fill x -padx 10 -pady 5

grid [ttk::label $p.lnetAddr -text "\u0421\u0435\u0442\u0435\u0432\u043E\u0439 \u0430\u0434\u0440\u0435\u0441:"] -row 0 -column 0 -sticky w
grid [ttk::spinbox $p.netAddr -width 6 -textvariable settings(trm1.addr) -from 1 -to 2040 -validate key -validatecommand {string is integer %P}] -row 0 -column 1 -sticky w

grid [ttk::label $p.lbaud -text "\u0421\u043A\u043E\u0440\u043E\u0441\u0442\u044C, бод/с:"] -row 0 -column 2 -sticky w
grid [ttk::combobox $p.baud -width 8 -textvariable settings(trm1.baud) -state readonly -values {9600 19200 28800 38400 57600 76800}] -row 0 -column 3 -sticky w

grid [ttk::label $p.lprotocol -text "Протокол обмена:"] -row 0 -column 4 -sticky w
grid [ttk::combobox $p.protocol -width 12 -textvariable settings(trm1.protocol) -state readonly -values {OWEN Modbus-RTU}] -row 0 -column 5 -sticky w

grid [ttk::button $p.test -text "\u041E\u043F\u0440\u043E\u0441" -command [list ::measure::widget::testTrm201 settings(rs485.serialPort) settings(trm1.rs485Addr) $p.test] ] -row 0 -column 6 -sticky e

grid columnconfigure $p { 0 1 2 3 4 5 6 } -pad 5
grid columnconfigure $p { 6 } -weight 1
grid rowconfigure $p { 0 1 } -pad 5

set p [ttk::labelframe $w.nb.tsetup.lir1 -text " Декодер угла поворота ЛИР-916 № 1" -pad 10]
pack $p -fill x -padx 10 -pady 5

grid [ttk::label $p.lnetAddr -text "\u0421\u0435\u0442\u0435\u0432\u043E\u0439 \u0430\u0434\u0440\u0435\u0441:"] -row 0 -column 0 -sticky w
grid [ttk::spinbox $p.netAddr -width 6 -textvariable settings(lir1.addr) -from 1 -to 2040 -validate key -validatecommand {string is integer %P}] -row 0 -column 1 -sticky w

grid [ttk::label $p.lbaud -text "\u0421\u043A\u043E\u0440\u043E\u0441\u0442\u044C, бод/с:"] -row 0 -column 2 -sticky w
grid [ttk::combobox $p.baud -width 8 -textvariable settings(lir1.baud) -state readonly -values {9600 19200 28800 38400 57600 76800}] -row 0 -column 3 -sticky w

grid [ttk::button $p.test -text "\u041E\u043F\u0440\u043E\u0441" -command [list testLir916 lir1 $p.test] ] -row 0 -column 6 -sticky e

grid columnconfigure $p { 0 1 2 3 4 5 6 } -pad 5
grid columnconfigure $p { 6 } -weight 1
grid rowconfigure $p { 0 1 } -pad 5

set p [ttk::labelframe $w.nb.tsetup.lir2 -text " Декодер угла поворота ЛИР-916 № 2" -pad 10]
pack $p -fill x -padx 10 -pady 5

grid [ttk::label $p.lnetAddr -text "\u0421\u0435\u0442\u0435\u0432\u043E\u0439 \u0430\u0434\u0440\u0435\u0441:"] -row 0 -column 0 -sticky w
grid [ttk::spinbox $p.netAddr -width 6 -textvariable settings(lir2.addr) -from 1 -to 2040 -validate key -validatecommand {string is integer %P}] -row 0 -column 1 -sticky w

grid [ttk::label $p.lbaud -text "\u0421\u043A\u043E\u0440\u043E\u0441\u0442\u044C, бод/с:"] -row 0 -column 2 -sticky w
grid [ttk::combobox $p.baud -width 8 -textvariable settings(lir2.baud) -state readonly -values {9600 19200 28800 38400 57600 76800}] -row 0 -column 3 -sticky w

grid [ttk::button $p.test -text "\u041E\u043F\u0440\u043E\u0441" -command [list testLir916 lir2 $p.test] ] -row 0 -column 6 -sticky e

grid columnconfigure $p { 0 1 2 3 4 5 6 } -pad 5
grid columnconfigure $p { 6 } -weight 1
grid rowconfigure $p { 0 1 } -pad 5

# Закладка "Параметры приборов"
ttk::frame $w.nb.cal
$w.nb add $w.nb.cal -text " Калибровка приборов "

set p [ttk::labelframe $w.nb.cal.lir -text " ЛИР-916" -pad 10]
pack $p -fill x -padx 10 -pady 5

grid [ttk::label $p.lcoeff -text "Коэффициент пересчёта угла поворота:"] -row 0 -column 0 -sticky w
grid [ttk::spinbox $p.coeff -width 12 -textvariable settings(lir2.coeff) -from 0.001 -to 1000 -validate key -validatecommand {string is double %P}] -row 0 -column 1 -sticky w

grid [ttk::button $p.test -text "Определить коэффициент" -command [list testLir916 lir2 $p.test] ] -row 0 -column 6 -sticky e

grid columnconfigure $p { 0 1 2 3 4 5 6 } -pad 5
grid columnconfigure $p { 6 } -weight 1
grid rowconfigure $p { 0 1 } -pad 5

# Стандартная панель
::measure::widget::std-bottom-panel $w

# Читаем настройки
measure::config::read

# Настраиваем элементы управления
toggleProgControls

# Запускаем тестер
startTester

#vwait forever
thread::wait

