#!/usr/bin/tclsh
set fileName [lindex $argv 0]
set f [open $fileName r]
fconfigure $f -encoding utf-8
set content [read $f]
close $f

set len [string length $content]
set f [open $fileName w]
for { set i 0 } { $i < $len } { incr i } {
    set c [string index $content $i]
    switch -exact -- $c {
        А { set c "\\u0410" }
        Б { set c "\\u0411" }
        В { set c "\\u0412" }
        Г { set c "\\u0413" }
        Д { set c "\\u0414" }
        Е { set c "\\u0415" }
        Ё { set c "\\u0401" }
        Ж { set c "\\u0416" }
        З { set c "\\u0417" }
        И { set c "\\u0418" }
        Й { set c "\\u0419" }
        К { set c "\\u041A" }
        Л { set c "\\u041B" }
        М { set c "\\u041C" }
        Н { set c "\\u041D" }
        О { set c "\\u041E" }
        П { set c "\\u041F" }
        Р { set c "\\u0420" }
        С { set c "\\u0421" }
        Т { set c "\\u0422" }
        У { set c "\\u0423" }
        Ф { set c "\\u0424" }
        Х { set c "\\u0425" }
        Ц { set c "\\u0426" }
        Ч { set c "\\u0427" }
        Ш { set c "\\u0428" }
        Щ { set c "\\u0429" }
        Ъ { set c "\\u042A" }
        Ы { set c "\\u042B" }
        Ь { set c "\\u042C" }
        Э { set c "\\u042D" }
        Ю { set c "\\u042E" }
        Я { set c "\\u042F" }
        а { set c "\\u0430" }
        б { set c "\\u0431" }
        в { set c "\\u0432" }
        г { set c "\\u0433" }
        д { set c "\\u0434" }
        е { set c "\\u0435" }
        ё { set c "\\u0451" }
        ж { set c "\\u0436" }
        з { set c "\\u0437" }
        и { set c "\\u0438" }
        й { set c "\\u0439" }
        к { set c "\\u043A" }
        л { set c "\\u043B" }
        м { set c "\\u043C" }
        н { set c "\\u043D" }
        о { set c "\\u043E" }
        п { set c "\\u043F" }
        р { set c "\\u0440" }
        с { set c "\\u0441" }
        т { set c "\\u0442" }
        у { set c "\\u0443" }
        ф { set c "\\u0444" }
        х { set c "\\u0445" }
        ц { set c "\\u0446" }
        ч { set c "\\u0447" }
        ш { set c "\\u0448" }
        щ { set c "\\u0449" }
        ъ { set c "\\u044A" }
        ы { set c "\\u044B" }
        ь { set c "\\u044C" }
        э { set c "\\u044D" }
        ю { set c "\\u044E" }
        я { set c "\\u044F" }
    }
    puts -nonewline $f $c 
}
close $f
