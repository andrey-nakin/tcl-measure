# datafile.tcl --
#
#   Write resulting data file
#
#   Copyright (c) 2011 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package require Thread

package provide measure::datafile 0.1.0

package require measure::logger

namespace eval measure::datafile {
  namespace export create write
}

# Пауза перед автоматическим закрытием файла
set measure::datafile::CLOSE_DELAY 10000

# Список поддерживаемых форматов
set measure::datafile::FORMAT_LIST { TXT CSV }

array set measure::datafile::textFormat {separator "\t" comment "# "}
array set measure::datafile::csvFormat {separator "," comment ""}

# Создаёт результирующий файл и записывает строку с заголовком
# Аргументы
#   fileName - имя файла данных
#   format - формат файла (TXT или CSV)
#   rewrite - переписывать или дополнять файл
#   headers - список заголовков столбцов
proc measure::datafile::create { fileName { format TXT } { rewrite 1 } { headers {} } { comment "" } } {
    if { [isStarted] } {
        # запись производится в выделенном потоке
		set tid [tsv::get measure-datafile thread]
		thread::send -async $tid [list ::measure::datafile::createInt $fileName $format $rewrite $headers $comment]
    } else {
        # запись производится немедленно
        createInt $fileName $format $rewrite $headers $comment
    }
}

# Записывает строку данных в результирующий файл
# Аргументы
#   fileName - имя файла данных
#   format - формат файла (TXT или CSV)
#   data - список значений
proc measure::datafile::write { fileName data } {
    if { [isStarted] } {
        # запись производится в выделенном потоке
		set tid [tsv::get measure-datafile thread]
		thread::send -async $tid [list ::measure::datafile::writeBg $fileName $data]
    } else {
        # запись производится немедленно
        writeRec $fileName $data
        closeFile $fileName
    }
}

proc measure::datafile::parseFileName { fn } {
    set sep [file separator]
    set autoDate [clock format [clock seconds] -format "%Y${sep}%m${sep}%d"]
    return [string map -nocase [list {%autodate%} $autoDate] $fn] 
}

# Инициализирует выделенный поток для записи данных
proc ::measure::datafile::startup { } {
	set t [thread::create -joinable {
		#rename source realsource

		proc ::source1 { f } {
			if {[catch {set fh [open $f r]; set b [read $fh]; close $fh} rc]} {
				return -code error -errorinfo $rc -errorcode $::errorCode $rc
			}
			set s [info script]
			info script $f
			if {[catch {uplevel 1 $b} rc]==1} {
				info script $s
				# the line below dumps errors in wish console
				catch {thread::send -async $mainthread [list puts $::errorInfo]}
				return -code error -errorinfo $rc -errorcode $::errorCode $rc
			}
			info script $s
			return $rc
		}

        proc init_df_thread {} {
			global log

		    package require measure::logger
		    package require measure::datafile
		    
		    # Инициализируем протоколирование
		    set log [measure::logger::init measure::datafile]
		    ${log}::setlevel info
		}

		proc stop {} {
		    measure::datafile::closeAll
			thread::exit
		}

		# enter to event loop
		thread::wait
	}]

	if {[info exists starkit::mode] && $starkit::mode ne "unwrapped"} {
        set self $starkit::topdir 
        thread::send $t "vfs::mk4::Mount \"$self\" \"$self\" -readonly" 
    }
    thread::send $t [list set ::auto_path $::auto_path]
	thread::send $t init_df_thread

	tsv::set measure-datafile thread $t
}

# Останавливает поток записи данных
proc ::measure::datafile::shutdown { } {
	if { [tsv::exists measure-datafile thread] } {
		global log

		if { [info exists log] } {
			#${log}::debug "Shutting log server down"
		}

		set tid [tsv::get measure-datafile thread]
		thread::send -async $tid stop
		thread::join $tid
		tsv::unset measure-datafile thread
	}
}

# Возвращает TRUE если выделенный поток записи данных работает
proc ::measure::datafile::isStarted { } {
	if { [tsv::exists measure-datafile thread] } {
	   return 1
	}
	return 0
}

#############################################################################
# Private
#############################################################################

set measure::datafile::DEF_FORMAT [list $measure::datafile::FORMAT_LIST 0] 
array set measure::datafile::config {} 
array set measure::datafile::channels {} 
array set measure::datafile::closeScripts {} 

proc measure::datafile::makeDateTime {} {
    return [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
}

proc measure::datafile::validateDir { fn } {
    set dir [file dirname $fn]
    file mkdir $dir
}

proc measure::datafile::writeRec { fileName data } {
    variable textFormat 
    variable csvFormat
    variable config
    variable channels
    global log

	if { [string trim $fileName] == "" } {
		return
	}

    # read file configuration
    if { [info exists config($fileName)] } {
        array set cfg $config($fileName) 
    } else {
        # no config
        array set cfg {}
    }
    
    # determine file format
    if { ![info exists cfg(format)] } {
        variable DEF_FORMAT
        set cfg(format) $DEF_FORMAT
    }
    
    # parse format
    if { [string equal -nocase $cfg(format) csv] } {
        set fmt csvFormat
    } else {
        set fmt textFormat
    }
    
    # check whether file is already open
    if { ![info exists channels($fileName)] } {
        ${log}::debug "writeRec open $fileName"
        set f [open [measure::datafile::parseFileName $fileName] a]
        set channels($fileName) $f
    } else {
        set f $channels($fileName) 
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
    ${log}::debug "writeRec append $fileName"
}

proc measure::datafile::writeBg { fileName data } {
    variable closeScripts
    variable CLOSE_DELAY
    global log
    
    writeRec $fileName $data
    
    if { [info exists closeScripts($fileName)] } {
        after cancel $closeScripts($fileName) 
    }
    
    set closeScripts($fileName) [after $CLOSE_DELAY [list measure::datafile::closeFile $fileName]]
}
 
proc measure::datafile::closeFile { fileName } {
    variable channels
    variable closeScripts
    global log
     
    if { [info exists channels($fileName)] } {
        ${log}::debug "closeFile $fileName channel $channels($fileName)"
        close $channels($fileName)
        unset channels($fileName)
    }

    unset -nocomplain closeScripts($fileName) 
}

proc measure::datafile::closeAll { } {
    variable channels

    foreach fn [ array names channels ] {
        closeFile $fn
    }
}

proc measure::datafile::createInt { fileName format rewrite headers comment } {
    variable textFormat 
    variable csvFormat
    variable config
    global log

	if { [string trim $fileName] == "" } {
		return
	}
	
	set config($fileName) [list format $format rewrite $rewrite]
	
    set fileName [measure::datafile::parseFileName $fileName]
    validateDir $fileName  

    set writeHeader 0
    if { $rewrite } {
        ${log}::debug "createInt open $fileName"
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
        eval "set commentChar \$${fmt}(comment)"
        eval "set separator \$${fmt}(separator)"
        
        if { $comment != "" } {
            puts $f "$commentChar $comment"
        }
        
        puts -nonewline $f $commentChar
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
