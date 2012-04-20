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
            append result "temperature\t$state(temperature)"
            append result " measureError\t$state(measureError)"
            append result " error\t$state(error)"
            append result " trend\t$state(trend)"
            append result " sigma\t$state(sigma)"
            append result " timestamp\t$state(timestamp)"
            append result " derivative1\t$state(derivative1)"
        }
        
        text/html {
            append result "<html><body>"
            append result "<p>Температура (К):\t$state(temperature)"
            append result "<p>1-я производная (К/мин):\t$state(derivative1)"
            append result "<p>Погрешность измерения (К):\t$state(measureError)"
            append result "<p>Невязка (К):\t$state(error)"
            append result "<p>Тренд (К/мин):\t$state(trend)"
            append result "<p>Разброс вокруг тренда (К):\t$state(sigma)"
            append result "<p>Временная отметка (мс):\t$state(timestamp)"
            append result "</body></html>"
        }
        
        text/xml {
            append result "<root><state>"
            append result "<temperature>$state(temperature)</temperature>"
            append result "<measureError>$state(measureError)</measureError>"
            append result "<error>$state(error)</error>"
            append result "<trend>$state(trend)</trend>"
            append result "<sigma>$state(sigma)</sigma>"
            append result "<timestamp>$state(timestamp)</timestamp>"
            append result "<derivative1>$state(derivative1)</derivative1>"
            append result "</state></root>"
        }
        
        text/json {
            append result "{"
            append result "temperature: $state(temperature)"
            append result ",measureError:$state(measureError)"
            append result ",error:$state(error)"
            append result ",trend:$state(trend)"
            append result ",sigma:$state(sigma)"
            append result ",timestamp:$state(timestamp)"
            append result ",derivative1:$state(derivative1)"
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
	measure::config::read

	# Проверяем правильность настроек
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
}

###############################################################################
# Начало работы
###############################################################################

# Инициализируем протоколирование
set log [measure::logger::init http]
