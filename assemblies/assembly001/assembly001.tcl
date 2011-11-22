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

# Читаем настройки из конфигурационного файла
proc readSettings {} {
  global CONFIG_FILE_NAME CONFIG_SECTION_SETTINGS log
  
  if { [catch { set fd [ini::open $CONFIG_FILE_NAME r] } rc ] } {
    # Ошибка открытия файла конфигурации
    ${log}::error "Ошибка открытия файла конфигурации: $rc"
    return
  }
  set pairs [ini::get $fd $CONFIG_SECTION_SETTINGS]
  ini::close $fd
}

# Сохраняем настройки в конфигурационном файле
proc saveSettings {} {
}

# Завершение работы программы
proc quit {} {
  global measureThread

  # Сохраняем параметры программы
  saveSettings
    
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
$w.note add $w.note.setup -text "Параметры" -underline 0 -padding 10

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
grid $w.note.setup.test -row 4 -column 0 -sticky w

pack [ttk::button $w.note.setup.save -text "Сохранить настройки" -compound left -command measure::config::write] -expand no -side right
grid $w.note.setup.save -row 4 -column 1 -sticky e

grid columnconfigure $w.note.setup {0 1} -pad 5
grid rowconfigure $w.note.setup {0 1 2 3} -pad 5
grid rowconfigure $w.note.setup 4 -pad 20

# Закладка "Измерение"
ttk::frame $w.note.measure
$w.note add $w.note.measure -text "Измерение" -underline 0 -padding 10

#ttk::label $w.note.msg.m -wraplength 4i -justify left -anchor n -text "Ttk is the new Tk themed widget set. One of the widgets it includes is the notebook widget, which provides a set of tabs that allow the selection of a group of panels, each with distinct content. They are a feature of many modern user interfaces. Not only can the tabs be selected with the mouse, but they can also be switched between using Ctrl+Tab when the notebook page heading itself is selected. Note that the second tab is disabled, and cannot be selected."
#ttk::button $w.note.msg.b -text "Neat!" -underline 0 -command {
#    set neat "Yeah, I know..."
#    after 500 {set neat {}}
#}
#ttk::label $w.note.msg.l -textvariable neat

#grid $w.note.msg.m - -sticky new -pady 2
#grid $w.note.msg.b $w.note.msg.l -pady {2 4}
#grid rowconfigure $w.note.msg 1 -weight 1
#grid columnconfigure $w.note.msg {0 1} -weight 1 -uniform 1

frame $w.inf
pack $w.inf -fill both -expand 1 -padx 10 -pady 10
pack [label $w.inf.txt -wraplength 4i -justify left -text "Программа измерения удельного сопротивления 4-х контактным методом при постоянной температуре с переполюсовкой контактов по току и напряжению."]

# Кнопка закрытия приложения
::measure::widget::exit-button $w

# Читаем настройки
array set settings [list] 
measure::config::read
set settings(rs485Port) COM5
set settings(switchAddr) 40
set settings(psAddr) "ASRL1::INSTR"

vwait forever
