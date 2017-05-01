#!/bin/sh
#\
exec tclsh "$0" ${1+"$@"}

package provide modbus 1.0

package require crc16

namespace eval ::modbus {
	variable Priv
	array set  Priv [list \
		sn 0x1234 \
		-mode "RTU" \
		-ip "127.0.0.1" \
		-port "502" \
		-com "/dev/ttyUSB0" \
		-settings "9600,n,8,1" \
		-timeout 500 \
	]
}

proc ::modbus::configure {args} {
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

proc ::modbus::asc2bin {args} {
	# ex.   asc2bin 0x02 0x01 0x00 0x00 0x01 0x01 0x03
	
	set ret ""
	foreach c $args {
		append ret [binary format c $c]
	}
	return $ret
}

proc ::modbus::bin2asc {data} {
	
	set len [string length $data]
	set str ""
	for {set i 0} {$i<$len} {incr i} {
		 binary scan [string index $data $i] c ch
		 if {$ch < 0} {incr ch 256}
		 lappend str [format %02X $ch]
	}
	return $str
}

proc ::modbus::debug {data} {
	puts [::modbus::bin2asc $data]
}

set ::modbus::LAST_RESPONSE ""

proc ::modbus::cmd {fun args} {
	global ::modbus::LAST_RESPONSE

	variable Priv
	
	set fun [string range 00[expr $fun] end-1 end]
	
	lassign [::modbus::cmd${fun}_pack {*}$args] reqCmd rspLen
	
	set mode [string tolower $Priv(-mode)]
	
	lassign [::modbus::pack_$mode $reqCmd $rspLen ] reqCmd rspLen

	::modbus::port_open
	set rspCmd [::modbus::port_send $reqCmd $rspLen]
	::modbus::port_close
	set LAST_RESPONSE $rspCmd
	
	set rspCmd [::modbus::unpack_$mode $reqCmd $rspCmd]
	if {$rspCmd == ""} {return ""}
	
	if {$mode == "tcp"} {set reqCmd [string range $reqCmd 6 end]}
	
	return [::modbus::cmd${fun}_unpack $reqCmd $rspCmd]
}

proc ::modbus::cmd01_pack {sta addr len} {
#function:  read coils
	# station : 1 byte
	# function :  1 byte (always 0x01)
	# addr : 2 bytes
	# read len : 2 bytes ( how much bits)
	
# response :
	#station :1 byte
	#function : 1 byte (always 0x01)
	#byte count : 1 byte
	# data : N byte (low byte ..  high byte)	
	
	set retlen [expr $len/8]
	
	if {($len % 8) != 0} {incr retlen}
	
	#station + function + byte count = 3
	return [list [binary format ccSS $sta 0x01 $addr $len] [incr retlen 3]]
}

proc ::modbus::cmd01_unpack {reqCmd rspCmd} {
# response :
	#station :1 byte
	#function : 1 byte (always 0x01)
	#byte count : 1 byte
	# data : N byte (low byte ..  high byte)	
	
	if {[string range $reqCmd 0 1] != [string range $rspCmd 0 1]} {return [list]}
	if {[binary scan [string range $reqCmd 4 5] S reqBits] == 0} {return [list]}
	set data [string range $rspCmd 3 end]
	set len [string length $data]
	set rspBits 0
	set ret [list]
	
	for {set i 0} {$i < $len} {incr i} {
		binary scan [string index $data $i] c byte
		for {set oft 0} {$oft < 8} {incr oft} {
			set bit 0
			if {($byte & [expr 0x01<<$oft]) != 0} {set bit 1}
			lappend ret $bit
			
			if {[incr rspBits] == $reqBits} {return $ret}
		}
	}
	
	return $ret
}

proc ::modbus::cmd02_pack {sta addr len} {
# function : read discrete inputs
	# station : 1 byte
	# function :  1 byte (always 0x02)
	# addr : 2 bytes
	# read len : 2 bytes ( how much bits)
#response
	#station :1 byte
	#function : 1 byte (always 0x02)
	#byte count : 1 byte
	# data : N byte		(low byte ..  high byte)

	set retlen [expr $len/8]
	
	if {($len % 8) != 0} {incr retlen}
	
	# 1+1+1+2*len
	# sta=>1 fun=>1 dlen=>1	
	return [list [binary format ccSS $sta 0x02 $addr $len] [expr 1+1+1+$retlen]]
	

		
}

proc ::modbus::cmd02_unpack {reqCmd rspCmd} {
# response :
	#station :1 byte
	#function : 1 byte (always 0x02)
	#byte count : 1 byte
	# data : N byte		(low byte ..  high byte)
	
	if {[string range $reqCmd 0 1] != [string range $rspCmd 0 1]} {return [list]}
	if {[binary scan [string range $reqCmd 4 5] S reqBits] == 0} {return [list]}
	set data [string range $rspCmd 3 end]
	set len [string length $data]
	set rspBits 0
	set ret [list]
	
	for {set i 0} {$i < $len} {incr i} {
		binary scan [string index $data $i] c byte
		for {set oft 0} {$oft < 8} {incr oft} {
			set bit 0
			if {($byte & [expr 0x01<<$oft]) != 0} {set bit 1}
			lappend ret $bit
			
			if {[incr rspBits] == $reqBits} {return $ret}
		}
	}
	
	return $ret
}

proc ::modbus::cmd03_pack {sta addr len} {
# function : read holding registers
	# station : 1 byte
	# function :  1 byte (always 0x03)
	# addr : 2 bytes
	# read len : 2 bytes (how much registers)

# response
	#station : 1 byte
	#function : 1 byte (always 0x03)
	#byte count : 1 byte
	#data : N*2 bytes (reg1_low...reg1_hi...reg2_low...reg2_hi...)
	
	# 1+1+1+2*len
	# sta=>1 fun=>1 dlen=>1
	return [list [binary format ccSS $sta 0x03 $addr $len] [expr 1+1+1+2*$len]]
}

proc ::modbus::cmd03_unpack {reqCmd rspCmd} {
# response
	#station : 1 byte
	#function : 1 byte (always 0x03)
	#byte count : 1 byte
	#data : N*2 bytes (reg1_low...reg1_hi...reg2_low...reg2_hi...)
	
	if {[string range $reqCmd 0 1] != [string range $rspCmd 0 1]} {return [list]}
	if {[binary scan [string range $reqCmd 4 5] S reqBytes] == 0} {return [list]}
	set data [string range $rspCmd 3 end]
	set len [string length $data]
	set ret [list]
	
	for {set i 0} {$i < $len} {incr i} {
		binary scan [string range $data $i [incr i]] S byte
		lappend ret $byte
	}
	
	return $ret
	
}

proc ::modbus::cmd04_pack {sta addr len} {
	# read input registers
	# station : 1 byte
	# function :  1 byte (always 0x04)
	# addr : 2 bytes
	# read len : 2 bytes (how much registers)
	
	# 1+1+1+2*len
	# sta=>1 fun=>1 dlen=>1
	
	return [list [binary format ccSS $sta 0x04 $addr $len] [expr 1+1+1+2*$len]]
	
	# response
	#station : 1 byte
	#function : 1 byte
	#byte count : 1 byte
	#data : N*2 bytes (reg1_low...reg1_hi...reg2_low...reg2_hi...)	
}

proc ::modbus::cmd04_unpack {reqCmd rspCmd} {
# response
	#station : 1 byte
	#function : 1 byte (always 0x04)
	#byte count : 1 byte
	#data : N*2 bytes (reg1_low...reg1_hi...reg2_low...reg2_hi...)
	
	if {[string range $reqCmd 0 1] != [string range $rspCmd 0 1]} {return [list]}
	if {[binary scan [string range $reqCmd 4 5] S reqBytes] == 0} {return [list]}
	set data [string range $rspCmd 3 end]
	set len [string length $data]
	set ret [list]
	
	for {set i 0} {$i < $len} {incr i} {
		binary scan [string range $data $i [incr i]] S byte
		lappend ret $byte
	}
	
	return $ret
	
}

proc ::modbus::cmd05_pack {sta addr value} {
# function : write single coil
	# station : 1 byte
	# function :  1 byte (always 0x05)
	# addr : 2 bytes
	# value : 2 bytes (ON => 0xff 0x00 , OFF => 0x00 0x00)
	
# response
	#station : 1 byte
	#function : 1 byte (always 0x05)
	#addr : 2 bytes
	#value : 2 bytes (ON => 0xff 0x00 , OFF => 0x00 0x00)	
	
	if {$value != 0} {set value 0xFF}
	
	# 6 =  1+1+2+2
	# sta=>1 fun=>1 addr=>2 val=>2
	return [list [binary format ccScc $sta 0x05 $addr $value 0x00] 6]
}

proc ::modbus::cmd05_unpack {reqCmd rspCmd} {
# response
	#station : 1 byte
	#function : 1 byte
	#addr : 2 bytes
	#value : 2 bytes (ON => 0xff 0x00 , OFF => 0x00 0x00)

	if {[string range $reqCmd 0 3] != [string range $rspCmd 0 3]} {return [list]}
	if {[string length $rspCmd] != 6} {return [list]}

	binary scan [string index $rspCmd end-1] c val
	
	if {$val != 0x00} {return 1}
	
	return $val
}

proc ::modbus::cmd06_pack {sta addr value} {
# function : write single register
	# station : 1 byte
	# function :  1 byte (always 0x06)
	# addr : 2 bytes (addr_hi ... addr_lo)
	# value : 2 bytes (value_hi ... value_lo)
	
# response
	#station : 1 byte
	#function : 1 byte
	#addr : 2 bytes
	#value : 2 bytes (value_hi ... value_lo)
	
	# 6 =  1+1+2+2
	# sta=>1 fun=>1 addr=>2 val=>2
	return [list [binary format ccSS $sta 0x06 $addr $value] 6]
}

proc ::modbus::cmd06_unpack {reqCmd rspCmd} {
# response
	#station : 1 byte
	#function : 1 byte
	#addr : 2 bytes
	#value : 2 bytes (value_hi ... value_lo)

	if {$reqCmd != $rspCmd} {return 0}

	binary scan [string range $rspCmd end-1 end] S val
	
	return $val
}

proc ::modbus::cmd15_pack {sta addr args} {
# function : write multiple coils
	# station : 1 byte
	# function :  1 byte (always 0x0F)
	# addr : 2 bytes (addr_hi ... addr_lo)
	# quantity of outputs : 2 bytes(how much coils)
	# byte count : 2 bytes (how much bytes)

# response
	#station : 1 byte
	#function : 1 byte
	# addr : 2 bytes (addr_hi ... addr_lo)
	# quantity of coils : 2 bytes(how much coils)
	
	set data ""
	set oft 0
	foreach item $args {
		if {$oft == 0} {set val 0}
		set val [expr $val | ($item<<$oft)]
		
		incr oft
		
		if {$oft == 8} {
			append data [binary format c $val]
			set oft 0
		}
	}

	if {$oft != 0} {append data [binary format c $val]}

	set cmd [binary format ccSSc $sta 0x0F $addr [llength $args] [string length $data]]
	
	append cmd $data

	# 6 =  1+1+2+2
	# sta=>1 fun=>1 addr=>2 val=>2
	return [list $cmd 6]

	# ex. wirte 16 bits to station 0x01 , addr 0x00
	# ::modbus::cmd15 0x01 0x00 0x5a 0x5a
}

proc ::modbus::cmd15_unpack {reqCmd rspCmd} {
	if {[string range $reqCmd 0 5] != [string range $rspCmd 0 5]} {return 0}
	return 1
}

proc ::modbus::cmd16_pack {sta addr args} {
# function : write multiple registers
	# station : 1 byte
	# function :  1 byte (always 0x10)
	# addr : 2 bytes (addr_hi ... addr_lo)
	# quantity of registers : 2 bytes(how much registers)
	# byte count : 2 bytes (how much bytes)
	
# response
	#station : 1 byte
	#function : 1 byte
	# addr : 2 bytes (addr_hi ... addr_lo)
	# quantity of registers : 2 bytes(how much registers)	
	
	set data ""
	foreach item $args {
		append data [binary format S $item]
	}

	set len [string length $data]
	set regs [expr $len/2]	
	
	set cmd [binary format ccSSc $sta 0x10 $addr $regs $len]
	
	append cmd $data
	
	# 6 =  1+1+2+2
	# sta=>1 fun=>1 addr=>2 val=>2
	return [list $cmd 6]
	
	# ex. wirte 3 words to station 0x01 , addr 0x00
	# ::modbus::cmd16 0x01 0x00 0x1234 0x5678 0x9812	
}

proc ::modbus::cmd16_unpack {reqCmd rspCmd} {
	if {[string range $reqCmd 0 5] != [string range $rspCmd 0 5]} {return 0}
	return 1
}

proc ::modbus::pack_rtu {data retlen} {
	# 把modbus訊息加上CRC
	
     append data [binary format s [::crc::crc16 -seed 0xFFFF $data]]
     return [list $data [incr retlen 2]]
}

proc ::modbus::pack_tcp {data retlen} {
	#把modbus訊息轉為 modbus tcp的訊息
	variable Priv
	
	# sn : 2 bytes
	# Protocol : 2 bytes (always 0)
	# len : 2 bytes
	# id : 1 bytes
	
	incr Priv(sn)
	append ret [binary format SSS $Priv(sn) 0x00 [string length $data]] $data
	return [list $ret [incr retlen 6] $Priv(sn)]
}

proc ::modbus::port_close {} {
	variable Priv
	
	catch {close $Priv(fd)}
	set Priv(fd) ""
}

proc ::modbus::port_open {} {
	variable Priv
	
	if {$Priv(-mode) == "RTU"} {
		if {[catch {set fd [open $Priv(-com) r+]} err]} {
			puts $err
			return ""
		}
		if {[catch {fconfigure $fd -blocking 0 -encoding binary -translation binary -mode $Priv(-settings)} err]} {
			puts $err
			return ""
		}
	}
	
	if {$Priv(-mode) == "TCP"} {
		if {[catch {set fd [socket $Priv(-ip) $Priv(-port)]} err]} {
			puts $err
			return ""
		}
		if {[catch {fconfigure $fd -encoding binary -translation binary -blocking 0} err]} {
			puts $err
			return ""
		}
		
	}

	set Priv(fd) $fd

	return $fd
}

proc ::modbus::port_send {data retlen} {
	variable Priv

	set fd $Priv(fd)
	set timeout $Priv(-timeout)	
	
	set buf [read $fd]
	
	puts -nonewline $fd $data
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
		if {[string length $ret] >= $retlen} {break}
		set t2 [clock milliseconds]
	}
	
	return $ret
}

