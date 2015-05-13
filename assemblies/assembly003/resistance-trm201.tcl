#!/bin/sh
# a dummy comment ending with a backslash-character: \
exec /usr/bin/wish -encoding utf-8 "$0" "$@"

###############################################################################
# Установка для измерения сопротивления образцов в зависимости от температуры.
#
# Термостатирование осуществляется прибором ОВЕН ТРМ-201, который аналоговым
#   сигналом управляет источником питания. ИП запитывает печку. 
# Температура измеряется термопарой, подключённой к ТРМ-201.
# Напряжение на образцах и контрольном сопротивлении измеряется 4-х канальным 
#   АЦП ЛА-и24USB ("Руднев и Шиляев").
# Переключение полярности напряжения и тока осуществляется 2-мя блоками реле 
#   ОВЕН МВУ-8.
# Устройства с интерфейсом RS-485 подключены при помощи преобразователя
#   RS-485 <-> USB ОВЕН АС4.
#
# Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#
###############################################################################

package require Tcl 8.4
package require Tk
package require Ttk
package require measure::widget

###############################################################################
# НАЧАЛО РАБОТЫ ПРИЛОЖЕНИЯ
###############################################################################

# Создаём окно программы
set w ""
wm title $w. "Измерение сопротивления в зависимости от температуры"
::measure::widget::exit-button $w

# Панель закладок
ttk::notebook $w.note
pack $w.note -fill both -expand 1 -padx 2 -pady 3
ttk::notebook::enableTraversal $w.note

# Закладка "Измерение"
ttk::frame $w.note.msg
ttk::label $w.note.msg.m -wraplength 4i -justify left -anchor n -text "Ttk is the new Tk themed widget set. One of the widgets it includes is the notebook widget, which provides a set of tabs that allow the selection of a group of panels, each with distinct content. They are a feature of many modern user interfaces. Not only can the tabs be selected with the mouse, but they can also be switched between using Ctrl+Tab when the notebook page heading itself is selected. Note that the second tab is disabled, and cannot be selected."
ttk::button $w.note.msg.b -text "Neat!" -underline 0 -command {
    set neat "Yeah, I know..."
    after 500 {set neat {}}
}
ttk::label $w.note.msg.l -textvariable neat
$w.note add $w.note.msg -text "Измерение" -underline 0 -padding 2
grid $w.note.msg.m - -sticky new -pady 2
grid $w.note.msg.b $w.note.msg.l -pady {2 4}
grid rowconfigure $w.note.msg 1 -weight 1
grid columnconfigure $w.note.msg {0 1} -weight 1 -uniform 1

# Закладка "Параметры"
ttk::frame $w.note.setup
$w.note add $w.note.setup -text "Параметры" -underline 0 -padding 2

# Входим в цикл обработки событий
vwait forever

