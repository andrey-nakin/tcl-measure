# utils.tcl --
#
#   Work with Agilent VISA devices
#   http://www.home.agilent.com/agilent/product.jspx?id=692834&pageMode=OV&pid=692834&lc=eng&ct=PRODUCT&cc=US&pselect=SR.PM-Search%20Results.Overview
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package provide hardware::agilent::utils 0.1.0

namespace eval hardware::agilent::utils {
  namespace export \
    query
}

# Отправляет команду устройству, ждёт ответа и возвращает ответ
# Аргументы
#   channel - канал с открытым портом для связи с устройством
#   cmd - команда для отправки
proc hardware::agilent::utils::query { channel cmd } {
    clearReadBuffer $channel
    # имеем три попытки для связи с устройством
    for { set attempts 3 } { $attempts > 0 } { incr attempts -1 } {
        puts $channel $cmd
        set ans [gets $channel]
        if { [string length $ans] > 0 } {
            return $ans
        }
        after 500
    }
    error "Error quering command $cmd"
}

proc hardware::agilent::utils::clearReadBuffer { channel } {
    catch { read $channel }
}
