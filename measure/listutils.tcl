# listutils.tcl --
#
#   List manipulations
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::listutils 0.1.0

namespace eval ::measure::listutils {
  namespace export 
}

# Добавляет значение в список. 
# Если результирующее значение списка больше заданного, удаляет элементы в начале списка.
# Аргументы:
#   lname - имя переменной-списка
#   v - значение для добавления 
#   maxlen - максимально возможная длина списка 
proc ::measure::listutils::lappend { lname v maxlen } {
    upvar $lname lst 
    set s [expr [llength $lst] - $maxlen + 1]
    if { $s > 0 } {
        set lst [lrange $lst $s end]
    }
    ::lappend lst $v
}

# Удаляет элемент из списка по значению.
# Аргументы:
#   lst - имя переменной, хранящей список
#   v - значение, которое нужно удалить
proc ::measure::listutils::lremove { lname v } {
    upvar $lname lst
    set idx [lsearch $lst $v]
    set lst [lreplace $lst $idx $idx]
}