# httpserver.tcl --
#
#   Embedded HTTP server 
#
#   Copyright (c) 2011, 2012 by Andrey V. Nakin <andrey.nakin@gmail.com>
#

package require Tcl 8.4
package provide measure::http::server 0.1.0

namespace eval measure::http::server {
  namespace export init 
}

namespace eval measure::http::server::get {
}

namespace eval measure::http::server::post {
}

# Creates HTTP server
# Arguments:
#   port - port number
proc measure::http::server::init { port } {
    socket -server measure::http::server::accept $port
}

proc measure::http::server::desiredContentType { paramList headerList supported { paramName {} } } {
    set result [lindex $supported 0]

    array set params $paramList
    array set headers $headerList
    
    if { [info exists headers(accept)] } {
        foreach ct [regexp -inline -all -- {[^,;]+} $headers(accept)] {
            if { [lsearch $supported $ct] >= 0 } {
                set result $ct
                break
            } 
        }        
    }

    if { [string length $paramName] > 0 &&  [info exists params($paramName)] && [lsearch $supported $params($paramName)] >= 0 } {
        set result $params($paramName)
    }

    return $result           
}

###############################################################################
# Private
###############################################################################

proc measure::http::server::cleanup { sock } {
    global log
    catch { close $sock }
    ${log}::debug "measure::http::server::cleanup: Socket $sock closed"
}

# Процедура вызывается при подключении клиента
proc measure::http::server::accept {sock clientaddr clientport} {
    global log
    ${log}::debug "Connection from $sock $clientaddr $clientport"
    
    #fconfigure $sock -blocking 0 
    fconfigure $sock -translation crlf 
    fconfigure $sock -buffering line 
    fileevent $sock readable [list measure::http::server::httpStart $sock]
}

proc measure::http::server::httpStart { sock } {
    global log

    if { [eof $sock] } {         
        measure::http::server::cleanup $sock
        return
    }
        
    if { [catch {set len [gets $sock s]} rc] } {
        ${log}::error "Error reading socker: $rc"
        measure::http::server::cleanup $sock
        return
    }
    
    lassign [split $s] method url protocol
    array set parts [uri::split $url http]
    
    # read HTTP headers
    set headers [list]
    while { [gets $sock s] > 0 } {
        set i [string first : $s]
        set name [string trim [string range $s 0 $i-1]] 
        set value [string trim [string range $s $i+1 end]] 
        lappend headers [string tolower $name]; lappend headers $value
    }
    
    # Parse query
    set qparams [list]
    foreach nv [regexp -inline -all -- {[^&]+} $parts(query)] {
        set i [string first = $nv]
        if { $i > 0 } {
            lappend qparams [string range $nv 0 $i-1]
            lappend qparams [string range $nv $i+1 end]
        }
    }
            
    if { [string compare -nocase $method "get"] == 0 } {
        httpGet $sock $parts(path) $qparams $headers
    } elseif {[string compare -nocase $method "post"] == 0 } {
        httpPost $sock $parts(path) $qparams $headers
    } else {
        puts $sock "HTTP/1.0 501 Unimplemented Method"
    }
    
    measure::http::server::cleanup $sock
}

proc measure::http::server::httpGet { sock path qparams headers } {
    global log

    measure::http::server::callHandler $sock "::measure::http::server::get::$path" $qparams $headers 
}

proc measure::http::server::httpPost { sock path qparams headers } {
    global log

    array set hdr $headers
    
    # Read input data
    set data [read $sock $hdr(content-length)]
    foreach s [split $data "\n"] {    
        set i [string first = $s]
        set name [string trim [string range $s 0 $i-1]] 
        set value [string trim [string range $s $i+1 end]] 
        lappend qparams [string tolower $name]; lappend qparams $value
    }
    
    measure::http::server::callHandler $sock "::measure::http::server::post::$path" $qparams $headers 
}

proc measure::http::server::callHandler { sock handlerName qparams headers } {
    global log
    
    if { [info procs $handlerName] eq "" } {
        ${log}::error "callHandler bad handler $handlerName"
        puts $sock "HTTP/1.0 404 Bad path"
        return
    }
    
    if { [catch { lassign [$handlerName $qparams $headers] ct body } rc] } {
        puts $sock "HTTP/1.0 500 Internal Server Error"
        puts $sock "Content-Type: text/plain"
        puts $sock ""
        puts $sock $rc
    } else {
        puts $sock "HTTP/1.0 200 OK"
        puts $sock "Content-Type: $ct"
        puts $sock "Content-Length: [string length $body]"
        puts $sock ""
        puts $sock $body
    }
}
