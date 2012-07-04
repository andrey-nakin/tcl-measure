# listutils.tcl --
#
#   List manipulations
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::listutils 0.1.0

package require math::statistics

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

# Прореживает список вдвое учитывая время регистрации точек
# Аргументы:
#   xvalues - имя переменной, хранящей список значений по оси X
#   yvalues - имя переменной, хранящей список значений по оси Y
#   times - имя переменной, хранящей список времён. 
#           Значения должны идти в порядке возрастания
proc ::measure::listutils::timedThinout { xvalues yvalues times } {
    upvar $xvalues x
    upvar $yvalues y
    upvar $times t
    
    if { [llength $x] < 2 || [llength $y] < 2 || [llength $t] < 2 } {
        return
    }
    
    set tt [list]
    for { set i 1 } { $i < [llength $t] } { incr i } {
        ::lappend tt [expr [lindex $t $i] - [lindex $t $i-1]]
    }
    set m [::math::statistics::median $tt]
     
    set xx [list]
    set yy [list]
    set tt [list]
    
    ::lappend xx [lindex $x 0]
    ::lappend yy [lindex $y 0]
    ::lappend tt [lindex $t 0]
    
    for { set i 1 } { $i < [llength $x] && $i < [llength $y] && $i < [llength $t] } { incr i } {
        set diff [expr [lindex $t $i] - [lindex $tt end]]
        if { $diff > $m } {
            ::lappend xx [lindex $x $i]
            ::lappend yy [lindex $y $i]
            ::lappend tt [lindex $t $i]
        } 
    }
    
    set x $xx
    set y $yy
    set t $tt
}

#set x { 1 2 3 4 5 6 7 8 9 }
#set y { 10 20 30 40 50 60 70 80 90 }
#set t { 0 100 150 250 300 400 450 550 600 }
#::measure::listutils::timedThinout x y t
#puts $x
#puts $y
#puts $t
