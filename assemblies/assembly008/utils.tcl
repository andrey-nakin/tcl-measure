#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 007
# Процедуры общего назначения
###############################################################################

package require hardware::agilent::mm34410a
package require hardware::owen::mvu8
package require measure::thermocouple
package require measure::listutils
package require measure::math
package require measure::sigma
package require hardware::agilent::pse3645a
package require hardware::owen::trm201
package require hardware::skbis::lir916

# Число измерений, по которым определяется производная dT/dt
set DERIVATIVE_READINGS 3

# Процедура проверяет правильность настроек, при необходимости вносит поправки
proc validateSettings {} {
    measure::config::validate {
        result.fileName ""
        result.format TXT
        result.rewrite 1
        result.comment ""

		dut.rErr 0.0
		dut.lengthErr 0.0
		dut.momentumErrErr 0.0
    }	
}

proc calcGamma { phi1 phi1Err phi2 phi2Err } {
	global settings

	set res 0.0
	set resErr 0.0

	catch {
		set phiDiff [expr $phi1 - $phi2]
		set phiDiffErr [measure::sigma::add $phi1Err $phi2Err]

		set a [expr settings(dut.r) / settings(dut.length)]
		set aErr [measure::sigma::div settings(dut.r) settings(dut.rErr) settings(dut.length) settings(dut.lengthErr)]

		set res [expr $a * $phiDiff]
		set resErr [measure::sigma::mul $a $aErr $phiDiff $phiDiffErr]
	}

	set res [expr 100.0 * $res]
	set resErr [expr 100.0 * $resErr]

	return [list $res $resErr]
}

proc calcTau { phi2 phi2Err } {
	global settings

	set res 0.0
	set resErr 0.0

	catch {
		set s [expr sin($phi2)]
		set sErr [measure::sigma::sin $phi2 $phi2Err]

		set a [expr 1.0 * settings(dut.momentum) * s]
		set aErr [measure::sigma::mul settings(dut.momentum) settings(dut.momentumErr) $s $sErr]

		set radius [expr 1.0e-3 * settings(dut.r)]
		set radiusErr [expr 1.0e-3 * settings(dut.rErr)]

		set b [expr 3.1415926535897932384 * $radius * $radius * $radius]
		set bErr [measure::sigma::pow3 $radius $radiusErr]

		set res [expr $a / $b]
		set resErr [measure::sigma::div $a $aErr $b $bErr]
	}

	return [list $res $resErr]
}

# Инициализация приборов
proc setup {} {
    global trm

	# ЛИР-16
    ::hardware::skbis::lir916::init [measure::config::get rs485.serialPort] [measure::config::get lir1.rs485Addr]
    ::hardware::skbis::lir916::init [measure::config::get rs485.serialPort] [measure::config::get lir2.rs485Addr]

    # Настраиваем ТРМ-201 для измерения температуры
    set trm [::hardware::owen::trm201::init [measure::config::get tcm.serialAddr] [measure::config::get tcm.rs485Addr]]
    ::hardware::owen::trm201::setTcType $trm [measure::config::get tc.type] 
}

# Завершаем работу установки, матчасть в исходное.
proc finish {} {
    global trm

    ::hardware::skbis::lir916::done [measure::config::get rs485.serialPort] [measure::config::get lir1.rs485Addr]
    ::hardware::skbis::lir916::done [measure::config::get rs485.serialPort] [measure::config::get lir2.rs485Addr]

    if { [info exists trm] } {
        # Переводим ТРМ-201 в исходное состояние
        ::hardware::owen::trm201::done $trm
        unset trm
    }
}

proc display { v sv c sc r sr temp tempErr tempDer write } {
	if { [measure::interop::isAlone] } {
	    # Выводим результаты в консоль
    	set cv [::measure::format::valueWithErr -mult 1.0e-3 $c $sc A]
    	set vv [::measure::format::valueWithErr -mult 1.0e-3 $v $sv V]
    	set rv [::measure::format::valueWithErr $r $sr "\u03A9"]
    	set pw [::measure::format::value -prec 2 [expr 1.0e-6 * $c * $v] W]
    	set tv [::measure::format::valueWithErr $temp $tempErr K]
    	puts "C=$cv\tV=$vv\tR=$rv\tP=$pw\tT=$tv"
	} else {
	    # Выводим результаты в окно программы
        measure::interop::cmd [list display $v $sv $c $sc $r $sr $temp $tempErr $tempDer $write]
	}
}

set tempValues [list]
set timeValues [list]
set startTime [clock milliseconds]

# Измеряем температуру и возвращаем вместе с инструментальной погрешностью и производной
proc readTemp {} {
    global tempValues timeValues startTime DERIVATIVE_READINGS
    
    lassign [readTempTrm] t tErr

    # накапливаем значения в очереди для вычисления производной 
    measure::listutils::lappend tempValues $t $DERIVATIVE_READINGS
    measure::listutils::lappend timeValues [expr [clock milliseconds] - $startTime] $DERIVATIVE_READINGS
    if { [llength $tempValues] < $DERIVATIVE_READINGS } {
        set der 0.0
    } else {
        set der [expr 60000.0 * [measure::math::slope $timeValues $tempValues]] 
    }
            
    return [list $t $tErr $der]
}

# Снимаем показания вольтметра на термопаре и возвращаем температуру 
# вместе с инструментальной погрешностью
proc readTempTrm {} {
    global trm
    return [::hardware::owen::trm201::readTemperature $trm]
}

# Измеряем сопротивление и регистрируем его вместе с температурой
proc readResistanceAndWrite { temp tempErr tempDer { write 0 } { manual 0 } { dotrace 1 } } {
	# TODO
}

# записывает точку в файл данных с попутным вычислением удельного сопротивления
proc writeDataPoint { fn temp tempErr tempDer phi1 phi1Err phi2 phi2Err gamma gammaErr tau tauErr manual } {
    global $cfn

	if { $manual } {
	   set manual true
    } else {
        set manual ""
    }
    
	measure::datafile::write $fn [list \
        TIMESTAMP \
		[format %0.3f $temp] [format %0.3f $tempErr] [format %0.3f $tempDer]  \
        [format %0.6g $phi1] [format %0.2g $phi1Err]    \
        [format %0.6g $phi2] [format %0.2g $phi2Err]    \
        [format %0.6g $gamma] [format %0.2g $gammaErr]    \
        [format %0.6g $tau] [format %0.2g $tauErr]    \
        $manual	\
	]
}

