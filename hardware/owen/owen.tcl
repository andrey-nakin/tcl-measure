#!/bin/sh
#\
exec tclsh "$0" ${1+"$@"}

package provide owen 1.0

package require crc16

namespace eval ::owen {
    set STATUS_OK 0
    set STATUS_EXCEPTION -1
    set STATUS_NETWORK_ERROR -2
    set STATUS_PORT_ERROR -3
    
    set ERROR_BAD_DATA -1
    set ERROR_BAD_LENGTH -2 
    set ERROR_TIMEOUT -3 

    set EXCEPTION_INPUT 0xfd
    set EXCEPTION_NO_DAC 0xfe
    set EXCEPTION_BAD_VALUE 0xf0
    
	variable Priv
	array set  Priv [list \
		-com "/dev/ttyUSB0" \
		-settings "9600,n,8,1" \
		-timeout 500 \
		-numOfAttempts 3
	]
	
	variable Status
	array set Status [list lastError 0 lastStatus $STATUS_OK ]
	
	variable ErrorHash
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

proc ::owen::lastError {} {
    variable Status
    return $Status(lastError)
}

proc ::owen::lastStatus {} {
    variable Status
    return $Status(lastStatus)
}

proc ::owen::sendCommand { addr addrType cmd } {
    port_open
    port_send [bin2ascii [pack_frame $addr $addrType $cmd 0]]
    port_close
}

proc ::owen::readString { addr addrType parameter } {
    set result ""

    port_open

    set res [send_frame [pack_frame $addr $addrType $parameter]]
    set result [encoding convertfrom cp1251 [string reverse $res]]
    
    port_close
    
    return $result    
}

proc ::owen::readInt { addr addrType parameter { index -1 } } {
    set data ""
    if { $index >= 0 } {
        set data [binary format S $index] 
    }
    return [readIntPriv $addr $addrType $parameter $index 1 $data]
}

proc ::owen::writeInt8 { addr addrType parameter index value } {
    set data [binary format c $value]
    if { $index >= 0 } {
        append data [binary format S $index] 
    }
    return [readIntPriv $addr $addrType $parameter $index 0 $data]
}

proc ::owen::writeInt16 { addr addrType parameter index value } {
    set data [binary format S $value]
    if { $index >= 0 } {
        append data [binary format S $index] 
    }
    return [readIntPriv $addr $addrType $parameter $index 0 $data]
}

proc ::owen::readFloat24 { addr addrType parameter { index -1 } } {
    set data ""
    if { $index >= 0 } {
        set data [binary format S $index] 
    }
    return [readFloat24Priv $addr $addrType $parameter 1 $data]
}

proc ::owen::writeFloat24 { addr addrType parameter index value } {
    set data [string reverse [string range [binary format f $value] 1 3]]
    if { $index >= 0 } {
        append data [binary format S $index] 
    }
    return [readFloat24Priv $addr $addrType $parameter 0 $data]
}

###############################################################################
# Private
###############################################################################

proc ::owen::dump { s { msg "" } } {
    puts -nonewline $msg
    for { set i 0 } { $i < [string length $s] } { incr i } {
        set c [string index $s $i]
        scan $c %ca ascii
        puts -nonewline [format %0.2x $ascii]  
    }
    puts ""
}

proc ::owen::readIntPriv { addr addrType parameter index request data } {
    variable Status

    if { "" == [port_open] } {
        return ""
    }
    
    set result ""
    set data [send_frame [pack_frame $addr $addrType $parameter $request $data]]
    set len [string length $data]

    if { $index >= 0 && $len >= 2 } {
        set data [string range $data 0 $len-2]
        incr len -2
    }

    switch -exact -- $len {
        1 {
            binary scan $data c result
        }
        2 {
            binary scan $data S result
        }
        4 {
            binary scan $data I result
        }
    }
    
    port_close
    
    return $result    
}

proc ::owen::readFloat24Priv { addr addrType parameter request data } {
    global ::owen::STATUS_EXCEPTION 
    variable Status
    
    if { "" == [port_open] } {
        return ""
    }

    set result ""
    set data [send_frame [pack_frame $addr $addrType $parameter $request $data]]
    set len [string length $data]
    
    if { $len == 1 } {
        # error
        scan [string index $data 0] %c ascii
        set Status(lastError) $ascii
        set Status(lastStatus) $STATUS_EXCEPTION
    }
    
    if { $len >= 3 } {
        # convert to little-endian form
        binary scan [string reverse "[string range $data 0 2]\x00"] f result
    }
    
    port_close
    
    return $result    
}

proc ::owen::send_frame { data } {
    global ::owen::ERROR_BAD_DATA ::owen::STATUS_NETWORK_ERROR ::owen::STATUS_OK ::owen::ERROR_TIMEOUT
	variable Priv
	variable Status

    set data [bin2ascii $data]	
    for { set i $Priv(-numOfAttempts) } { $i > 0 } { incr i -1 } {
        set Status(lastError) 0
        set Status(lastStatus) $STATUS_OK
        
        set res [port_send $data]
        if { $Status(lastStatus) == $STATUS_OK } {
            set res [ascii2bin $res]
        }
        if { $Status(lastStatus) == $STATUS_OK } {
            set res [unpack_frame $res]
        }
        if { $Status(lastStatus) == $STATUS_NETWORK_ERROR && ($Status(lastError) == $ERROR_BAD_DATA || $Status(lastError) == $ERROR_TIMEOUT)} {
            continue
        }
        
        break
    }
    
    return $res
}

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
    global ::owen::STATUS_NETWORK_ERROR ::owen::ERROR_BAD_DATA ::owen::ERROR_BAD_LENGTH 
    variable Status
    variable ErrorHash

