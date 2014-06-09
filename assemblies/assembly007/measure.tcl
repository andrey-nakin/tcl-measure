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
package require measure::listutils
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
    global doMeasurement
    
    set step [measure::config::get prog.time.step 1000.0]
    
    # Выполняем цикл пока не прервёт пользователь
    while { ![measure::interop::isTerminated] } {
        set t1 [clock milliseconds]
        
        # считываем температуру
        lassign [readTemp] temp tempErr tempDer
        
        # регистрируем сопротивление
        readResistanceAndWrite $temp $tempErr $tempDer 1 $doMeasurement
        
        set t2 [clock milliseconds]
        after [expr int($step - ($t2 - $t1))] set doMeasurement 0
        vwait doMeasurement
        after cancel set doMeasurement 0
    }
}

# Производит регистрацию данных по заданному температурному шагу
set tempDerValues {}

proc runTempStep {} {
    global doMeasurement tempDerValues scpi::commandDelays tcmm
    global log
    
    if { [info exists tcmm] } {
        set scpi::commandDelays($tcmm) 0.0
    }
    
    set step [measure::config::get prog.temp.step 1.0]
    lassign [readTemp] temp tempErr
    set prevN [expr floor($temp / $step + 0.5)]
    set prevT [expr $prevN * $step]
    
    # Выполняем цикл пока не прервёт пользователь
    while { ![measure::interop::isTerminated] } {
        # текущее время
        set t [clock milliseconds]
    
        # считываем температуру
        lassign [readTemp] temp tempErr tempDer
        measure::listutils::lappend tempDerValues $tempDer 10 
        
        if { $doMeasurement
            || $temp > $prevT && $temp > [expr ($prevN + 1) * $step]  \
            || $temp < $prevT && $temp < [expr ($prevN - 1) * $step] } {

            # регистрируем сопротивление
            readResistanceAndWrite $temp $tempErr $tempDer 1 $doMeasurement
            
            set prevT [expr floor($temp / $step + 0.5) * $step]
            set prevN [expr floor($temp / $step + 0.5)]
        } else {
            # измеряем сопротивление, но не регистрируем
            readResistanceAndWrite $temp $tempErr $tempDer 0
        } 

        # определим, какую паузу нужно выдержать в зависимости от dT/dt
        set der [math::statistics::mean $tempDerValues]
        set delay [expr 0.05 * $step / (abs($der) / 60000.0)]
        set delay [expr min($delay, 1000)]
        set delay [expr int($delay - ([clock milliseconds] - $t))]
        if { $delay > 50 } {
            after $delay set doMeasurement 0
            vwait doMeasurement
            after cancel set doMeasurement 0
        }
    }
}

# Производит регистрацию данных по командам оператора
proc runManual {} {
    global doMeasurement

    # Выполняем цикл пока не прервёт пользователь
    while { ![measure::interop::isTerminated] } {
        # считываем температуру
        lassign [readTemp] temp tempErr tempDer
        
        # регистрируем сопротивление
        readResistanceAndWrite $temp $tempErr $tempDer $doMeasurement $doMeasurement
        
        after 500 set doMeasurement 0
        vwait doMeasurement
        after cancel set doMeasurement 0
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

# Произвести очередное измерение
proc makeMeasurement {} {
    global doMeasurement
    
    set doMeasurement 1
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
	"Date/Time" "T (K)" "+/- (K)" "dT/dt (K/min)" "I (mA)" "+/- (mA)" "U (mV)" "+/- (mV)" "R (Ohm)" "+/- (Ohm)" "Rho (Ohm*cm)" "+/- (Ohm*cm)" "Manual" "U polarity" "I polarity" 
} "$settings(result.comment), [measure::measure::dutParams]"

if { $settings(switch.voltage) || $settings(switch.current) } {
    # в случае переполюсовок создадим ещё один файл с "очищенными" данными
    measure::datafile::create [refinedFileName $settings(result.fileName)] $settings(result.format) $settings(result.rewrite) {
    	"Date/Time" "T (K)" "+/- (K)" "dT/dt (K/min)" "I (mA)" "+/- (mA)" "U (mV)" "+/- (mV)" "R (Ohm)" "+/- (Ohm)" "Rho (Ohm*cm)" "+/- (Ohm*cm)" 
    } "$settings(result.comment), [measure::measure::dutParams]"
}

measure::datafile::create $settings(trace.fileName) $settings(result.format) $settings(result.rewrite) {
	"Date/Time" "T (K)" "dT/dt (K/min)" "R (Ohm)" 
} "$settings(result.comment), [measure::measure::dutParams]"

###############################################################################
# Основной цикл измерений
###############################################################################

# Холостое измерение для "прогрева" мультиметров
measure::measure::resistance -n 1
readTemp

set doMeasurement 0
if { $settings(prog.method) == 0 } {
    runTimeStep
} elseif { $settings(prog.method) == 1 } {
    runTempStep
} else {
    runManual
}

###############################################################################
# Завершение измерений
###############################################################################

finish

