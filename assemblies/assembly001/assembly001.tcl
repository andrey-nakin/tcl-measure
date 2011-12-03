#!/usr/bin/wish

###############################################################################
# Измерительная установка № 001
# Измеряем удельное сопротивление с варьированием тока, протекающего через 
#   образец, при постоянной температуре 4-х контактным методом.
# Количество одновременно измеряемых образцов: 1
# Переполюсовка напряжения и тока.
###############################################################################

package require Tcl 8.4
package require Tk
package require Ttk
package require Thread
package require measure::widget
package require inifile
package require measure::logger
package require measure::config
package require measure::visa
package require measure::com
package require measure::interop

###############################################################################
# Константы
###############################################################################

###############################################################################
# Процедуры
###############################################################################

# Процедура вызываеися из фонового рабочего потока по завершении его работы
proc stopMeasure {} {
	global w log

	# разрешаем кнопку запуска измерений
	$w.note.measure.run.start configure -state normal 
}

# Запускаем измерения
proc startMeasure {} {
	global w log

	# запрещаем кнопку запуска измерений
	$w.note.measure.run.start configure -state disabled

	# Сохраняем параметры программы
	measure::config::write

	# Запускаем на выполнение фоновый поток	с процедурой измерения
	measure::interop::startWorker [list source [file join [file dirname [info script]] measure.tcl] ] { stopMeasure }
}

# Открываем файл с результами измерения
proc openResults {} {
    global measure
    
    exec start \"measure(fileName)\"
}

# Завершение работы программы
proc quit {} {
	# Сохраняем параметры программы
	measure::config::write

	# завершаем измерительный поток, если он запущен
	measure::interop::waitForWorkerThreads

	exit
}

###############################################################################
# Начало скрипта
###############################################################################

set log [measure::logger::init measure]
measure::logger::server

# Создаём окно программы
set w ""
wm title $w. "Установка № 1: Измерение УС"

# Панель закладок
ttk::notebook $w.note
pack $w.note -fill both -expand 1 -padx 2 -pady 3
ttk::notebook::enableTraversal $w.note

# Закладка "Измерение"
ttk::frame $w.note.measure
$w.note add $w.note.measure -text " Измерение " -padding 10

grid [labelframe $w.note.measure.curr -text " Параметры измерения " -padx 2 -pady 2] -column 0 -row 0 -sticky wns

grid [label $w.note.measure.curr.lstart -text "Начальный ток, мА:"] -row 0 -column 0 -sticky w
spinbox $w.note.measure.curr.start -textvariable measure(startCurrent) -from 0 -to 2200 -increment 10 -width 10 -validate key -vcmd {string is integer %P}
grid $w.note.measure.curr.start -row 0 -column 1 -sticky w

grid [label $w.note.measure.curr.lend -text "Конечный ток, мА:"] -row 1 -column 0 -sticky w
spinbox $w.note.measure.curr.end -textvariable measure(endCurrent) -from 0 -to 2200 -increment 10 -width 10 -validate key -vcmd {string is integer %P}
grid $w.note.measure.curr.end -row 1 -column 1 -sticky w

grid [label $w.note.measure.curr.lstep -text "Приращение, мА:"] -row 2 -column 0 -sticky w
spinbox $w.note.measure.curr.step -textvariable measure(currentStep) -from -2200 -to 2200 -increment 10 -width 10 -validate key -vcmd {string is integer %P}
grid $w.note.measure.curr.step -row 2 -column 1 -sticky w

grid [label $w.note.measure.curr.lnsamples -text "Измерений на точку:"] -row 3 -column 0 -sticky w
spinbox $w.note.measure.curr.nsamples -textvariable measure(numberOfSamples) -from 1 -to 50000 -increment 10 -width 10 -validate key -vcmd {string is integer %P}
grid $w.note.measure.curr.nsamples -row 3 -column 1 -sticky w

grid [label $w.note.measure.curr.lswitchVoltage -text "Переполюсовка напряжения:"] -row 4 -column 0 -sticky w
checkbutton $w.note.measure.curr.switchVoltage -variable measure(switchVoltage) -relief flat
grid $w.note.measure.curr.switchVoltage -row 4 -column 1 -sticky w

grid [label $w.note.measure.curr.lswitchCurrent -text "Переполюсовка тока:"] -row 5 -column 0 -sticky w
checkbutton $w.note.measure.curr.switchCurrent -variable measure(switchCurrent) -relief flat
grid $w.note.measure.curr.switchCurrent -row 5 -column 1 -sticky w

grid columnconfigure $w.note.measure.curr {0 1} -pad 5
grid rowconfigure $w.note.measure.curr {0 1 2 3 4 5} -pad 5

grid [labelframe $w.note.measure.file -text " Результаты " -padx 2 -pady 2] -column 1 -row 0 -sticky ens

grid [label $w.note.measure.file.lname -text "Имя файла: " -anchor e] -row 0 -column 0 -sticky w
entry $w.note.measure.file.name -width 20 -textvariable measure(fileName)
grid $w.note.measure.file.name -row 0 -column 1 -sticky w
grid [button $w.note.measure.file.bname -text "Обзор..." -command "::measure::widget::fileSaveDialog $w. $w.note.measure.file.name"] -row 1 -column 1 -sticky e

