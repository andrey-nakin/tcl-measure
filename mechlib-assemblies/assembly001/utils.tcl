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
set DERIVATIVE_READINGS 10

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

		lir2.coeff 1.0
    }	
}

proc calcGamma { phi1 phi1Err phi2 phi2Err } {
	global settings

	set res 0.0
	set resErr 0.0

	catch {
		set r $settings(dut.r)
		set rErr $settings(dut.rErr)
		set length $settings(dut.length)
		set lengthErr $settings(dut.lengthErr)

		set phiDiff [expr abs($phi1 - $phi2)]
		set phiDiffErr [measure::sigma::add $phi1Err $phi2Err]

		set a [expr $r / $length]
		set aErr [measure::sigma::div $r $rErr $length $lengthErr]

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
		set momentum $settings(dut.momentum)
		set momentumErr $settings(dut.momentumErr)

		set s [expr sin($phi2)]
		set sErr [measure::sigma::sin $phi2 $phi2Err]

		set a [expr 1.5 * $momentum * $s]
		set aErr [measure::sigma::mul $momentum $momentumErr $s $sErr]

		set radius [expr 1.0e-3 * $settings(dut.r)]
		set radiusErr [expr 1.0e-3 * $settings(dut.rErr)]

		set b [expr 3.1415926535897932384 * $radius * $radius * $radius]
		set bErr [measure::sigma::pow3 $radius $radiusErr]

		set res [expr $a / $b]
		set resErr [measure::sigma::div $a $aErr $b $bErr]
	}

	return [list $res $resErr]
}

# Инициализация приборов
proc setup {} {
    global lir1 lir2 trm

	# ЛИР-16
    set lir1 [::hardware::skbis::lir916::init -com [measure::config::get rs485.serialPort] -addr [measure::config::get lir1.addr] -baud [measure::config::get lir1.baud] ]
    set lir2 [::hardware::skbis::lir916::init -com [measure::config::get rs485.serialPort] -addr [measure::config::get lir2.addr] -baud [measure::config::get lir2.baud] ]

    # Настраиваем ТРМ-201 для измерения температуры
    set trm [::hardware::owen::trm201::init -protocol [measure::config::get trm1.protocol] -baud [measure::config::get trm1.baud] [measure::config::get rs485.serialPort] [measure::config::get trm1.addr]]
    # ::hardware::owen::trm201::setTcType $trm [measure::config::get tc.type] 
}

# Завершаем работу установки, матчасть в исходное.
proc finish {} {
    global lir1 lir2 trm

    if { [info exists lir1] } {
        # Переводим ЛИР-916 № 1 в исходное состояние
    	::hardware::skbis::lir916::done $lir1
		unset lir1
	}

    if { [info exists lir2] } {
        # Переводим ЛИР-916 № 2 в исходное состояние
    	::hardware::skbis::lir916::done $lir2
		unset lir2
	}

    if { [info exists trm] } {
        # Переводим ТРМ-201 в исходное состояние
        ::hardware::owen::trm201::done $trm
        unset trm
    }
}

proc rad2grad { v } {
	return [expr $v * 57.2957795130823]
}

proc display { phi1 phi1Err phi2 phi2Err temp tempErr tempDer { write 0 } } {
	# рассчитываем деформацию
	lassign [calcGamma $phi1 $phi1Err $phi2 $phi2Err] gamma gammaErr

	# рассчитываем напряжение
	lassign [calcTau $phi2 $phi2Err] tau tauErr

	# переводим углы из радиан в градусы        
	set phi1 [rad2grad $phi1]
	set phi1Err [rad2grad $phi1Err]
	set phi2 [rad2grad $phi2]
	set phi2Err [rad2grad $phi2Err]

	if { [measure::interop::isAlone] } {
	    # Выводим результаты в консоль
# !!!
#    	set cv [::measure::format::valueWithErr -mult 1.0e-3 $c $sc A]
#    	set vv [::measure::format::valueWithErr -mult 1.0e-3 $v $sv V]
#    	set rv [::measure::format::valueWithErr $r $sr "\u03A9"]
#    	set pw [::measure::format::value -prec 2 [expr 1.0e-6 * $c * $v] W]
		set phi1v [::measure::format::valueWithErr -noScale -- $phi1 $phi1Err "°"]
		set phi2v [::measure::format::valueWithErr -noScale -- $phi2 $phi2Err "°"]
    	set tv [::measure::format::valueWithErr $temp $tempErr K]
    	puts "φ1=$phi1v\tφ2=$phi2v\t$T=$tv"
	} else {
	    # Выводим результаты в окно программы
        measure::interop::cmd [list display $phi1 $phi1Err $phi2 $phi2Err $temp $tempErr $tempDer $gamma $gammaErr $tau $tauErr $write]
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
# !!!
set TRM_T 293
proc readTempTrm {} {
	global	TRM_T
	set TRM_T [expr $TRM_T + 0.02 * rand() - 0.0075]
	return [list $TRM_T [expr $TRM_T * 0.001] ]
	# !!!

    global trm
    return [::hardware::owen::trm201::readTemperature $trm]
}


proc readAngles {} {
    global lir1 lir2

	lassign [::hardware::skbis::lir916::readAngle $lir1] phi1 phi1Err
	lassign [::hardware::skbis::lir916::readAngle $lir2] phi2 phi2Err

	return [list $phi1 $phi1Err $phi2 $phi2Err]
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

