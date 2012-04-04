# tsclient.tcl --
#
#   Math functions
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::tsclient 0.1.0

namespace eval ::measure::tsclient {
  namespace export
}

# Процедура настраивает конфигурацию клиента
proc ::measure::tsclient::config { args } {
	variable configuration

	set configOptions {
		{host.arg	"localhost"	"Host name or address"}
		{port.arg	8080		"TCP port number"}
	}

	array set configuration {}
	array set configuration [array get configOptions]
}

# Процедура считывает текущие показания термометра
proc ::measure::tsclient::state { } {
	variable configuration
	variable tsStateUrl

	if { ![info exists tsStateUrl] } {
		# сформируем адрес запроса
		set tsStateUrl [::uri::join \
			scheme http \
			host $configuration(host) \
			port $configuration(port) \
			path state]

        # настроим библиотеку HTTP
    	if { [info exists ::http::http(-accept)] } {
        	set ::http::http(-accept) text/plain
        }
	}

	# делаем три попытки связаться с термостатом
	for { set i 0 } { $i < 3 } { incr i } {
    	# отправим запрос и ждём завершения
    	set token [::http::geturl $tsStateUrl -protocol 1.0 -keepalive 1 -timeout 5000]
    	set code [::http::ncode $token]
    	set data [::http::data $token]

		if { $code == 200 } {
			# успешно
			
        	return $data
		}
		
    	::http::cleanup $token
		
		# выдержим паузу
		after 3000
    }

	error "Cannot connect to thermostat via URL $tsStateUrl"
}

# Отправляем команду термостату с новой уставкой
proc ::measure::tsclient::setPoint { t } {
	variable configuration

	# делаем три попытки связаться с термостатом
	for { set i 0 } { $i < 3 } { incr i } {
		# сформируем адрес запроса
		set url [::uri::join \
			scheme http \
			host $configuration(host) \
			port $configuration(port) \
			path setpoint ]
		# отправим запрос и ждём завершения
		set token [::http::geturl $url -query [::http::formatQuery value $t] -timeout 5000]
		set code [::http::ncode $token]
		::http::cleanup $token

		if { $code == 200 } {
			# успешно
			
			# выведем уставку на экран
			measure::interop::cmd [list setPointSet $t]
			
			return
		}

		# выждем паузу перед повторной попыткой
		after 3000
	}

	error "Cannot connect to thermostat via URL $url"
}

