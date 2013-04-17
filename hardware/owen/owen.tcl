#!/bin/sh
#\
exec tclsh "$0" ${1+"$@"}

##############################################################################
# owen.tcl --
#
# This file is part of owen Tcl library.
#
# Copyright (c) 2011 Andrey V. Nakin <andrey.nakin@gmail.com>
# All rights reserved.
#
# See the file "COPYING" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##############################################################################

package provide owen 1.0

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
    
    set ADDR_TYPE_8BIT 0
    set ADDR_TYPE_11BIT 1
    
	variable Config
	array set Config [list \
		-port "/dev/ttyUSB0" \
		-settings "9600,n,8,1" \
		-timeout 500 \
		-numOfAttempts 3  \
		-addr 16   \
		-addrType $ADDR_TYPE_8BIT 
	]
	
	variable Status
	array set Status [list lastError 0 lastStatus $STATUS_OK ]
	
	variable ErrorHash
}

# Creates a device descriptor to be used in subsequent calls
# Arguments:
#   args - <name value> pairs with device options. See Config variable definition above to know all possible options
# Returns:
#   Device descriptor
proc ::owen::configure {args} {
	variable Config
	set names [lsort [array names Config -*]]
	
	array set desc [array get Config]
	foreach {opt val} $args {
		if {[lsearch $names $opt] < 0} {
			puts "bad option \"$opt\": must be $names"
			exit
		}
		set desc($opt) $val
	}
	
	return [array get desc]
}

# Returns code or description of error of last operation
proc ::owen::lastError {} {
    variable Status
    return $Status(lastError)
}

# Returns status code of last operation
proc ::owen::lastStatus {} {
    variable Status
    return $Status(lastStatus)
}

# Sends a command to OWEN device
# Arguments:
#   desc - device descriptor returned by ::owen::configure
#   cmd - command to send   
proc ::owen::sendCommand { desc cmd } {
    array set Desc $desc
    
    port_open Desc
    if { [info exists Desc(fd)] } {
        port_send Desc [bin2ascii [pack_frame Desc $cmd 0]]
        port_close Desc
    }
}

# Reads a string parameter
# Arguments:
#   desc - device descriptor returned by ::owen::configure
#   parameter - parameter to read   
# Returns:
#   Parameter value or empty string if error occurs
proc ::owen::readString { desc parameter } {
    array set Desc $desc
    
    set result ""

    port_open Desc
    if { [info exists Desc(fd)] } {
        set res [send_frame Desc [pack_frame Desc $parameter]]
        set result [encoding convertfrom cp1251 [string reverse $res]]
        
        port_close Desc
    }
    
    return $result    
}

# Reads an integer parameter
# Arguments:
#   desc - device descriptor returned by ::owen::configure
#   parameter - parameter to read
#   index - parameter index (if any)   
# Returns:
#   Parameter value or empty string if error occurs
proc ::owen::readInt { desc parameter { index -1 } } {
    array set Desc $desc
    set data ""
    if { $index >= 0 } {
        set data [binary format S $index] 
    }
    return [readIntPriv Desc $parameter $index 1 $data]
}

# Writes a 8-bit integer parameter
# Arguments:
#   desc - device descriptor returned by ::owen::configure
#   parameter - parameter to read
#   index - parameter index or -1 if parameter has no index
#   value - value to set   
# Returns:
#   New parameter value or empty string if error occurs
proc ::owen::writeInt8 { desc parameter index value } {
    array set Desc $desc
    set data [binary format c $value]
    if { $index >= 0 } {
        append data [binary format S $index] 
    }
    return [readIntPriv Desc $parameter $index 0 $data]
}

# Writes a 16-bit integer parameter
# Arguments:
#   desc - device descriptor returned by ::owen::configure
#   parameter - parameter to read
#   index - parameter index or -1 if parameter has no index
#   value - value to set   
# Returns:
#   New parameter value or empty string if error occurs
proc ::owen::writeInt16 { desc parameter index value } {
    array set Desc $desc
    set data [binary format S $value]
    if { $index >= 0 } {
        append data [binary format S $index] 
    }
    return [readIntPriv Desc $parameter $index 0 $data]
}

