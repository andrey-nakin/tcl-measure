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

# Список поддерживаемых форматов
set measure::datafile::FORMAT_LIST { TXT CSV }

array set measure::datafile::textFormat {separator "\t" comment "# "}
array set measure::datafile::csvFormat {separator "," comment ""}
array set measure::datafile::config {} 

# Создаёт результирующий файл и записывает строку с заголовком
# Аргументы
#   fileName - имя файла данных
#   format - формат файла (TXT или CSV)
#   rewrite - переписывать или дополнять файл
#   headers - список заголовков столбцов
proc measure::datafile::create { fileName format rewrite headers } {
    global measure::datafile::textFormat measure::datafile::csvFormat
    variable config

	if { [string trim $fileName] == "" } {
		return
	}
	
	set config($fileName) [list format $format rewrite $rewrite]
	
    set fileName [measure::datafile::parseFileName $fileName]
    validateDir $fileName  

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
    }
    puts $f ""
    
    close $f
}

# Записывает строку данных в результирующий файл
# Аргументы
#   fileName - имя файла данных
#   format - формат файла (TXT или CSV)
#   data - список значений
proc measure::datafile::write { fileName format data } {
    global measure::datafile::textFormat measure::datafile::csvFormat

	if { [string trim $fileName] == "" } {
		return
	}

    set fileName [measure::datafile::parseFileName $fileName]
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
        
        if { $v == "TIMESTAMP" } {
            set v [makeDateTime]
        }
        
        puts -nonewline $f $v
    }
    puts $f ""
    close $f
}

proc measure::datafile::parseFileName { fn } {
    set sep [file separator]
    set autoDate [clock format [clock seconds] -format "%Y${sep}%m${sep}%d"]
    return [string map -nocase [list {%autodate%} $autoDate] $fn] 
}

#############################################################################
# Private
#############################################################################

proc measure::datafile::makeDateTime {} {
    return [clock format [clock seconds] -format %Y-%m-%dT%H:%M:%S]
}

proc measure::datafile::validateDir { fn } {
    set dir [file dirname $fn]
    file mkdir $dir
}
 