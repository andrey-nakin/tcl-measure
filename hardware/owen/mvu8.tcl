# mvu8.tcl --
#
#   Work with OWEN MVU-8 8-channel switch
#   http://www.owen.ru/catalog/51054088
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide hardware::owen::mvu8 0.1.0

namespace eval hardware::owen::mvu8 {
  namespace export init
}

namespace eval hardware::owen::mvu8::modbus {
  namespace export init
}

# addresses of registers
set hardware::owen::mvu8::CHANNEL	0x0000

# Процедура устанавливает состояние одного или нескольких каналов МВУ-8
# Связь с устройством по протоколу Modbus RTU
# Аргументы
#     port - имя COM-порта для связи с устройством
#     id - сетевой адрес устройства
#     first - номер первого канала (начиная с 0)
#     values - список значений для каналов. Значения целочисленные в диапазоне [0, 1000]
proc hardware::owen::mvu8::modbus::setChannels { port id first values } {
	package require modbus
	global log
	
	modbus::configure -mode RTU -com $port

    # имеем три попытки для установки состояния каналов	
	for { set attempts 3 } { $attempts > 0 } { incr attempts -1 } {
    	# Формируем команду для установки состояния каналов
        set cmd "set res \[modbus::cmd 16 $id $first"
        foreach v $values {
    	    append cmd " $v"
        }              
        append cmd "\]"
        
        # Отправляем команду
        eval $cmd
        
        # Считываем текущее состояние каналов для сравнения
        set state [modbus::cmd 0x03 $id $first [llength $values]]
        set bad 0
        for { set i 0 } { $i < [llength $values] } { incr i } {
            if { [lindex $values $i] != [lindex $state $i] } {
                # несовпадение!
                ${log}::error "MVU-8 channel $i state mismatch: expected=[lindex $values $i], actual=[lindex $state $i]"
                set bad 1
                break
            }
        }
        
        if { !$bad } {
            # успешное завершение
            return
        }
    }
    
    error "Cannot set MVU-8 channels" 
}

# Процедура проверяет связь с МВУ-8
# Аргументы
#     port - имя COM-порта для связи с устройством
#     id - сетевой адрес устройства
# Результат
#   0 - нет связи
#   1 - связь установлена
proc hardware::owen::mvu8::modbus::test { port id } {
	package require modbus
	global log

	set ok 0
    catch {
    	::modbus::configure -mode RTU -com $port
        set state [::modbus::cmd 0x03 $id 0 8]
        set ok [expr [llength $state] == 9]
    } 
	return $ok
}

