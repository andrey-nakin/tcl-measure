#!/bin/sh
#\
exec tclsh "$0" ${1+"$@"}

package provide owen 1.0

package require crc16

namespace eval ::owen {
	variable Priv
	array set  Priv [list \
		-com "/dev/ttyUSB0" \
		-settings "9600,n,8,1" \
		-timeout 500 \
	]
}

proc ::owen::configure {args} {
	variable Priv
	set names [lsort [array names Priv -*]]
	
	foreach {opt val} $args {
		if {[lsearch $names $opt] < 0} {
			puts "bad option \"$opt\": must be $names"
			exit
		}
		set Priv($opt) $val
	}
}

proc ::owen::readIEEE32 { addr addrType parameter } {
    port_open

    set res [port_send [pack_frame $addr $addrType $parameter]]
    if { [string length $res] == 9 || [string length $res] == 10 } {
        puts "RESULT LENGTH=[string length $res]"
        set data [unpack_frame $res]
    }
    
    port_close    
}

###############################################################################
# Private
###############################################################################

proc ::owen::pack_frame { addr addrType parameter { request 1 } { data "" } } {
    set res ""
    
    if { $request } {
        set r 0x10
    } else {
        set r 0
    }
    
    set len [expr [string length $data] & 0xf]
    if { $addrType == 0 } {
        # 8-bit address
        append res [binary format cc [expr $addr & 0xff] [expr $r | $len]]
    } else {
        # 11-bit address
        append res [binary format cc [expr ($addr & 0xff) >> 3] [expr (($addr & 0x07) << 5) | $r | $len]]
    }
    
    set hash [str2hash $parameter]
    append res [binary format cc [expr ($hash >> 8) & 0xff] [expr $hash & 0xff]]
    
    if { $data != "" } {
        append res $data
    }

    set crc [calc_crc_str $res]
    append res [binary format cc [expr ($crc >> 8) & 0xff] [expr $crc & 0xff]]
    
    return $res
}

proc ::owen::unpack_frame { data } {
    set len [string length $data]  
    if { $len < 6 } {
        return ""
    }
    
    set crcStr [string range $data $len-3 end]
    binary scan $crcStr cc crcHi crcLo
    set crc [calc_crc_str [expr $len-2]]
    if { $crc != $crcHi * 256 + $crcLo } {
        puts "crc = $crc, crcHi=$crcHi, $crcLo=$crcLo"
        return ""
    }
         
    binary scan $data cccc addr8 len hashHi hashLo
    set plen [expr $len & 0xf]
    puts "$addr8 $len $plen $hashHi $hashLo" 
}

proc ::owen::calc_crc_str { s { l -1} } {
    set crc 0
    if { $l < 0 } {
        set l [string length $s] 
    } 
    for { set i 0 } { $i < $l } { incr i } {
        set c [string index $s $i]
        scan $c %c ascii
        set crc [calc_crc $ascii 8 $crc]
    }
    return $crc
}

proc ::owen::calc_crc { b n crc } {
    for { set j 0 } { $j < $n } { incr j } {
        if { (($b ^ ($crc >> 8)) & 0x80) != 0 } {
            set crc [expr ($crc << 1) ^ 0x8f57]
        } else {
            set crc [expr $crc << 1]
        }

        set b [expr $b << 1]
    }        
    return [expr $crc & 0xffff]
}

proc ::owen::str2hash { s } {
    set hash 0
    set nchars 0
    
    for { set i 0; set l [string length $s] } { $i < $l } { incr i; incr nchars } {
        set c [string index $s $i]
        scan $c %c ascii
        if { $ascii >= 0x30 && $ascii <= 0x39 } {
            set code [expr $ascii - 0x30]
        } elseif { $ascii >= 0x41 && $ascii <= 0x5a } {
            set code [expr $ascii - 0x41 + 10]
        } elseif { $ascii >= 0x61 && $ascii <= 0x7a } {
            set code [expr $ascii - 0x61 + 10]
        } elseif { $ascii == 0x2d } {
            set code 36
        } elseif { $ascii == 0x5f } {
            set code 37
        } elseif { $ascii == 0x2f } {
            set code 38
        } elseif { $ascii == 0x20 } {
            set code 39
        } else {
            error "Invalid character $c in the name of parameter $s"
        }
        set code [expr $code * 2]
        if { $i < $l-1 && [string index $s $i+1] == "." } {
            incr code
            incr i
        }
        
        set hash [calc_crc [expr $code << 1] 7 $hash]
    }
    
    while { $nchars < 4 } {
        set hash [calc_crc [expr (39 * 2) << 1] 7 $hash]
        incr nchars
    }
    
    return [expr $hash & 0xffff]
}

proc ::owen::port_close {} {
	variable Priv
	
	catch {close $Priv(fd)}
	set Priv(fd) ""
}

proc ::owen::port_open {} {
	variable Priv
	
	if {[catch {set fd [open $Priv(-com) r+]} err]} {
		puts $err
		return ""
	}
	if {[catch {fconfigure $fd -blocking 0 -encoding binary -translation binary -mode $Priv(-settings)} err]} {
		puts $err
		return ""
	}

	set Priv(fd) $fd

	return $fd
}

proc ::owen::port_send { data } {
	variable Priv

	set fd $Priv(fd)
	set timeout $Priv(-timeout)	
	
	set buf [read $fd]

    set dts "#"
    for { set i 0; set l [string length $data] } { $i < $l } { incr i } {
        set c [string index $data $i]
        scan $c %c ascii
        append dts [binary format cc [expr ($ascii >> 4) + 0x47] [expr ($ascii & 0xf) + 0x47]]
    }
    append dts "\x0d"

	puts -nonewline $fd $dts
	flush $fd
	
	set t1 [clock milliseconds]
	set t2 $t1
	set ret ""
	while {($t2-$t1) < $timeout} {
		set buf [read $fd]
		if {$buf != ""} {
			append ret $buf
			set t1 [clock milliseconds]
		}
		if {[string first "\x0d" $ret] > 0} {break}
		set t2 [clock milliseconds]
	}

    if { [string index $ret 0] != "#" } {
        return "";  # invalid packet
    }
    
    set result ""
    puts "ret=$ret"
    for { set i 1; set l [string length $ret] } { $i < $l } { incr i } {
        set c [string index $ret $i]
        scan $c %c ascii
        if { $ascii == 0x0d } {
            break
        }
        
        if { $ascii < 0x47 || $ascii > 0x56 } {
            return "";  # invalid packet
        }
        
        if { $i >= $l-1 } {
            return "";  # invalid packet
        }
        
        incr i
        set c [string index $ret $i]
        scan $c %c ascii2
        if { $ascii2 < 0x47 || $ascii2 > 0x56 } {
            return "";  # invalid packet
        }
        
        append result [binary format c [expr ($ascii - 0x47) * 16 + $ascii2 - 0x47]]
    }
	
	return $result
}
