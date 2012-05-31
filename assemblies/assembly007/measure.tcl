#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 007
# Измерительный модуль
###############################################################################

package require math::statistics
package require http 2.7
package require measure::logger
package require measure::config
package require measure::datafile
package require measure::interop
package require measure::ranges
package require measure::measure
package require scpi

###############################################################################
# Константы
###############################################################################

###############################################################################
# Подпрограммы
###############################################################################

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]
                   
# Производит регистрацию данных по заданному временному шагу
proc runTimeStep {} {
    set step [measure::config::get prog.timeStep 1000.0]
    
    # Выполняем цикл пока не прервёт пользователь
    while { ![measure::interop::isTerminated] } {
        set t1 [clock milliseconds]
        
        # считываем температуру
        lassign [readTemp] temp tempErr tempDer
        
        # регистрируем сопротивление
        readResistanceAndWrite $temp $tempErr $tempDer 1
        
        set t2 [clock milliseconds]
        measure::interop::sleep [expr int($step - ($t2 - $t1))]
    }
}

# Производит регистрацию данных по заданному температурному шагу
proc runTempStep {} {
    set step [measure::config::get prog.tempStep 1.0]
    lassign [readTemp] temp tempErr
    set prevN [expr floor($temp / $step + 0.5)]
    set prevT [expr $prevN * $step]
    
    # Выполняем цикл пока не прервёт пользователь
    while { ![measure::interop::isTerminated] } {
        # считываем температуру
        lassign [readTemp] temp tempErr tempDer
        
        if { $temp > $prevT && $temp > [expr ($prevN + 1) * $step]  \\
            || $temp < $prevT && $temp < [expr ($prevN - 1) * $step] } {
            # регистрируем сопротивление
            readResistanceAndWrite $temp $tempErr $tempDer 1
            
            set prevT $temp
            set prevN [expr floor($temp / $step + 0.5)]
        } else {
            # измеряем сопротивление, но не регистрируем
            readResistanceAndWrite $temp $tempErr $tempDer 0
        } 
        
        after 500
    }
}

###############################################################################
# Обработчики событий
###############################################################################

# Команда прочитать последние настройки
proc applySettings { lst } {
	global settings

	array set settings $lst
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

# Производим подключение к устройствам и их настройку
setup

# Создаём файлы с результатами измерений
measure::datafile::create $settings(result.fileName) $settings(result.format) $settings(result.rewrite) {
	"Date/Time" "T (K)" "+/- (K)" "dT/dt (K/min)" "I (mA)" "+/- (mA)" "U (mV)" "+/- (mV)" "R (Ohm)" "+/- (Ohm)" 
} $settings(result.comment)

###############################################################################
# Основной цикл измерений
###############################################################################

# Холостое измерение для "прогрева" мультиметров
measure::measure::resistance -n 1

if { $settings(prog.method) == 0 } {
    runTimeStep
} else {
    runTempStep
}

###############################################################################
# Завершение измерений
###############################################################################

finish

