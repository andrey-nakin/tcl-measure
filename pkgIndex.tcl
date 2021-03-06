# Tcl package index file, version 1.1

# All packages need Tcl 8.4 (use [namespace])
if {![package vsatisfies [package provide Tcl] 8.4]} {return}

# Extend the auto_path to make tcllib packages available
if {[lsearch -exact $::auto_path $dir] == -1} {
    lappend ::auto_path $dir
}

# For Tcl 8.3.1 and later, that's all we need
if {[package vsatisfies [package provide Tcl] 8.4]} {return}
if {(0 == [catch {
    package vcompare [info patchlevel] [info patchlevel]
}]) && (
    [package vcompare [info patchlevel] 8.3.1] >= 0
)} {return}

set maindir $dir
set dir [file join $maindir measure] ;	 source [file join $dir pkgIndex.tcl]
set dir [file join $maindir thirdparty] ;	 source [file join $dir pkgIndex.tcl]
set dir [file join $maindir hardware] ;	 source [file join $dir pkgIndex.tcl]
unset maindir

