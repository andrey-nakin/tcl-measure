package require hardware::skbis::lir916
package require hardware::owen::trm201

set trm [::hardware::owen::trm201::init COM3 20]

while {1 } {
  set v [::hardware::skbis::lir916::readAngle COM3 2]

#	::modbus::configure -mode "RTU" -com COM3 -settings "19200,n,8,1"
#	set v [::modbus::cmd 0x03 20 0x1009 2]
#  set s [binary format SS [lindex $v 0] [lindex $v 1] ]
#  binary scan [string reverse $s] f v

#	::modbus::configure -mode "RTU" -com COM3 -settings "19200,n,8,1"
#	set v [::modbus::cmd 0x03 20 0x0200 1]
  
  #set v [::hardware::owen::trm201::readTemperature $trm] 
  puts $v
  after 1000
}