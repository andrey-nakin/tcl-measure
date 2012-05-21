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
package require measure::tmap
package require measure::datafile

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]

###############################################################################
# Константы
###############################################################################

###############################################################################
# Процедуры
###############################################################################

# Процедура вызывается при завершении работы модуля термостатирования
proc thermostatStopped {} {
	global w thermoThreadId

	# Запрещаем кнопку "Стоп"
	$w.nb.m.ctl.stop configure -state disabled

	# Запрещаем кнопки управления ПИД
	$w.nb.m.ctl.ssp configure -state disabled
	$w.nb.m.ctl.ria configure -state disabled

	# Разрешаем кнопку "Старт"
	$w.nb.m.ctl.start configure -state normal

	unset thermoThreadId
}

# Запускаем модуль термостатирования
proc startThermostat {} {
	global w thermoThreadId

	# Сохраняем параметры программы
	measure::config::write

    # Сбрасываем сигнал "прерван"
    measure::interop::clearTerminated

	# Запускаем на выполнение фоновый поток	с процедурой измерения
	set thermoThreadId [measure::interop::startWorker [list source [file join [file dirname [info script]] pid.tcl] ] {thermostatStopped}]

	# Запрещаем кнопку "Старт"
	$w.nb.m.ctl.start configure -state disabled

	# Разрешаем кнопку "Стоп"
	$w.nb.m.ctl.stop configure -state normal

	# Разрешаем кнопки управления ПИД
	$w.nb.m.ctl.ssp configure -state normal
	$w.nb.m.ctl.ria configure -state normal
}

# Прерываем работу модуля термостатирования
proc stopThermostat { { wait 0} } {
	global w

	# Запрещаем кнопку "Стоп"
	$w.nb.m.ctl.stop configure -state disabled

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

    # останавливаем поток записи данных
    ::measure::datafile::shutdown
     
	# завершаем работу модуля протоколирования
	::measure::logger::shutdown

	exit
}

# Изменяем значение уставки
proc setPoint {} {
	global thermoThreadId settings

	if { [info exists thermoThreadId] } {
		thread::send -async $thermoThreadId [list setPoint $settings(newSetPoint)]
	}
}

# Сбрасываем интегральное накопление
proc resetIAccum {} {
	global thermoThreadId

	if { [info exists thermoThreadId] } {
		thread::send -async $thermoThreadId [list resetIAccum]
	}
}

proc setReg {} {
	global thermoThreadId settings

	if { [info exists thermoThreadId] } {
		thread::send -async $thermoThreadId [list setReg $settings(reg.fileName) $settings(reg.format) $settings(reg.rewrite)]
	}
}

# Процедура вызывается при завершении работы модуля записи температуной схемы
proc tsWriterStopped {} {
	global w tsThreadId

	# Запрещаем кнопку "Стоп"
	$w.nb.stc.ctl.stop configure -state disabled

	# Разрешаем кнопку "Старт"
	$w.nb.stc.ctl.start configure -state normal

	unset tsThreadId
}

# Запускаем модуль записи температурной схемы
proc startTsWriter {} {
	global w tsThreadId

	# Сохраняем параметры программы
	measure::config::write

    # Сбрасываем сигнал "прерван"
    measure::interop::clearTerminated

	# Запускаем на выполнение фоновый поток	с процедурой измерения
	set tsThreadId [measure::interop::startWorker [list source [file join [file dirname [info script]] tswriter.tcl] ] {tsWriterStopped}]

	# Запрещаем кнопку "Старт"
	$w.nb.stc.ctl.start configure -state disabled

	# Разрешаем кнопку "Стоп"
	$w.nb.stc.ctl.stop configure -state normal
}

