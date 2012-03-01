#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 004
# Процедуры общего назначения
###############################################################################

# Процедура проверяет правильность настроек, при необходимости вносит поправки
proc validateSettings {} {
    global settings

	# Число циклов питания на одно измерение напряжения
	if { ![info exists settings(mmtc.mm.nplc)] || !$settings(mmtc.mm.nplc) || $settings(mmtc.mm.nplc) < 0 } {
		# Если не указано в настройках, по умолчанию равно 10
		set settings(mmtc.mm.nplc) 10
	}
}

proc createChildren { } {
	global temperatureThreadId powerThreadId httpThreadId
	
	lassign [measure::interop::createChildren [list    \
	   [measure::config::get tempmodule mmtc]  \
	   [measure::config::get powermodule ps]   \
	   http    \
    ]] temperatureThreadId powerThreadId httpThreadId 
}

proc destroyChildren {} {
	measure::interop::destroyChildren { powerThreadId temperatureThreadId httpThreadId }
}
