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

###############################################################################
# Константы
###############################################################################

# Кол-во точек усреднения производной температуры по времени
set DTN 50

# Имя файла для регистрации температурной зависимости
set tFileName "t.txt"

# Переменная, используемая для синхронизации
set mutexVar 0

# Переменная для хранения состояния ПИД-регулятора
array set pidState [list lastError 0.0 setPoint 0.0 iaccum 0.0 currentTemperature 0.0]

# Список для хранения значений производной невязки по времени
set derrs [list]

set lastTime ""

# Число отсчётов температуры, необходимых для вычисления тренда
set NUM_OF_READINGS 10

# Списки для хранения отсчётов температуры и времени
set tvalues [list]
set terrvalues [list]
set timevalues [list]
set rtimevalues [list]

# Время начала работы, мс
set START_TIME 0

###############################################################################
# Подпрограммы
###############################################################################

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]

# процедура, реализующая алгоритм ПИД
proc pidCalc { dt } {
	global pidState settings log tFileName derrs DTN

	if { ![info exists pidState(currentTemperature)] || ![info exists pidState(setPoint)] } {
		return 0.0
	}

	# текущее значение невязки	
	set err [expr $pidState(setPoint) - $pidState(currentTemperature)]

    # пропорциональный член
    set pTerm [expr $settings(pid.tp) * $err]
    
    # интегральное накопление
    set pidState(iaccum) [expr $pidState(iaccum) + $err]
    set maxi [measure::config::get pid.maxi]
    if { $maxi != "" } {
        if { $pidState(iaccum) > $maxi } {
            set pidState(iaccum) $maxi 
        } 
        if { $pidState(iaccum) < -$maxi } {
            set pidState(iaccum) [expr -1.0 * $maxi] 
        } 
    }
    
    # интегральный член
    set iTerm [expr $settings(pid.ti) * $pidState(iaccum)]
    
    # вычислим производную невязки по времени с усреднением
    measure::listutils::lappend derrs [expr $err - $pidState(lastError)] $DTN
    
    # дифференциальный член
    set dTerm [expr $settings(pid.td) * [::math::statistics::mean $derrs] ]

    # результирующий ток
	set result [expr $pTerm + $iTerm + $dTerm]

    # регистрируем температуру и управляющие токи
	measure::datafile::write $tFileName TXT [list TIMESTAMP $pidState(currentTemperature) $result $pTerm $iTerm $dTerm]
	
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

###############################################################################
# Обработчики событий
###############################################################################

# Процедура вызывается модулем измерения температуры
proc setTemperature { t tErr } {
	global mutexVar pidState log tvalues terrvalues timevalues rtimevalues NUM_OF_READINGS START_TIME

	set pidState(currentTemperature) $t
	set pidState(currentTemperatureError) $tErr
	
	# Сохраняем отсчёты температуры и времени в списках для вычисления тренда
	measure::listutils::lappend tvalues $t $NUM_OF_READINGS
	measure::listutils::lappend terrvalues $tErr $NUM_OF_READINGS
	measure::listutils::lappend timevalues [clock milliseconds] $NUM_OF_READINGS
	measure::listutils::lappend rtimevalues [expr [clock milliseconds] - $START_TIME] $NUM_OF_READINGS

    if { [llength $tvalues] > 2 } {
        # Вычислим линейную аппроксимацию графика функции температуры, т.е. тренд
      	lassign [::math::statistics::linear-model $rtimevalues $tvalues] a b
    } else {
        set b 0.0
    }
  	
  	# Переведём наклон тренда в К/мин
  	set pidState(currentTrend) [expr 1000.0 * 60.0 * $b]

	# Выводим температуру в окне
	measure::interop::cmd [list setTemperature $t $tErr [expr $pidState(setPoint) - $t] $pidState(currentTrend)]

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
	global pidState log

	${log}::debug "setPoint: enter, t=$t"
	set pidState(setPoint) $t

	measure::interop::setVar runtime(setPoint) [format "%0.1f" $t]
}

# Процедура изменяет параметры ПИДа
proc setPid { tp td ti maxi } {
    global settings
    
    set settings(pid.tp) $tp
    set settings(pid.td) $td
    set settings(pid.ti) $ti
    set settings(pid.maxi) $maxi 
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
measure::datafile::create $tFileName TXT 1 [list "Date/Time" "T (K)" "C (mA)" "P-Term (mA)" "I-Term (mA)" "D-Accum (mA)"]

# Запоминаем время начала работы
set START_TIME [clock milliseconds]

# Основной цикл регулировки
${log}::debug "starting main loop"
while { ![measure::interop::isTerminated] } {
	# отправляем команду на измерение текущей температуры
	thread::send -async $temperatureThreadId [list getTemperature $thisId setTemperature]

	# отправляем команду на установление тока питания
	thread::send -async $powerThreadId [list setCurrent [calcCurrent] $thisId currentSet]

	# ждём изменения переменной синхронизации дважды от двух источников событий
	vwait mutexVar; vwait mutexVar

#	if { $mutexVar > 100 } {
#		break
#	}
}

# Завершаем работу
measure::interop::exit

