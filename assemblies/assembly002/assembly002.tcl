#!/usr/bin/wish

###############################################################################
# Измерительная установка № 002
# Измеряем напряжение однократно с высокой частотой 
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
package require startfile

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
     
    # Запрещаем кнопку останова измерений    
	$w.note.measure.run.stop configure -state disabled
}

# Запускаем измерения
proc startMeasure {} {
	global w log runtime

	# запрещаем кнопку запуска измерений
	$w.note.measure.run.start configure -state disabled

	# Сохраняем параметры программы
	measure::config::write

    # Сбрасываем сигнал "прерван"
    measure::interop::clearTerminated
    
	# Запускаем на выполнение фоновый поток	с процедурой измерения
	measure::interop::startWorker [list source [file join [file dirname [info script]] measure.tcl] ] { stopMeasure }

    # Разрешаем кнопку останова измерений
	$w.note.measure.run.stop configure -state normal
}

# Прерываем измерения
proc terminateMeasure {} {
    global w log

    # Запрещаем кнопку останова измерений    
	$w.note.measure.run.stop configure -state disabled
	
	# Посылаем в измерительный поток сигнал об останове
	measure::interop::terminate
}

# Открываем файл с результами измерения
proc openResults {} {
    global measure
    
    startfile::start $measure(fileName)
}

# Анализируем файл с результами измерения
proc analyzeResults {} {
    global measure
    
	catch { exec scilab -f "analyze.sce" & }
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
wm title $w. "Установка № 2: Измерение напряжения"

# Панель закладок
ttk::notebook $w.note
pack $w.note -fill both -expand 1 -padx 2 -pady 3
ttk::notebook::enableTraversal $w.note

# Закладка "Измерение"
ttk::frame $w.note.measure
$w.note add $w.note.measure -text " Измерение " -padding 10

grid [labelframe $w.note.measure.curr -text " Параметры измерения " -padx 2 -pady 2] -column 0 -row 0 -sticky wns

grid [label $w.note.measure.curr.lnsamples -text "Число измерений:"] -row 0 -column 0 -sticky w
grid [spinbox $w.note.measure.curr.nsamples -textvariable measure(numberOfSamples) -from 1 -to 50000 -increment 100 -width 10 -validate key -vcmd {string is integer %P} ] -row 0 -column 1 -sticky w

grid [label $w.note.measure.curr.lfreq -text "Частота, Гц:"] -row 1 -column 0 -sticky w
grid [spinbox $w.note.measure.curr.freq -textvariable measure(freq) -from 0 -to 8000 -increment 10 -width 10 -validate key -vcmd {string is double %P} ] -row 1 -column 1 -sticky w

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

grid [ttk::button $w.note.measure.run.open -text "Открыть результаты" -command openResults] -column 0 -row 2 -sticky w
grid [ttk::button $w.note.measure.run.analyze -text "Анализировать результаты" -command analyzeResults] -column 1 -row 2 -sticky w
#grid [ttk::button $w.note.measure.run.stop -text "Остановить измерения" -command terminateMeasure -state disabled] -column 2 -row 2 -sticky w
grid [ttk::button $w.note.measure.run.start -text "Начать измерения" -command startMeasure] -column 2 -row 2 -sticky e

grid columnconfigure $w.note.measure.run {0 1 2 3 4} -pad 5
grid rowconfigure $w.note.measure.run {0 1} -pad 5
grid rowconfigure $w.note.measure.run {2} -pad 20

grid columnconfigure $w.note.measure {0 1} -pad 5
grid rowconfigure $w.note.measure {0 1} -pad 5

# Закладка "Параметры"
ttk::frame $w.note.setup
$w.note add $w.note.setup -text " Параметры " -padding 10

grid [label $w.note.setup.lmm -text "VISA адрес вольтметра:"] -row 0 -column 0 -sticky w
grid [ttk::combobox $w.note.setup.mm -width 40 -textvariable settings(mmAddr) -values [measure::visa::allInstruments] ] -row 0 -column 1 -sticky w

grid columnconfigure $w.note.setup {0 1} -pad 5
grid rowconfigure $w.note.setup {0 1 2 3 4 5} -pad 5
grid rowconfigure $w.note.setup 5 -pad 20

# Информационная панель

frame $w.inf
pack $w.inf -fill both -expand 1 -padx 10 -pady 10
pack [label $w.inf.txt -wraplength 6i -justify left -text "Программа делает однократную съёмку напряжения с указанной частотой и записывает результаты в файл."]

# Кнопка закрытия приложения
::measure::widget::exit-button $w

# Читаем настройки
measure::config::read

#vwait forever
thread::wait