# Прерываем работу модуля записи температурной схемы
proc stopTsWriter { { wait 0} } {
	global w

	# Запрещаем кнопку "Стоп"
	$w.nb.stc.ctl.stop configure -state disabled

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

proc applySettings {} {
	global thermoThreadId settings

	# Сохраняем параметры программы
	measure::config::write
	
	if { [info exists thermoThreadId] } {
		# Отправляем настройки рабочему потоку
		thread::send -async $thermoThreadId [list applySettings [array get settings]]
	}
}

###############################################################################
# Обработчики событий
###############################################################################

# Последняя измеренная температура
proc setTemperature { t tErr err trend sigma derivative1 } {
	global runtime canvas

	set runtime(value) [format "%0.2f \u00b1 %0.2f" $t $tErr]
	set runtime(error) [format "%0.3f \u00b1 %0.2f" $err $tErr]
	set runtime(trend) [format "%0.3f" $trend]
	set runtime(sigma) [format "%0.3f" $sigma]
	set runtime(derivative1) [format "%0.3f" $derivative1]

	measure::chart::${canvas}::addPoint $t
}

# Ток и напряжение питания печки
proc setPower { current voltage } {
	global runtime

	set runtime(current) [format "%0.4g" [expr 1000.0 * $current]]
	set runtime(voltage) [format "%0.4g" [expr 1.0 * $voltage]]
	set runtime(power) [format "%0.2g" [expr 1.0 * $current * $voltage]]
}

proc setPidTerms { pTerm iTerm dTerm } {
	global runtime

    set sum [expr $pTerm + $iTerm + $dTerm]
	set runtime(pterm) [format "%0.1f (%0.0f%%)" $pTerm [expr 100.0 * ($pTerm/$sum)]]
	set runtime(iterm) [format "%0.1f (%0.0f%%)" $iTerm [expr 100.0 * ($iTerm/$sum)]]
	set runtime(dterm) [format "%0.1f (%0.0f%%)" $dTerm [expr 100.0 * ($dTerm/$sum)]]
}

# Ток и напряжение питания печки
proc setTsPower { current voltage } {
	global runtime

	set runtime(current) [format "%0.4g" [expr 1000.0 * $current]]
	set runtime(voltage) [format "%0.4g" [expr 1.0 * $voltage]]
	set runtime(power) [format "%0.2g" [expr 1.0 * $current * $voltage]]
}

# Последняя измеренная температура
proc setTsTemperature { t tErr trend std } {
	global runtime tsCanvas

	set runtime(value) [format "%0.2f \u00b1 %0.2f" $t $tErr]
	set runtime(trend) [format "%0.3f" $trend]
	set runtime(std) [format "%0.2f" $std]

	measure::chart::${tsCanvas}::addPoint $t
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
wm title $w. "Установка № 5: Термостат"

# При нажатии крестика в углу окна вызыватьспециальную процедуру завершения
wm protocol $w. WM_DELETE_WINDOW { quit }

# Панель закладок
ttk::notebook $w.nb
pack $w.nb -fill both -expand 1 -padx 2 -pady 3
ttk::notebook::enableTraversal $w.nb

##############################################################################
# Закладка "Работа"
##############################################################################
ttk::frame $w.nb.m
$w.nb add $w.nb.m -text " Работа "

# Раздел "Управление"
set p [ttk::labelframe $w.nb.m.ctl -text " Управление " -pad 10]
pack $p -fill x -side bottom -padx 10 -pady 5

grid [ttk::label $p.lsp -text "Новая уставка, К:"] -row 0 -column 0 -sticky w
grid [ttk::spinbox $p.sp -width 10 -textvariable settings(newSetPoint) -from 0 -to 2000 -increment 1 -validate key -validatecommand {string is double %P}] -row 0 -column 1 -sticky w
grid [ttk::button $p.ssp -text "Установить" -command setPoint -state disabled] -row 0 -column 2 -sticky w
grid [ttk::button $p.ria -text "Сбросить интегральное накопление" -command resetIAccum -state disabled] -row 0 -column 3 -sticky w
grid [ttk::button $p.start -text "Старт" -command startThermostat -image ::img::start -compound left] -row 0 -column 4 -sticky e
grid [ttk::button $p.stop -text "Стоп" -command stopThermostat -state disabled -image ::img::stop -compound left] -row 0 -column 5 -sticky e

grid columnconfigure $p { 0 1 2 3 4 5 } -pad 5
grid columnconfigure $p { 3 } -weight 1

# Раздел "Текущее состояние"
set p [ttk::labelframe $w.nb.m.v -text " Текущее состояние " -pad 10]
pack $p -fill x -side bottom -padx 10 -pady 5

grid [ttk::label $p.lsp -text "Уставка, К:"] -row 0 -column 0 -sticky w
grid [ttk::entry $p.esp -textvariable runtime(setPoint) -state readonly] -row 0 -column 1 -sticky we

grid [ttk::label $p.lvl -text "Значение, К:"] -row 0 -column 3 -sticky w
grid [ttk::entry $p.evl -textvariable runtime(value) -state readonly] -row 0 -column 4 -sticky we

grid [ttk::label $p.le -text "Невязка, К:"] -row 0 -column 6 -sticky w
grid [ttk::entry $p.ee -textvariable runtime(error) -state readonly] -row 0 -column 7 -sticky we

grid [ttk::label $p.leder -text "Производная, К/мин:"] -row 1 -column 0 -sticky w
grid [ttk::entry $p.eder -textvariable runtime(derivative1) -state readonly] -row 1 -column 1 -sticky we

grid [ttk::label $p.letrend -text "Тренд, К/мин:"] -row 1 -column 3 -sticky w
grid [ttk::entry $p.etrend -textvariable runtime(trend) -state readonly] -row 1 -column 4 -sticky we

grid [ttk::label $p.lesigma -text "Разброс, К:"] -row 1 -column 6 -sticky w
grid [ttk::entry $p.esigma -textvariable runtime(sigma) -state readonly] -row 1 -column 7 -sticky we

grid [ttk::label $p.lc -text "Ток питания, мА:"] -row 2 -column 0 -sticky w
grid [ttk::entry $p.ec -textvariable runtime(current) -state readonly] -row 2 -column 1 -sticky we

grid [ttk::label $p.lv -text "Напряжение, В:"] -row 2 -column 3 -sticky w
grid [ttk::entry $p.ev -textvariable runtime(voltage) -state readonly] -row 2 -column 4 -sticky we

grid [ttk::label $p.lp -text "Мощность, Вт:"] -row 2 -column 6 -sticky w
grid [ttk::entry $p.ep -textvariable runtime(power) -state readonly] -row 2 -column 7 -sticky we

grid [ttk::label $p.lpterm -text "ПЧ, мА:"] -row 3 -column 0 -sticky w
grid [ttk::entry $p.pterm -textvariable runtime(pterm) -state readonly] -row 3 -column 1 -sticky we

grid [ttk::label $p.literm -text "ИЧ, мА:"] -row 3 -column 3 -sticky w
grid [ttk::entry $p.iterm -textvariable runtime(iterm) -state readonly] -row 3 -column 4 -sticky we

grid [ttk::label $p.ldterm -text "ДЧ, мА:"] -row 3 -column 6 -sticky w
grid [ttk::entry $p.dterm -textvariable runtime(dterm) -state readonly] -row 3 -column 7 -sticky we

grid columnconfigure $p { 0 1 3 4 6 7 } -pad 5
grid columnconfigure $p { 2 5 } -minsize 20
grid columnconfigure $p { 1 4 7 } -weight 1
grid rowconfigure $p { 0 1 2 3 } -pad 5

# Раздел "График"
set p [ttk::labelframe $w.nb.m.c -text " График температуры " -pad 2]
pack $p -fill both -padx 10 -pady 5 -expand 1
set canvas [canvas $p.c -width 400 -height 200]
pack $canvas -fill both -expand 1
place [ttk::button $p.cb -text "Очистить" -command "measure::chart::${canvas}::clear"] -anchor ne -relx 1.0 -rely 0.0
measure::chart::movingChart -ylabel "T, К" -xpoints 500 $canvas

##############################################################################
# Закладка "Параметры"
##############################################################################
set frm $w.nb.setup
ttk::frame $frm
$w.nb add $frm -text " Параметры "

set p [ttk::labelframe $frm.ps -text " Источник тока " -pad 10]
pack $p -fill x -padx 10 -pady 5

::measure::widget::psControls $p ps

set p [ttk::labelframe $frm.pid -text " ПИД-регулятор " -pad 10]
pack $p -fill x -padx 10 -pady 5

grid [ttk::label $p.ltp -text "Пропорциональный коэффициент:"] -row 0 -column 0 -sticky w
grid [ttk::spinbox $p.tp -width 10 -textvariable settings(pid.tp) -from 0 -to 100000 -increment 1 -validate key -validatecommand {string is double %P}] -row 0 -column 1 -sticky w

grid [ttk::label $p.ltd -text "Дифференциальный коэффициент:"] -row 0 -column 3 -sticky w
grid [ttk::spinbox $p.td -width 10 -textvariable settings(pid.td) -from 0 -to 100000 -increment 1 -validate key -validatecommand {string is double %P}] -row 0 -column 4 -sticky w

grid [ttk::label $p.lti -text "Интегральный коэффициент:"] -row 1 -column 0 -sticky w
grid [ttk::spinbox $p.ti -width 10 -textvariable settings(pid.ti) -from 0 -to 100000 -increment 1 -validate key -validatecommand {string is double %P}] -row 1 -column 1 -sticky w

grid [ttk::label $p.lmaxi -text "Макс. интегральное накопление (+):"] -row 2 -column 0 -sticky w
grid [ttk::spinbox $p.maxi -width 10 -textvariable settings(pid.maxi) -from 0 -to 100000000 -increment 1 -validate key -validatecommand {string is double %P}] -row 2 -column 1 -sticky w

grid [ttk::label $p.lmaxin -text "Макс. интегральное накопление (-):"] -row 2 -column 3 -sticky w
grid [ttk::spinbox $p.maxin -width 10 -textvariable settings(pid.maxiNeg) -from 0 -to 100000000 -increment 1 -validate key -validatecommand {string is double %P}] -row 2 -column 4 -sticky w

grid [ttk::label $p.lnd -text "Кол-во измерений для производной:"] -row 3 -column 0 -sticky w
grid [ttk::spinbox $p.nd -width 10 -textvariable settings(pid.nd) -from 0 -to 1000 -increment 1 -validate key -validatecommand {string is integer %P}] -row 3 -column 1 -sticky w

grid [ttk::label $p.lnt -text "Кол-во измерений для тренда:"] -row 3 -column 3 -sticky w
grid [ttk::spinbox $p.nt -width 10 -textvariable settings(pid.nt) -from 0 -to 1000 -increment 1 -validate key -validatecommand {string is integer %P}] -row 3 -column 4 -sticky w

grid columnconfigure $p { 0 1 2 3 4 } -pad 5
grid columnconfigure $p { 2 } -weight 1 -pad 20
grid rowconfigure $p { 0 1 2 3 } -pad 5

set p [ttk::labelframe $frm.reg -text " Регистрация температуры " -pad 10]
pack $p -fill x -padx 10 -pady 5

grid [ttk::label $p.lname -text "Имя файла: " -anchor e] -row 0 -column 0 -sticky w
grid [ttk::entry $p.name -textvariable settings(reg.fileName)] -row 0 -column 1 -columnspan 4 -sticky we
grid [ttk::button $p.bname -text "Обзор..." -command "::measure::widget::fileSaveDialog $w. $p.name" -image ::img::open] -row 0 -column 4 -sticky e

grid [ttk::label $p.lformat -text "Формат файла:"] -row 1 -column 0 -sticky w
grid [ttk::combobox $p.format -width 10 -textvariable settings(reg.format) -state readonly -values $measure::datafile::FORMAT_LIST] -row 1 -column 1 -sticky we

grid [ttk::label $p.lrewrite -text "Переписать файл:"] -row 1 -column 3 -sticky w
grid [ttk::checkbutton $p.rewrite -variable settings(reg.rewrite)] -row 1 -column 4 -sticky e

grid [ttk::button $p.ssp -text "Применить" -command setReg] -row 2 -column 3 -columnspan 2 -sticky e

grid columnconfigure $p { 0 1 3 4 } -pad 5
grid columnconfigure $p { 2 } -weight 1 -pad 20
grid rowconfigure $p { 0 1 2 } -pad 5

set p [ttk::labelframe $frm.misc -text " Прочее " -pad 10]
pack $p -fill x -padx 10 -pady 5

grid [ttk::label $p.lport -text "TCP порт:"] -row 0 -column 0 -sticky w
grid [ttk::spinbox $p.port -width 10 -textvariable settings(http.port) -from 1 -to 65534 -increment 1 -validate key -validatecommand {string is integer %P}] -row 0 -column 1 -sticky w

grid [ttk::label $p.lautoStart -text "Автостарт при запуске:"] -row 0 -column 3 -sticky w
grid [ttk::checkbutton $p.autoStart -variable settings(autoStart)] -row 0 -column 4 -sticky e

grid columnconfigure $p { 0 1 3 4 } -pad 5
grid columnconfigure $p { 2 } -weight 1 -pad 20
grid rowconfigure $p { 0 1 } -pad 5

# Нижний раздел
pack [ttk::frame $frm.bot -pad 10] -side bottom -fill x
pack [ttk::button $frm.bot.apply -text "Применить настройки" -command applySettings -image ::img::apply -compound left] -side right

##############################################################################
# Закладка "Вольметр+Термопара"
set frm $w.nb.mmtc
##############################################################################
ttk::frame $frm
$w.nb add $frm -text " Параметры вольметра и термопары "

set p [ttk::labelframe $frm.mm -text " Вольтметр " -pad 10]
pack $p -fill x -padx 10 -pady 5

::measure::widget::mmControls $p mmtc.mm

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

##############################################################################
# Закладка "Запись температурной схемы"
##############################################################################

set frm $w.nb.stc
ttk::frame $frm
$w.nb add $frm -text " Запись T-схемы "

# Раздел "Управление"
set p [ttk::labelframe $w.nb.stc.ctl -text " Управление " -pad 10]
pack $p -fill x -side bottom -padx 10 -pady 5

grid [ttk::button $p.start -text "Старт" -command startTsWriter -image ::img::start -compound left] -row 0 -column 4 -sticky e
grid [ttk::button $p.stop -text "Стоп" -command stopTsWriter -state disabled -image ::img::stop -compound left] -row 0 -column 5 -sticky e

grid columnconfigure $p { 0 1 2 3 4 5 } -pad 5
grid columnconfigure $p { 3 } -weight 1

# Раздел "Текущее состояние"
set p [ttk::labelframe $w.nb.stc.v -text " Текущее состояние " -pad 10]
pack $p -fill x -side bottom -padx 10 -pady 5

grid [ttk::label $p.lsp -text "Температура, К:"] -row 0 -column 0 -sticky w
grid [ttk::entry $p.esp -textvariable runtime(value) -state readonly] -row 0 -column 1 -sticky we

grid [ttk::label $p.lvl -text "Тренд, К/мин:"] -row 0 -column 3 -sticky w
grid [ttk::entry $p.evl -textvariable runtime(trend) -state readonly] -row 0 -column 4 -sticky we

grid [ttk::label $p.le -text "Отклонение, мК:"] -row 0 -column 6 -sticky w
grid [ttk::entry $p.ee -textvariable runtime(std) -state readonly] -row 0 -column 7 -sticky we

grid [ttk::label $p.lc -text "Ток питания, мА:"] -row 1 -column 0 -sticky w
grid [ttk::entry $p.ec -textvariable runtime(current) -state readonly] -row 1 -column 1 -sticky we

grid [ttk::label $p.lv -text "Напряжение, В:"] -row 1 -column 3 -sticky w
grid [ttk::entry $p.ev -textvariable runtime(voltage) -state readonly] -row 1 -column 4 -sticky we

grid [ttk::label $p.lp -text "Мощность, Вт:"] -row 1 -column 6 -sticky w
grid [ttk::entry $p.ep -textvariable runtime(power) -state readonly] -row 1 -column 7 -sticky we

grid columnconfigure $p { 0 1 3 4 6 7 } -pad 5
grid columnconfigure $p { 2 5 } -minsize 20
grid columnconfigure $p { 1 4 7 } -weight 1
grid rowconfigure $p { 0 1 } -pad 5

# Раздел "Параметры"

set p [ttk::labelframe $w.nb.stc.setup -text " Параметры " -pad 10]
pack $p -fill x -side bottom -padx 10 -pady 5

grid [ttk::label $p.lstart -text "Начальный ток, мА:"] -row 0 -column 0 -sticky w
grid [ttk::spinbox $p.start -width 10 -textvariable settings(stc.start) -from 0 -to 2200 -increment 1 -validate key -validatecommand {string is double %P}] -row 0 -column 1 -sticky w

grid [ttk::label $p.lend -text "Конечный ток, мА:"] -row 0 -column 3 -sticky w
grid [ttk::spinbox $p.end -width 10 -textvariable settings(stc.end) -from 0 -to 2200 -increment 1 -validate key -validatecommand {string is double %P}] -row 0 -column 4 -sticky w

grid [ttk::label $p.lstep -text "Шаг изменения, мА:"] -row 0 -column 6 -sticky w
grid [ttk::spinbox $p.step -width 10 -textvariable settings(stc.step) -from 0 -to 2200 -increment 1 -validate key -validatecommand {string is double %P}] -row 0 -column 7 -sticky w

grid [ttk::label $p.lmaxTrend -text "Пороговый тренд, К/мин:"] -row 1 -column 0 -sticky w
grid [ttk::spinbox $p.maxTrend -width 10 -textvariable settings(stc.maxTrend) -from 0 -to 100 -increment 0.01 -validate key -validatecommand {string is double %P}] -row 1 -column 1 -sticky w

grid [ttk::label $p.lmaxStd -text "Пороговое отклонение, мК:"] -row 1 -column 3 -sticky w
grid [ttk::spinbox $p.maxStd -width 10 -textvariable settings(stc.maxStd) -from 0 -to 1000 -increment 1 -validate key -validatecommand {string is double %P}] -row 1 -column 4 -sticky w

grid [ttk::label $p.lname -text "Название схемы:"] -row 1 -column 6 -sticky w
grid [ttk::combobox $p.name -textvariable settings(stc.name) -values [measure::tmap::names]] -row 1 -column 7 -sticky we

grid columnconfigure $p { 0 1 3 4 6 7 } -pad 5
grid columnconfigure $p { 2 5 } -weight 1 -minsize 20
grid rowconfigure $p { 0 1 } -pad 5

# Раздел "График"
set p [ttk::labelframe $w.nb.stc.c -text " График температуры " -pad 2]
pack $p -fill both -padx 10 -pady 5 -expand 1
set tsCanvas [canvas $p.c -width 400 -height 200]
pack $tsCanvas -fill both -expand 1
measure::chart::movingChart -linearTrend -ylabel "T, К" -xpoints 500 $tsCanvas

##############################################################################
# Закладки закончились
##############################################################################

# Стандартная панель
::measure::widget::std-bottom-panel $w

# Читаем настройки
measure::config::read

# Запускаем модуль термостатирования
if { [measure::config::get autoStart 0] } {
	startThermostat
}

#vwait forever
thread::wait

