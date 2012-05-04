#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 004
# Процедуры общего назначения
###############################################################################

# Процедура проверяет правильность настроек, при необходимости вносит поправки
proc validateSettings {} {
    global settings

    measure::config::validate {
        mmtc.mm.nplc 10
        pid.nd 5
        pid.nt 15
		pid.adaptiveIT 0
		pid.maxi ""
		pid.maxiNeg ""
    }
}

proc createChildren { } {
	global log temperatureThreadId powerThreadId httpThreadId
	
	lassign [measure::interop::createChildren [list    \
	   [measure::config::get tempmodule mmtc]  \
	   [measure::config::get powermodule ps]   \
	   http    \
    ]] temperatureThreadId powerThreadId httpThreadId
}

proc destroyChildren {} {
	global log
	measure::interop::destroyChildren
}
