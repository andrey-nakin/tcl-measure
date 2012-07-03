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

# Прореживает список, удаляя каждый n-ый элемент
# Аргументы:
#   lname - имя переменной, хранящей список
#   n - степень прореживания
proc ::measure::listutils::thinout { lname { n 2 } } {
    upvar $lname in
    set res [list]
    set c $n
    foreach v $in {
        if { $c > 1 } {
            ::lappend res $v
            set c [expr $c - 1]
        } else {
            set c $n
        }
    }
    set in $res
}

#array set aa {}
#set aa(a) { 1 2 3 4 5 6 7 8 9 }
#::measure::listutils::thinout aa(a) 2
#puts $aa(a)
