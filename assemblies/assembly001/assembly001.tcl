#!/usr/bin/tclsh

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

###############################################################################
# Измерительная установка № 001
# Измеряем удельное сопротивление при постоянной температуре 4-х контактным
# методом.
# Количество одновременно измеряемых образцов: 1
# Переполюсовка напряжения и тока.
###############################################################################

###############################################################################
# Константы
###############################################################################

# Имя файла конфигурации
set CONFIG_FILE_NAME "params.ini"

# Имя секции файла конфигурации для параметров программы
set CONFIG_SECTION_SETTINGS "settings"

###############################################################################
# Процедуры
###############################################################################

# Создаём измерительный поток
set measureThread [thread::create -joinable {

  
  #package require tclvisa
  #package require measure::logger

  #set log [measure::logger::init measure]
  
  #proc measure { config measure } {
    #global log
  
    #${log}::debug "Подключаемся к менеджеру ресурсов VISA"    
    #set rm [visa::open-default-rm]
    
    #set cfg [tsv::array get $config]
    
    # Закрываем подключения
    #close $rm
  #}
  
  thread::wait 
}]

proc fileDialog { ent } {
	global w

	set file [tk_getOpenFile -parent "$w."]

	if {[string compare $file ""]} {
		$ent delete 0 end
		$ent insert 0 $file
		$ent xview end
	}
}

# Завершение работы программы
proc quit {} {
  global measureThread

  # Сохраняем параметры программы
  measure::config::write
    
  # завершаем измерительный поток
  #thread::send $measureThread "thread::exit"
  #thread::join $measureThread 
  
  exit
}

###############################################################################
# Начало скрипта
###############################################################################

set log [measure::logger::init measure]
measure::logger::server

# Создаём окно программы
set w ""
wm title $w. "Установка № 1: Измерение удельного сопротивления"

# Панель закладок
ttk::notebook $w.note
pack $w.note -fill both -expand 1 -padx 2 -pady 3
ttk::notebook::enableTraversal $w.note

# Закладка "Параметры"
ttk::frame $w.note.setup
$w.note add $w.note.setup -text " Параметры " -padding 10

grid [label $w.note.setup.lrs485 -text "Порт для АС4:"] -row 0 -column 0 -sticky w
ttk::combobox $w.note.setup.rs485 -textvariable settings(rs485Port) -state readonly -values [measure::com::allPorts]
grid $w.note.setup.rs485 -row 0 -column 1 -sticky w

grid [label $w.note.setup.lswitchAddr -text "Сетевой адрес МВУ-8:"] -row 1 -column 0 -sticky w
spinbox $w.note.setup.switchAddr -textvariable settings(switchAddr) -from 1 -to 2040 -width 10 -validate key -vcmd {string is integer %P}
grid $w.note.setup.switchAddr -row 1 -column 1 -sticky w

grid [label $w.note.setup.lps -text "VISA адрес источника питания:"] -row 2 -column 0 -sticky w
ttk::combobox $w.note.setup.ps -textvariable settings(psAddr) -state readonly -values [measure::visa::allInstruments]
grid $w.note.setup.ps -row 2 -column 1 -sticky w

grid [label $w.note.setup.lmm -text "VISA адрес мультиметра:"] -row 3 -column 0 -sticky w
ttk::combobox $w.note.setup.mm -textvariable settings(mmAddr) -state readonly -values [measure::visa::allInstruments]
grid $w.note.setup.mm -row 3 -column 1 -sticky w

pack [ttk::button $w.note.setup.test -text "Опросить устройства" -compound left] -expand no -side left
grid $w.note.setup.test -row 4 -column 1 -sticky e

grid columnconfigure $w.note.setup {0 1} -pad 5
grid rowconfigure $w.note.setup {0 1 2 3} -pad 5
grid rowconfigure $w.note.setup 4 -pad 20

# Закладка "Измерение"
ttk::frame $w.note.measure
$w.note add $w.note.measure -text " Измерение " -padding 10

pack [labelframe $w.note.measure.curr -text " Токи " -padx 2 -pady 2]

grid [label $w.note.measure.curr.lstart -text "Начальный ток, мА:"] -row 0 -column 0 -sticky w
spinbox $w.note.measure.curr.start -textvariable measure(startCurrent) -from 1 -to 2200 -width 10 -validate key -vcmd {string is integer %P}
grid $w.note.measure.curr.start -row 0 -column 1 -sticky w

grid [label $w.note.measure.curr.lend -text "Конечный ток, мА:"] -row 1 -column 0 -sticky w
spinbox $w.note.measure.curr.end -textvariable measure(endCurrent) -from 1 -to 2200 -width 10 -validate key -vcmd {string is integer %P}
grid $w.note.measure.curr.end -row 1 -column 1 -sticky w

grid [label $w.note.measure.curr.lstep -text "Приращение, мА:"] -row 2 -column 0 -sticky w
spinbox $w.note.measure.curr.step -textvariable measure(currentStep) -from 1 -to 2200 -width 10 -validate key -vcmd {string is integer %P}
grid $w.note.measure.curr.step -row 2 -column 1 -sticky w

grid columnconfigure $w.note.measure.curr {0 1} -pad 5
grid rowconfigure $w.note.measure.curr {0 1 2 3} -pad 5
grid rowconfigure $w.note.measure.curr 4 -pad 20

pack [labelframe $w.note.measure.file -text " Файл " -padx 2 -pady 2]

grid [label $w.note.measure.file.lname -text "Имя файла с результатами: " -anchor e] -row 0 -column 0 -sticky w
entry $w.note.measure.file.name -width 20 -textvariable measure(fileName)
grid $w.note.measure.file.name -row 0 -column 1 -sticky w
grid [button $w.note.measure.file.bname -text "Обзор..." -command "fileDialog $w.note.measure.file.name"] -row 0 -column 2 -sticky w

grid [label $w.note.measure.file.lformat -text "Формат файла:"] -row 1 -column 0 -sticky w
ttk::combobox $w.note.measure.file.format -textvariable measure(fileFormat) -state readonly -values [list TXT CSV]
grid $w.note.measure.file.format -row 1 -column 1 -sticky w

grid [label $w.note.measure.file.lrewrite -text "Переписать файл:"] -row 2 -column 0 -sticky w
checkbutton $w.note.measure.file.rewrite -variable measure(fileRewrite) -relief flat
grid $w.note.measure.file.rewrite -row 2 -column 1 -sticky w

frame $w.inf
pack $w.inf -fill both -expand 1 -padx 10 -pady 10
pack [label $w.inf.txt -wraplength 4i -justify left -text "Программа измерения удельного сопротивления 4-х контактным методом при постоянной температуре с переполюсовкой контактов по току и напряжению."]

# Кнопка закрытия приложения
::measure::widget::exit-button $w

# Читаем настройки
measure::config::read

vwait forever
