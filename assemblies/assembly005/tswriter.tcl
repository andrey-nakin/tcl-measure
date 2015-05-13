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
package require measure::tmap
package require measure::sigma
package require measure::datafile
package require measure::listutils

###############################################################################
# Константы
###############################################################################

# кол-во точек, по которым определяется стационарность
set N 50

# Имя файла для регистрации температурной зависимости
set tFileName "ts.txt"

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
	global mutexVar log N tvalues terrvalues timevalues startTime

	# добавим значение температуры в список
	measure::listutils::lappend tvalues $t $N
	measure::listutils::lappend terrvalues $tErr $N
	measure::listutils::lappend timevalues [expr [clock milliseconds] - $startTime] $N

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

# Создаём файл с результатами измерений
set resultFileName [measure::tmap::create $settings(stc.name)]

measure::datafile::create $tFileName TXT 1 [list "I (mA)" "T (K)" "Terr (K)" "Trend (K/min)" "Std (mK)"]

# В этой переменной храним время начала работы в мс
set startTime [clock milliseconds]

# Главный цикл, обходим все значения тока нагрева печки
set start [measure::config::get stc.start 0.0]
set end  [measure::config::get stc.end 100.0]
set step [measure::config::get stc.step 100.0]
for { set c $start } { $c < $end + 0.5 * $step && ![measure::interop::isTerminated] } { set c [expr $c + $step] } {

	# в переменной c - ток в мА
	# отправляем команду на установление тока питания
	thread::send -async $powerThreadId [list setCurrent [expr 0.001 * $c] $thisId currentSet]

	# очищаем список измеренных температур
	set tvalues [list]
	set terrvalues [list]
	set timevalues [list]

	# ожидаем установления стационарного режима
	while { ![measure::interop::isTerminated] } {
		# отправляем команду на измерение текущей температуры
		thread::send -async $temperatureThreadId [list getTemperature $thisId setTemperature]

		# ждём изменения переменной синхронизации
		vwait mutexVar

        if { [llength $tvalues] > 3 } {
    		# вычислим наклон тренда
        	lassign [::math::statistics::linear-model $timevalues $tvalues] a b
			# переведём степень наклона в К/мин
			set b [expr 1.0e3 * 60.0 * $b]
        } else {
            set b 0.0
        }

        set std [expr 1000.0 * [math::statistics::pstdev $tvalues]]
    	
		if { [llength $tvalues] == $N } {
			# проверим наличие стационарности
			if { abs($b) <= [measure::config::get stc.maxTrend 1.0] && $std <= [measure::config::get stc.maxStd 1.0] } {
				# если значения тренда и отклонения меньше пороговых, завершаем цикл
				break
			}
		}
		
		measure::datafile::write $tFileName [list $c [lindex $tvalues end] [lindex $terrvalues end] $b $std]

        # Сохраним последний отсчёт в разделяемых переменных 		
    	tsv::array set tempState [list temperature [lindex $tvalues end] measureError [lindex $terrvalues end] error 0.0 trend $b timestamp [lindex $timevalues end]]
		
		# Выводим температуру в окне
		measure::interop::cmd [list setTsTemperature [lindex $tvalues end] [lindex $terrvalues end] $b $std]
	}

    if { ![measure::interop::isTerminated] } {
    	# Выводим результаты в результирующий файл
    	measure::tmap::append $resultFileName $c [::math::statistics::mean $tvalues] [measure::sigma::add $std [::math::statistics::mean $terrvalues]]
    }
}

# Завершаем работу модуля
measure::interop::exit

