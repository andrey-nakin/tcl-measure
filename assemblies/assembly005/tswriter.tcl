#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 005
# Модуль записи температурной схемы
###############################################################################

package require Thread
package require math::statistics
package require measure::logger
package require measure::config
package require measure::interop
package require measure::datafile

###############################################################################
# Константы
###############################################################################

# кол-во точек, по которым определяется стационарность
set N 50

# Переменная, используемая для синхронизации
set mutexVar 0

# переменная со списком значений температуры
set tvalues [list]

# переменная со списком отсчётов времени
set timevalues [list]

###############################################################################
# Подпрограммы
###############################################################################

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]

proc finish {} {
	global log

	# закрываем дочерние модули
	destroyChildren
}

###############################################################################
# Обработчики событий
###############################################################################

# Процедура вызывается модулем измерения температуры
proc setTemperature { t tErr } {
	global mutexVar log N tvalues timevalues

	# добавим значение температуры в список
	if { [llength $tvalues] == $N } {
		set tvalues [lrange $tvalues 1 end]
		set timevalues [lrange $timevalues 1 end]
	}
	lappend tvalues $t
	lappend timevalues [clock milliseconds]

	# Изменяем значение переменной синхронизации для остановки ожидания
	incr mutexVar
}

# Процедура вызывается модулем регулировки тока питания печки
proc currentSet { current voltage } {
	global mutexVar log

	# Выводим параметры питания в окне
	measure::interop::cmd [list setTsPower $current $voltage]
}

###############################################################################
# Начало работы
###############################################################################

# Эта команда будет вызваться в случае преждевременной остановки потока
measure::interop::start { finish }

# Читаем настройки программы
measure::config::read

# Инициализируем протоколирование
set log [measure::logger::init "tswriter"]

# Проверяем правильность настроек
validateSettings

# Запускаем дочерние модули
createChildren

set thisId [thread::id]

set resultFileName "$settings(stc.name).tsc"

# Создаём файл с результатами измерений
measure::datafile::create $resultFileName TXT 1 [list "I (mA)" "T (K)"]

# Главный цикл, обходим все значения тока нагрева печки
set step [measure::config::get stc.step 100.0]
for { set c [measure::config::get stc.start 0.0] }
    { $c < [measure::config::get stc.end 100.0] + 0.5 * $step && ![measure::interop::isTerminated] }
    { set c [expr $c + $step] } {

	# в переменной c - ток в мА
	# отправляем команду на установление тока питания
	thread::send -async $powerThreadId [list setCurrent [expr 0.001 * $c] $thisId currentSet]

	# очищаем список измеренных температур
	set tvalues [list]
	set timevalues [list]

	# ожидаем установления стационарного режима
	while { ![measure::interop::isTerminated] } {
		# отправляем команду на измерение текущей температуры
		thread::send -async $temperatureThreadId [list getTemperature $thisId setTemperature]

		# ждём изменения переменной синхронизации
		vwait mutexVar

		if { [llength $tvalues] == $N } {
			# вычислим наклон тренда
			lassign [::math::statistics::linear-model $timevalues $tvalues] a b
			
			# переведём степень наклона в мК/сек
			set b [expr 1.0e6 * $b]

			# Выводим температуру в окне
			measure::interop::cmd [list setTsTemperature $t 0.0 $b [math::statistics::pstdev $tvalues]]

			# проверим наличие стационарности
			if { abs($b) <= [measure::config::get stc.maxTrend 1.0] } {
				# если значение тренда меньше порогового, завершаем цикл
				break
			}
		}
	}

	# Выводим результаты в результирующий файл
	measure::datafile::write $resultFileName TXT [list $c [lindex $tvalues end]]
}

# Завершаем работу модуля
measure::interop::exit