    set len [string length $data]  
    if { $len < 6 } {
        set Status(lastError) $ERROR_BAD_LENGTH
        set Status(lastStatus) $STATUS_NETWORK_ERROR
        return ""
    }
    
    binary scan [string range $data $len-2 end] cc crcHi crcLo
    set crc [calc_crc_str $data [expr $len - 2]]
    if { $crc != (($crcHi & 0xff) << 8) + ($crcLo & 0xff) } {
        # bad CRC
        set Status(lastError) $ERROR_BAD_DATA
        set Status(lastStatus) $STATUS_NETWORK_ERROR
        return "" 
    }
         
    binary scan $data ccccc b1 b2 hashHi hashLo err
    set hash [expr (($hashHi & 0xff) << 8) + ($hashLo & 0xff)]
    if { $hash == $ErrorHash } {
        set Status(lastError) $err
        set Status(lastStatus) $STATUS_NETWORK_ERROR
        return ""
    }
    
    set datalen [expr $b2 & 0xf]
    if { $datalen != $len - 6 } {
        # bad data len field
        set Status(lastError) $ERROR_BAD_LENGTH
        set Status(lastStatus) $STATUS_NETWORK_ERROR
        return ""
    }
    
    return [string range $data 4 end-2]
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
    global ::owen::STATUS_OK ::owen::STATUS_PORT_ERROR 
	variable Priv
	variable Status
	
    set Status(lastError) 0
    set Status(lastStatus) $STATUS_OK
    
	if {[catch {set fd [open $Priv(-com) r+]} err]} {
        set Status(lastError) $err
        set Status(lastStatus) $STATUS_PORT_ERROR
		return ""
	}
	if {[catch {fconfigure $fd -blocking 0 -encoding binary -translation binary -mode $Priv(-settings)} err]} {
        set Status(lastError) $err
        set Status(lastStatus) $STATUS_PORT_ERROR
		return ""
	}

	set Priv(fd) $fd

	return $fd
}

proc ::owen::bin2ascii { data } {
    set dts ""
    for { set i 0; set l [string length $data] } { $i < $l } { incr i } {
        set c [string index $data $i]
        scan $c %c ascii
        append dts [binary format cc [expr ($ascii >> 4) + 0x47] [expr ($ascii & 0xf) + 0x47]]
    }
    return $dts
}

proc ::owen::ascii2bin { ret } {
    global ::owen::STATUS_NETWORK_ERROR ::owen::ERROR_TIMEOUT ::owen::ERROR_BAD_DATA
	variable Status
	
    if { $ret == "" } {
        set Status(lastError) $ERROR_TIMEOUT
        set Status(lastStatus) $STATUS_NETWORK_ERROR
        return "";  # invalid packet
    }
    
    set result ""
    for { set i 0; set l [string length $ret]; set l1 [expr $l - 1] } { $i < $l } { incr i } {
        set c [string index $ret $i]
        scan $c %c ascii
        
        #if { $ascii == 0x0d } {
        #    break
        #}
        
        if { $ascii < 0x47 || $ascii > 0x56 } {
            set Status(lastError) $ERROR_BAD_DATA
            set Status(lastStatus) $STATUS_NETWORK_ERROR
            return "";  # invalid packet
        }
        
        if { $i >= $l1 } {
            set Status(lastError) $ERROR_BAD_DATA
            set Status(lastStatus) $STATUS_NETWORK_ERROR
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

proc ::owen::port_send { data } {
	variable Priv

	set fd $Priv(fd)
	set timeout $Priv(-timeout)	
	
    # dirty read	
	read $fd

    set dts "#${data}\x0d"
    #puts stderr "SENT:\t$dts"
	puts -nonewline $fd $dts
	flush $fd
	
	set t1 [clock milliseconds]
	set t2 $t1
	set ret ""
	set tmp ""
	while {($t2-$t1) < $timeout} {
		set buf [read $fd]
		if {$buf != ""} {
			append tmp $buf
			set t1 [clock milliseconds]
		}
		set pos1 [string first "#" $tmp] 
		set pos2 [string first "\x0d" $tmp]
		if {$pos1 >= 0 && $pos2 > $pos1} {
  		    set ret [string range $tmp $pos1+1 $pos2-1]
            break
        }
		set t2 [clock milliseconds]
	}
    #puts stderr "RECV:\t$tmp"

    return $ret
}

set ::owen::ErrorHash [::owen::str2hash n.Err]
