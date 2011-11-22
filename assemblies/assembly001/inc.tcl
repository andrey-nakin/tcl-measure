thread::send $measureThread "measure config measure"

# Открываем менеджер ресурсов VISA
set rm [visa::open-default-rm]

set powerSupplyAddr $POWER_SUPPLY_DEF_ADDR

# Подключаемся к ИП
set powerSupply [visa::open $rm $powerSupplyAddr]

# Инициализируем ИП
fconfigure $powerSupply -buffering line
#visa::clear $powerSupply
puts $powerSupply "*IDN?"
puts "Power supply: [read $powerSupply]"

puts $powerSupply "*CLS"
puts $powerSupply "*RST"
puts $powerSupply "CURRENT 0.001"
puts $powerSupply "OUTPUT ON"
after 500

set mmAddr $MM_DEF_ADDR

# Подключаемся к ММ
set mm [visa::open $rm $mmAddr]

# Инициализируем ММ
fconfigure $mm -buffering line
puts $mm "*IDN?"
puts "Multimeter: [read $mm]"
puts $mm "*CLS"
puts $mm "*RST"

puts $mm "SENSE:VOLTAGE:DC:NPLC 10.0"

for { set v 0.5 } { $v < 2.51 } { set v [expr $v + 0.1] } {
  puts $powerSupply "VOLTAGE $v"
  after 500
  puts $powerSupply "MEASURE:CURRENT?"
  scan [read $powerSupply] "%f" curr 
  puts "$v\t$curr"
  after 500
}