proc ::modbus::unpack_rtu {reqCmd rspCmd} {
	if {[string length $rspCmd] < 4} {return ""} 
	
	set crc [binary format s [::crc::crc16 -seed 0xFFFF [string range $rspCmd 0 end-2]]]	
	if {$crc != [string range $rspCmd end-1 end]} {return ""}
	
	if {[binary scan [string index $rspCmd 1] c fun] == 0} {return ""}
	if {$fun & 0x80} {return ""}
	
	return $rspCmd
}

proc ::modbus::unpack_tcp {reqCmd rspCmd} {
	# transaction identifier : 2 bytes
	# protocol identifier : 2 bytes
	# length : 2 bytes
	# unit identifier : 1 bytes

	if {[string length $rspCmd] < 8} {return ""}

	if {[string range $reqCmd 0 3] != [string range $rspCmd 0 3]} {return ""}

	if {[binary scan [string range $rspCmd 0 1] S	sn] == 0} {return ""}
	if {[binary scan [string range $rspCmd 2 3] S	pocl] == 0} {return ""}
	if {[binary scan [string range $rspCmd 4 5] S	len] == 0} {return ""}

	if {[string length $rspCmd] != 6+$len} {return ""}

	return [string range $rspCmd 6 end]
}

#::modbus::configure -mode "RTU" -com "/dev/ttyUSB0" -settings "9600,n,8,1"
#::modbus::configure -mode "TCP" -ip "192.168.1.104" -port 502
#set aa [list 0 1 0 1 0 1 1 1 0 1 1 0 1 1 1 0 0 0 1 1 1]
#puts [::modbus::cmd 15 0x01 0 {*}$aa]
#set bb [::modbus::cmd 0x01 0x01 0x00 [llength $aa]]
#puts bb=$bb
#if {$aa == $bb} {puts xx}
