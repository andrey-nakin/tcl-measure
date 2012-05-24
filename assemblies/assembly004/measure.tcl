#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 004
# Измерительный модуль
###############################################################################

package require measure::logger
package require measure::config
package require hardware::owen::mvu8
package require scpi
package require hardware::agilent::pse3645a
package require hardware::agilent::mm34410a
package require tclvisa
package require measure::datafile
package require measure::interop
package require measure::sigma
package require math::statistics

###############################################################################
# Подпрограммы
###############################################################################

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]

# Процедура производит одно измерение со всеми нужными переполюсовками
#   и сохраняет результаты в файле результатов
proc makeMeasurement {} {
	global mm cmm connectors settings

	set vs [list]; set svs [list]
	set cs [list]; set scs [list]
	set rs [list]; set srs [list]

	# Пробегаем по переполюсовкам
	set nc [llength $connectors]
	foreach conn $connectors {
		# Устанавливаем нужную полярность
		if { $nc > 1 } {
			setConnectors $conn
		}

		# Ждём окончания переходных процессов, 
		after 1000

		# Измеряем напряжение
		set res [measure::measure::resistance]

		# Накапливаем суммы
		lassign $res v sv c sc r sr
		lappend vs $v; lappend svs $sv
		lappend cs $c; lappend scs $sc
		lappend rs $r; lappend srs $sr

        # Выводим результаты в окно программы
        display $v $sv $c $sc $r $sr          
	}

	# Вычисляем средние значения
	set c [math::statistics::mean $cs]; set sc [math::statistics::mean $scs]
	set v [math::statistics::mean $vs]; set sv [math::statistics::mean $svs]
	set r [math::statistics::mean $rs]; set sr [math::statistics::mean $srs]

    # Выводим результаты в результирующий файл
	measure::datafile::write $settings(fileName) [list $c $sc $v $sv $r $sr]
}

###############################################################################
# Начало работы
###############################################################################

# Инициализируем протоколирование
set log [measure::logger::init measure]

# Эта команда будет вызвааться в случае преждевременной остановки потока
measure::interop::registerFinalization { finish }

# Читаем настройки программы
measure::config::read

# Проверяем правильность настроек
validateSettings

# Создаём файл с результатами измерений
measure::datafile::create $settings(fileName) $settings(fileFormat) $settings(fileRewrite) [list "I (mA)" "+/- (mA)" "U (mV)" "+/- (mV)" "R (Ohm)" "+/- (Ohm)"] $settings(fileComment)

# Подключаемся к менеджеру ресурсов VISA
set rm [visa::open-default-rm]

# Производим подключение к устройствам и их настройку
if { !$settings(manualPower) } {
	setupPs
}
measure::measure::setupMmsForResistance

# Задаём наборы переполюсовок
# Основное положение переключателей
set connectors [list { 0 0 0 0 }]
if { $settings(switchVoltage) } {
	# Инверсное подключение вольтметра
	lappend connectors {1000 1000 0 0} 
}
if { $settings(switchCurrent) } {
	# Инверсное подключение источника тока
	lappend connectors { 0 0 1000 1000 }
	if { $settings(switchVoltage) } {
		# Инверсное подключение вольтметра и источника тока
		lappend connectors { 1000 1000 1000 1000 } 
	}
}
setConnectors [lindex $connectors 0]

###############################################################################
# Основной цикл измерений
###############################################################################

if { !$settings(manualPower) } {
	# Устанавливаем выходной ток
	setCurrent $settings(startCurrent)

	# Включаем подачу тока на выходы ИП
	hardware::agilent::pse3645a::setOutput $ps 1
}

# Холостое измерение для "прогрева" мультиметров
measure::measure::resistance -n 1

if { $settings(manualPower) } {
	# Ручной режим управления питанием
	# Просто делаем одно измерение и сохраняем результат в файл
	makeMeasurement
} else {
	# Режим автоматического управления питанием
	# Пробегаем по всем токам из заданного диапазона
	for { set curr $settings(startCurrent) } { $curr <= $settings(endCurrent) + 0.1 * $settings(currentStep) } { set curr [expr $curr + $settings(currentStep)] } {
		# проверим, не нажата ли кнопка остановки
		measure::interop::checkTerminated
		
		# выставляем ток на ИП
		setCurrent $curr

		# Делаем очередное измерение из сохраняем результат в файл
		makeMeasurement
	}
}

###############################################################################
# Завершение измерений
###############################################################################

if { [info exists settings(beepOnExit)] && $settings(beepOnExit) } {
    # подаём звуковой сигнал об окончании измерений
	scpi::cmd $mm "SYST:BEEP"
	after 500
}

finish

