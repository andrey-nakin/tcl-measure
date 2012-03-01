# tmap.tcl --
#
#   Working with temperature maps
#
#   Copyright (c) 2011, 2012 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::tmap 0.1.0

package require measure::datafile

namespace eval measure::tmap {
  namespace export 
}

set measure::tmap::EXT ".tsc"

# Возвращает список температурных схем, обнаруженных в указанной директории
# Аргументы
#   dir - путь к директории
# Возврашаемое значение
#   Список с именами файлов-схем (без пути и расширения) 
proc measure::tmap::names { { dir . } } {
    variable EXT
	set files [glob -nocomplain "$dir/*$EXT"]
	set result [list]
	foreach f $files {
		set f [file tail $f]
		lappend result [string range $f 0 end-[string length $EXT]]
	}
	return $result
}

# Создаёт пустой файл температурной схемы
# Аргументы
#   name - название схемы
#   dir - путь к директории
# Возврашаемое значение
#   Путь и имя файлы-схемы 
proc measure::tmap::create { name { dir . } } {
    variable EXT
    set fileName "${dir}/${name}${EXT}"
    measure::datafile::create $fileName TXT 1 [list "I (mA)" "T (K)" "dT (K)"]
    return $fileName
}

# Дописывает данные в конец температурной схемы
# Аргументы
#   fileName - полный путь и имя файла схемы
#   c - ток питания
#   t - температура 
#   tErr - абс. погрешность измерения температуры 
proc measure::tmap::append { fileName c t { tErr 0.0 }} {
	# Выводим результаты в результирующий файл
	measure::datafile::write $fileName TXT [list $c $t $tErr]
}
