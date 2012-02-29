#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 005
# Модуль управления по протоколу HTTP 
###############################################################################

package require uri
package require measure::logger
package require measure::config

###############################################################################
# Подпрограммы
###############################################################################

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]

proc httpGet { channel query params } {
    global log
    
    ${log}::debug "httpGet $channel query=$query params=$params"

    array set params $params
    
    if { $query == "state" } {
    }
}

proc httpPost { channel query } {
}
 
proc httpStart { channel } {
    global log

    lassign [split [read $channel]] method url protocol
    array set url [uri::split $url http]
    ${log}::debug "httpStart [uri::split $url http]"
    
    # read HTTP parameters
    set params [list]
    while {1} {
        lassign [split [read $channel]] name value
    }
    lappend params $name; lappend params $value
    
    if { $method == "GET" } {
        httpGet $channel $url(path) $params
    } elseif { $method == "POST" } {
        httpPost $method $url(path) $params
    }
    close $channel
}

# Процедура вызывается при подключении клиента
proc accept {channel clientaddr clientport} {
    global log
    ${log}::debug "Connection from $clientaddr registered"
    
    fconfigure $channel -buffering line -blocking 0
    fileevent $channel readable [list httpStart $channel]
}

# Инициализируем HTTP-сервер
proc createHttpServer {} {
    socket -server accept [measure::config::get http.port 8080]
}

###############################################################################
# Обработчики событий
###############################################################################

# Процедура вызывается при инициализации модуля
proc init { senderId senderCallback } {
	global log

	# Читаем настройки программы
	${log}::debug "init: reading settings"
	measure::config::read

	# Проверяем правильность настроек
	${log}::debug "init: validating settings"
	validateSettings

    # Создаём HTTP-сервер
    createHttpServer
    
	# Отправляем сообщение в поток управления
	thread::send -async $senderId [list $senderCallback [thread::id]]
}

# Процедура вызывается при завершени работы модуля
# Приводим устройства в исходное состояние
proc finish {} {
    global log

    ${log}::debug "finish: enter"
    
    ${log}::debug "finish: exit"
}

###############################################################################
# Начало работы
###############################################################################

# Инициализируем протоколирование
set log [measure::logger::init http]
