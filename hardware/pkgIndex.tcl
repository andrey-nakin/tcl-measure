# All packages need Tcl 8.4 (use [namespace])
if {![package vsatisfies [package provide Tcl] 8.4]} {return}

# Extend the auto_path to make tcllib packages available
if {[lsearch -exact $::auto_path $dir] == -1} {
    lappend ::auto_path $dir
}

package ifneeded scpi 0.1.0 [list source [file join $dir scpi.tcl]]
package ifneeded scpimm 0.1.0 [list source [file join $dir scpi-mm.tcl]]

set maindir $dir
set dir [file join $maindir owen] ;	 source [file join $dir pkgIndex.tcl]
set dir [file join $maindir agilent] ;	 source [file join $dir pkgIndex.tcl]
set dir [file join $maindir skbis] ;	 source [file join $dir pkgIndex.tcl]
unset maindir

