package require measure::interop

set i 0
while { ![measure::interop::isTerminated] } {
	measure::interop::setVar runtime(current) $i
	incr i
	after 500
}

