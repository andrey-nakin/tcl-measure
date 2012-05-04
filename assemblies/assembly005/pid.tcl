#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 005
# Модуль термостатирования
# Алгоритм управления: ПИД-регулятор
###############################################################################

package require Thread
package require math::statistics
package require measure::logger
package require measure::config
package require measure::interop
package require measure::datafile
package require measure::listutils
package require measure::math

###############################################################################
# Константы
###############################################################################

# При адаптивном интегральном члене константа определяет паузу в секундах,
# между временем уставки и моментом, когда начинает анализироваться
# производная dT/dt
set ISTOP_DELAY 30

###############################################################################
# Глобальные переменные
###############################################################################

# Переменная, используемая для синхронизации
set mutexVar 0

# Переменная для хранения состояния ПИД-регулятора
array set pidState [list lastError 0.0 setPoint 0.0 iaccum 0.0 currentTemperature 0.0 istop 0]

# Список для хранения значений производной невязки по времени
set derrs [list]

set lastTime ""

# Списки для хранения отсчётов температуры и времени
set tvalues [list]
set terrvalues [list]
set timevalues [list]
set rtimevalues [list]
set dervalues [list]

# Число отсчётов температуры, необходимых для фурье-анализа
set NUM_OF_FOURIER_READINGS 300
set tvalues_fourier [list]

# Время начала работы, мс
set START_TIME 0

###############################################################################
# Подпрограммы
###############################################################################

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]

# процедура, реализующая алгоритм ПИД
proc pidCalc { dt } {
	global pidState settings log derrs dervalues DTN

	if { ![info exists pidState(currentTemperature)] || ![info exists pidState(setPoint)] } {
		return 0.0
	}

	# текущее значение невязки	
	set err [expr $pidState(setPoint) - $pidState(currentTemperature)]

    # пропорциональный член
    set pTerm [expr $settings(pid.tp) * $err]
    
    # вычислим производную невязки по времени с усреднением
    measure::listutils::lappend derrs [expr $err - $pidState(lastError)] $settings(pid.nd)
    
    # дифференциальный член
    set dTerm [expr $settings(pid.td) * [::math::statistics::mean $derrs] ]

	if { $pidState(istop) } {
		if { $pidState(istopDelay) } {
			if { [clock seconds] >= $pidState(istopTime) } {
				set pidState(istopDelay) 0
			}
		} else {
			if { sign([lindex $dervalues 0]) != sign([lindex $dervalues end]) } {
				set pidState(istop) 0
			}
		}
	}

	if { !$pidState(istop) } {
		# интегральное накопление
		set pidState(iaccum) [expr $pidState(iaccum) + $err]

		# проверка на выход за разрешенный предел
		if { $settings(pid.maxi) != "" || $settings(pid.maxiNeg) != "" } {
			::measure::math::validateRange pidState(iaccum) -$settings(pid.maxiNeg) $settings(pid.maxi)
		}
		
		# интегральный член
		set iTerm [expr $settings(pid.ti) * $pidState(iaccum)]
	} else {
		set iTerm 0
	}
    
    # результирующий ток
	set result [expr $pTerm + $iTerm + $dTerm]

	# Выводим токи управления в окне
	measure::interop::cmd [list setPidTerms $pTerm $iTerm $dTerm]

	# сохраним данные для использования на следующем шаге
	set pidState(lastError) $err

	return $result
}

# вычисляет новое значение тока
proc calcCurrent {} {
	global settings lastTime

	set curTime [clock milliseconds]

	if { $lastTime != "" } {
		# время в мс, прошедшее с момента предыдущего измерения
		set dt [expr $curTime - $lastTime]

		# определим новое значение тока питания
		set result [pidCalc $dt]
	} else {
		# это первое измерение
		set result 0.0
	}

	set lastTime $curTime

	return [expr 0.001 * $result]
}

proc finish {} {
	global log

	# закрываем дочерние модули
	destroyChildren
}

proc fourierFileName {} {
    for { set n 1 } { $n < 100 } { incr n } {
        set fn [format "tf-%03d.txt" $n]
        if { ![file exists $fn] } {
            return $fn
        }
    }
    return "tf-000.txt"
}

proc writeFourierData { data } {
    return
    set f [open [fourierFileName] w]
    foreach v $data {
        puts $f $v
    }
    close $f
}

proc createRegFile {} {
    measure::datafile::create [measure::config::get reg.fileName] [measure::config::get reg.format] [measure::config::get reg.rewrite] [list "Date/Time" "T (K)" "Set Point (K)" "dT/dt (K/min)" "Slope (K/min)" "Sigma (K)"]
}

###############################################################################
# Обработчики событий
###############################################################################