grid [label $w.note.measure.file.lformat -text "Формат файла:"] -row 2 -column 0 -sticky w
ttk::combobox $w.note.measure.file.format -textvariable measure(fileFormat) -state readonly -values [list TXT CSV]
grid $w.note.measure.file.format -row 2 -column 1 -sticky w

grid [label $w.note.measure.file.lrewrite -text "Переписать файл:"] -row 3 -column 0 -sticky w
checkbutton $w.note.measure.file.rewrite -variable measure(fileRewrite) -relief flat
grid $w.note.measure.file.rewrite -row 3 -column 1 -sticky w

grid columnconfigure $w.note.measure.file {0 1} -pad 5
grid rowconfigure $w.note.measure.file {0 1 2 3 4} -pad 5

grid [labelframe $w.note.measure.run -text " Работа " -padx 2 -pady 2] -column 0 -row 1 -columnspan 2 -sticky we
grid [label $w.note.measure.run.lcurrent -text "Ток питания, мА:"] -column 0 -row 0 -sticky w
grid [entry $w.note.measure.run.current -textvariable runtime(current) -state readonly] -column 1 -row 0 -sticky e
grid [label $w.note.measure.run.lpower -text "Мощность, мВт:"] -column 3 -row 0 -sticky e
grid [entry $w.note.measure.run.power -textvariable runtime(power) -state readonly] -column 4 -row 0 -sticky w
grid [label $w.note.measure.run.lvoltage -text "Напряжение, мВ:"] -column 0 -row 1 -sticky w
grid [entry $w.note.measure.run.voltage -textvariable runtime(voltage) -state readonly] -column 1 -row 1 -sticky e
grid [label $w.note.measure.run.lresistance -text "Сопротивление, Ом:"] -column 3 -row 1 -sticky e
grid [entry $w.note.measure.run.resistance -textvariable runtime(resistance) -state readonly] -column 4 -row 1 -sticky w
#grid [ttk::button $w.note.measure.run.open -text "Открыть файл результатов" -command openResults] -column 0 -row 2 -columnspan 2 -sticky w
grid [ttk::button $w.note.measure.run.start -text "Начать измерения" -command startMeasure] -column 3 -row 2 -columnspan 2 -sticky e

grid columnconfigure $w.note.measure.run {0 1 2 3 4} -pad 5
grid rowconfigure $w.note.measure.run {0 1} -pad 5
grid rowconfigure $w.note.measure.run {2} -pad 20

grid columnconfigure $w.note.measure {0 1} -pad 5
grid rowconfigure $w.note.measure {0 1} -pad 5

# Закладка "Параметры"
ttk::frame $w.note.setup
$w.note add $w.note.setup -text " Параметры " -padding 10

grid [label $w.note.setup.lrs485 -text "Порт для АС4:"] -row 0 -column 0 -sticky w
ttk::combobox $w.note.setup.rs485 -textvariable settings(rs485Port) -values [measure::com::allPorts]
grid $w.note.setup.rs485 -row 0 -column 1 -sticky w

grid [label $w.note.setup.lswitchAddr -text "Сетевой адрес МВУ-8:"] -row 1 -column 0 -sticky w
spinbox $w.note.setup.switchAddr -textvariable settings(switchAddr) -from 1 -to 2040 -width 10 -validate key -vcmd {string is integer %P}
grid $w.note.setup.switchAddr -row 1 -column 1 -sticky w

grid [label $w.note.setup.lps -text "VISA адрес источника питания:"] -row 2 -column 0 -sticky w
ttk::combobox $w.note.setup.ps -textvariable settings(psAddr) -values [measure::visa::allInstruments]
grid $w.note.setup.ps -row 2 -column 1 -sticky w

grid [label $w.note.setup.lmm -text "VISA адрес мультиметра:"] -row 3 -column 0 -sticky w
ttk::combobox $w.note.setup.mm -textvariable settings(mmAddr) -values [measure::visa::allInstruments]
grid $w.note.setup.mm -row 3 -column 1 -sticky w

#pack [ttk::button $w.note.setup.test -text "Опросить устройства" -compound left] -expand no -side left
#grid $w.note.setup.test -row 4 -column 1 -sticky e

grid columnconfigure $w.note.setup {0 1} -pad 5
grid rowconfigure $w.note.setup {0 1 2 3} -pad 5
grid rowconfigure $w.note.setup 4 -pad 20

# Информационная панель

frame $w.inf
pack $w.inf -fill both -expand 1 -padx 10 -pady 10
pack [label $w.inf.txt -wraplength 6i -justify left -text "Программа измерения удельного сопротивления 4-х контактным методом при постоянной температуре с переполюсовкой контактов по току и напряжению. Максимально допустимое сопротивление в цепи: 35 кОм."]

# Кнопка закрытия приложения
::measure::widget::exit-button $w

# Читаем настройки
measure::config::read

#vwait forever
thread::wait

