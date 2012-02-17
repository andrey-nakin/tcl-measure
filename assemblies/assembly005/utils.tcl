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

# Процедура возвращает список всех температурных схем, 
# обнаруженных в текущей директории
proc tschemeNames {} {
	set files [glob "./*.tsc"]
	set result [list]
	foreach f $files {
		set f [file tail $f]
		set ext [file extension $f]
		lappend result [string range $f 0 end-[string length $ext]]
	}
	return $result
}