# Процедура вызывается модулем измерения температуры
proc setTemperature { t tErr } {
	global mutexVar pidState log tvalues terrvalues timevalues rtimevalues dervalues START_TIME
	global tvalues_fourier settings NUM_OF_FOURIER_READINGS           

	set tm [clock milliseconds]

	# Сохраняем отсчёты температуры и времени в списках для вычисления тренда
	measure::listutils::lappend tvalues $t $settings(pid.nt)
	measure::listutils::lappend terrvalues $tErr $settings(pid.nt)
	measure::listutils::lappend timevalues $tm $settings(pid.nt)
	measure::listutils::lappend rtimevalues [expr $tm - $START_TIME] $settings(pid.nt)

    # вычисляем тренд
    # Вычислим линейную аппроксимацию графика функции температуры, т.е. тренд
    lassign [::measure::math::slope-std $rtimevalues $tvalues] b sb
  	# Переведём наклон тренда в К/мин
  	set b [expr 1000.0 * 60.0 * $b]

    # вычисляем производную
    set nd [expr min($settings(pid.nd), $settings(pid.nt)) - 1]
    # Вычислим линейную аппроксимацию графика функции температуры, т.е. тренд
	set der1 [::measure::math::slope [lrange $rtimevalues end-${nd} end] [lrange $tvalues end-${nd} end]]
  	# Переведём наклон тренда в К/мин
  	set der1 [expr 1000.0 * 60.0 * $der1]
  	
	if { !$pidState(istop) || !$pidState(istopDelay) } {
      	# Добавим производную в список
  	    measure::listutils::lappend dervalues $der1 $settings(pid.nt)
    } 

	lappend tvalues_fourier $t
    if { [llength $tvalues_fourier] >= $NUM_OF_FOURIER_READINGS } {
        writeFourierData $tvalues_fourier 
        set tvalues_fourier [list]    
    }

    # Запишем в состояние ПИДа  	
	set pidState(currentTemperature) $t

	# Сохраняем отсчёт температуры и времени в разделяемых переменных 
	tsv::array set tempState [list temperature $t measureError $tErr error [expr $pidState(setPoint) - $t] trend $b sigma $sb timestamp $tm derivative1 $der1]
	
    # регистрируем температуру и управляющие токи
	measure::datafile::write [measure::config::get reg.fileName] [measure::config::get reg.format] [list \
        TIMESTAMP [format %0.4f $t] $pidState(setPoint) \
        [format %0.3g $der1] [format %0.3g $b] [format %0.3g $sb] ]
	
	# Выводим температуру в окне
	measure::interop::cmd [list setTemperature $t $tErr [expr $pidState(setPoint) - $t] $b $sb $der1]

	# Изменяем значение переменной синхронизации для остановки ожидания
	incr mutexVar
}

# Процедура вызывается модулем регулировки тока питания печки
proc currentSet { current voltage } {
	global mutexVar log

	# Выводим параметры питания в окне
	measure::interop::cmd [list setPower $current $voltage]

	# Изменяем значение переменной синхронизации для остановки ожидания
	incr mutexVar
}

# Процедура изменяет значение уставки
proc setPoint { t } {
	global pidState log settings dervalues ISTOP_DELAY

	set pidState(setPoint) $t

	if { $settings(pid.adaptiveIT) } {
		set pidState(iaccum) 0.0
		set pidState(istop) 1
		set pidState(istopDelay) 1
		set pidState(istopTime) [expr [clock seconds] + $ISTOP_DELAY]
		set dervalues [list]
	}

	measure::interop::setVar runtime(setPoint) [format "%0.1f" $t]
}

# Процедура сбрасывает интегральное накопление
proc resetIAccum { } {
	global pidState log

	set pidState(iaccum) 0.0
}

# Процедура изменяет параметры регистрации температуры
proc setReg { fn fmt rewrite } {
    global settings
    
    set settings(reg.fileName) $fn
    set settings(reg.format) $fmt
    set settings(reg.rewrite) $rewrite
    
    createRegFile
}

proc applySettings { lst } {
    global settings temperatureThreadId powerThreadId 
    
    array set settings $lst
    
	thread::send -async $temperatureThreadId [list applySettings $lst]
	thread::send -async $powerThreadId [list applySettings $lst]
}

###############################################################################
# Начало работы
###############################################################################

# Эта команда будет вызваться в случае преждевременной остановки потока
measure::interop::start { finish }

# Читаем настройки программы
measure::config::read

# Инициализируем протоколирование
set log [measure::logger::init "pid"]

# Проверяем правильность настроек
validateSettings

# Запускаем дочерние модули
createChildren

set thisId [thread::id]

# Текущее значение уставки
setPoint [measure::config::get newSetPoint 0.0]

# Создаём файл для регистрации температуры
createRegFile

# Запоминаем время начала работы
set START_TIME [clock milliseconds]

# Основной цикл регулировки
while { ![measure::interop::isTerminated] } {
	# отправляем команду на измерение текущей температуры
	thread::send -async $temperatureThreadId [list getTemperature $thisId setTemperature]

	# отправляем команду на установление тока питания
	thread::send -async $powerThreadId [list setCurrent [calcCurrent] $thisId currentSet]

	# ждём изменения переменной синхронизации дважды от двух источников событий
	vwait mutexVar; vwait mutexVar
	
#	if { $mutexVar > 10 } { break }
}

# Завершаем работу
measure::interop::exit

