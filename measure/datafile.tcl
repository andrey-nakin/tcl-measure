# datafile.tcl --
#
#   Write resulting data file
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::datafile 0.1.0

namespace eval measure::datafile {
  namespace export create write
}

array set measure::data::textFormat {separator "\t" comment "# "}
array set measure::data::csvFormat {separator "," comment ""}

# Создаёт результирующий файл и записывает строку с заголовком
# Аргументы
#   fileName - имя файла данных
#   format - формат файла (TXT или CSV)
#   rewrite - переписывать или дополнять файл
#   headers - список заголовков столбцов
proc measure::data::create { fileName format rewrite headers } {
    global measure::data::textFormat measure::data::csvFormat

	if { [string trim $fileName] == "" } {
		return
	}

    set writeHeader 0
    if { $rewrite } {
        set f [open $fileName w]
        set writeHeader 1
    } else {
        if { ![file exists $fileName] || ![file size $fileName] } {
            set writeHeader 1
        }
        set f [open $fileName a]
    }
    
    if { [string equal -nocase $format csv] } {
        set fmt csvFormat
    } else {
        set fmt textFormat
    }
    
    if { $writeHeader } {
        set first 1
        eval "set comment \$${fmt}(comment)"
        eval "set separator \$${fmt}(separator)"
        puts -nonewline $f $comment
        foreach v $headers {
            if { $first } {
                set first 0
            } else {
                puts -nonewline $f $separator 
            }
            puts -nonewline $f $v
        }
        puts $f ""
    }
    
    close $f
}

# Записывает строку данных в результирующий файл
# Аргументы
#   fileName - имя файла данных
#   format - формат файла (TXT или CSV)
#   data - список значений
proc measure::data::write { fileName format data } {
    global measure::data::textFormat measure::data::csvFormat

	if { [string trim $fileName] == "" } {
		return
	}

    set f [open $fileName a]
    
    if { [string equal -nocase $format csv] } {
        set fmt csvFormat
    } else {
        set fmt textFormat
    }
    
    set first 1
    eval "set separator \$${fmt}(separator)"
    foreach v $data {
        if { $first } {
            set first 0
        } else {
            puts -nonewline $f $separator 
        }
        puts -nonewline $f $v
    }
    puts $f ""
    close $f
}
