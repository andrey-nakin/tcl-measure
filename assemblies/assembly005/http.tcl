#!/usr/bin/tclsh

###############################################################################
# Измерительная установка № 005
# Модуль управления по протоколу HTTP 
###############################################################################

package require Thread
package require uri
package require measure::logger
package require measure::config
package require measure::http::server

###############################################################################
# Глобальные переменные
###############################################################################

###############################################################################
# Подпрограммы
###############################################################################

# Подгружаем модель с процедурами общего назначения
source [file join [file dirname [info script]] utils.tcl]

# Процедура вызывается при запросе текущей температуры
proc ::measure::http::server::get::state { paramList headerList args } {
    global log
    
    ${log}::debug "get::stat $paramList $headerList $args"

    # Считываем последний отсчёт из разделяемых переменных
    array set state [tsv::array get tempState]

    # Определим формат, в котором нужно вернуть данные
    set ct [measure::http::server::desiredContentType \
        $paramList $headerList {text/plain text/html text/xml text/json} format]
        
    switch -exact -- $ct {
        text/plain {
            append result "temperature\t$state(temperature)\n"
            append result "measureError\t$state(measureError)\n"
            append result "error\t$state(error)\n"
            append result "trend\t$state(trend)\n"
            append result "timestamp\t$state(timestamp)\n"
        }
        
        text/html {
            append result "<html><body>"
            append result "<p>Температура (К):\t$state(temperature)\n"
            append result "<p>Погрешность измерения (К):\t$state(measureError)\n"
            append result "<p>Невязка (К):\t$state(error)\n"
            append result "<p>Тренд (К/мин):\t$state(trend)\n"
            append result "<p>Временная отметка (мс):\t$state(timestamp)\n"
            append result "</body></html>"
        }
        
        text/xml {
            append result "<root><state>\n"
            append result "<temperature>$state(temperature)</temperature>\n"
            append result "<measureError>$state(measureError)</measureError>\n"
            append result "<error>$state(error)</error>\n"
            append result "<trend>$state(trend)</trend>\n"
            append result "<timestamp>$state(timestamp)</timestamp>\n"
            append result "</state></root>"
        }
        
        text/json {
            append result "{"
            append result "temperature: $state(temperature)"
            append result ",measureError:$state(measureError)"
            append result ",error:$state(error)"
            append result ",trend:$state(trend)"
            append result ",timestamp:$state(timestamp)"
            append result "}"
        }
    }     
    
    return [list $ct $result]
}

# Процедура вызывается при измерении уставки
proc measure::http::server::post::setpoint { paramList headerList args } {
    global log parentThreadId
    
    ${log}::debug "post::setpoint $paramList $headerList $args"
    
    array set params $paramList
    thread::send -async $parentThreadId [list setPoint $params(value)]
}

# Инициализируем HTTP-сервер
proc createHttpServer { senderId } {
    global parentThreadId
    
    measure::http::server::init [measure::config::get http.port 8080]
    set parentThreadId $senderId 
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
    createHttpServer $senderId
    
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

############################
# отладка
############################

proc dummy { args } {
}

proc setPoint { vvv } {
    global log
    
    ${log}::debug "SET POINT $vvv"
}

#init [thread::id] dummy

#thread::wait 