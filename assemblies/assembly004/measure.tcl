package require measure::interop

set i 0
while { ![measure::interop::isTerminated] } {
	measure::interop::setVar runtime(current) $i

	set r [expr rand() + 1.0]
	if { [info exists mainThreadId_] } {
		if { [catch { thread::send -async $mainThreadId_ "addValueToChart $r" } rc] } {
			${log}::error "setVar $varName $value"
		}
	}

	incr i
	after 500
}