# Reads a 24-bit float parameter
# Arguments:
#   desc - device descriptor returned by ::owen::configure
#   parameter - parameter to read
#   index - parameter index (if any)   
# Returns:
#   Parameter value or empty string if error occurs
proc ::owen::readFloat24 { desc parameter { index -1 } } {
    array set Desc $desc
    set data ""
    if { $index >= 0 } {
        set data [binary format S $index] 
    }
    return [readFloat24Priv Desc $parameter 1 $data]
}

# Writes a 24-bit float parameter
# Arguments:
#   desc - device descriptor returned by ::owen::configure
#   parameter - parameter to read
#   index - parameter index or -1 if parameter has no index
#   value - value to set   
# Returns:
#   New parameter value or empty string if error occurs
proc ::owen::writeFloat24 { desc parameter index value } {
    array set Desc $desc
    set data [string reverse [string range [binary format f $value] 1 3]]
    if { $index >= 0 } {
        append data [binary format S $index] 
    }
    return [readFloat24Priv Desc $parameter 0 $data]
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

proc ::owen::readIntPriv { desc parameter index request data } {
    upvar $desc Desc
    variable Status

    if { "" == [port_open Desc] } {
        return ""
    }
    
    set result ""
    set data [send_frame Desc [pack_frame Desc $parameter $request $data]]
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
    
    port_close Desc
    
    return $result    
}

proc ::owen::readFloat24Priv { desc parameter request data } {
    global ::owen::STATUS_EXCEPTION 
    upvar $desc Desc
    variable Status
    
    if { "" == [port_open Desc] } {
        return ""
    }

    set result ""
    set data [send_frame Desc [pack_frame Desc $parameter $request $data]]
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
    
    port_close Desc
    
    return $result    
}

proc ::owen::send_frame { desc data } {
    global ::owen::ERROR_BAD_DATA ::owen::STATUS_NETWORK_ERROR ::owen::STATUS_OK ::owen::ERROR_TIMEOUT
	variable Status
	upvar $desc Desc

    set data [bin2ascii $data]	
    for { set i $Desc(-numOfAttempts) } { $i > 0 } { incr i -1 } {
        set Status(lastError) 0
        set Status(lastStatus) $STATUS_OK
        
        set res [port_send Desc $data]
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

proc ::owen::pack_frame { desc parameter { request 1 } { data "" } } {
    global ::owen::ADDR_TYPE_8BIT
    upvar $desc Desc
    
    set res ""
    
    if { $request } {
        set r 0x10
    } else {
        set r 0
    }
    
    set len [expr [string length $data] & 0xf]
    if { $Desc(-addrType) == $ADDR_TYPE_8BIT } {
        # 8-bit address
        append res [binary format cc [expr $Desc(-addr) & 0xff] [expr $r | $len]]
    } else {
        # 11-bit address
        append res [binary format cc [expr ($Desc(-addr) & 0xff) >> 3] [expr (($Desc(-addr) & 0x07) << 5) | $r | $len]]
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

proc ::owen::port_close { desc } {
    upvar $desc Desc
	
	catch {close $Desc(fd)}
	unset Desc(fd)
}

proc ::owen::port_open { desc } {
    global ::owen::STATUS_OK ::owen::STATUS_PORT_ERROR 
	variable Status
    upvar $desc Desc
	
    for { set i $Desc(-numOfAttempts) } { $i > 0 } { incr i -1 } {
        set Status(lastError) 0
        set Status(lastStatus) $STATUS_OK
    	if {[catch {set fd [open $Desc(-port) r+]} err]} {
            set Status(lastError) $err
            set Status(lastStatus) $STATUS_PORT_ERROR
            if { $i > 1 } {
                after $Desc(-timeout)
            }
    	} else {
    	   break
        }
    }
    
    if { [info exists fd] } {
    	if {[catch {fconfigure $fd -blocking 0 -encoding binary -translation binary -mode $Desc(-settings)} err]} {
    	    close $fd
            set Status(lastError) $err
            set Status(lastStatus) $STATUS_PORT_ERROR
    		return ""
    	}
    
    	set Desc(fd) $fd
    
    	return $fd
    }
    
    return ""
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

proc ::owen::port_send { desc data } {
	upvar $desc Desc

	set fd $Desc(fd)
	set timeout $Desc(-timeout)	
	
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
