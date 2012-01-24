package ifneeded measure::logger 0.1.0 [list source [file join $dir logger.tcl]]
package ifneeded measure::parallel 0.1.0 [list source [file join $dir parallel.tcl]]
package ifneeded measure::widget 0.1.0 [list source [file join $dir widget/widget.tcl]]
package ifneeded measure::config 0.1.0 [list source [file join $dir config.tcl]]
package ifneeded measure::visa 0.1.0 [list source [file join $dir visa.tcl]]
package ifneeded measure::com 0.1.0 [list source [file join $dir com.tcl]]
package ifneeded measure::datafile 0.1.0 [list source [file join $dir datafile.tcl]]
package ifneeded measure::interop 0.1.0 [list source [file join $dir interop.tcl]]
package ifneeded startfile 0.1.0 [list source [file join $dir startfile.tcl]]
package ifneeded measure::sigma 0.1.0 [list source [file join $dir sigma.tcl]]
package ifneeded measure::chart 0.1.0 [list source [file join $dir chart.tcl]]
package ifneeded measure::bsearch 0.1.0 [list source [file join $dir bsearch.tcl]]
package ifneeded measure::thermocouple 0.1.0 [list source [file join $dir thermocouple.tcl]]

set maindir $dir
set dir [file join $maindir widget]; source [file join $dir pkgIndex.tcl]
unset maindir

