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
        А { set c "\0u410" }
        Б { set c "\0u411" }
        В { set c "\0u412" }
        Г { set c "\0u413" }
        Д { set c "\0u414" }
        Е { set c "\0u415" }
        Ё { set c "\0u401" }
        Ж { set c "\0u416" }
        З { set c "\0u417" }
        И { set c "\0u418" }
        Й { set c "\0u419" }
        К { set c "\0u41A" }
        Л { set c "\0u41B" }
        М { set c "\0u41C" }
        Н { set c "\0u41D" }
        О { set c "\0u41E" }
        П { set c "\0u41F" }
        Р { set c "\0u420" }
        С { set c "\0u421" }
        Т { set c "\0u422" }
        У { set c "\0u423" }
        Ф { set c "\0u424" }
        Х { set c "\0u425" }
        Ц { set c "\0u426" }
        Ч { set c "\0u427" }
        Ш { set c "\0u428" }
        Щ { set c "\0u429" }
        Ъ { set c "\0u42A" }
        Ы { set c "\0u42B" }
        Ь { set c "\0u42C" }
        Э { set c "\0u42D" }
        Ю { set c "\0u42E" }
        Я { set c "\0u42F" }
        а { set c "\0u430" }
        б { set c "\0u431" }
        в { set c "\0u432" }
        г { set c "\0u433" }
        д { set c "\0u434" }
        е { set c "\0u435" }
        ё { set c "\0u451" }
        ж { set c "\0u436" }
        з { set c "\0u437" }
        и { set c "\0u438" }
        й { set c "\0u439" }
        к { set c "\0u43A" }
        л { set c "\0u43B" }
        м { set c "\0u43C" }
        н { set c "\0u43D" }
        о { set c "\0u43E" }
        п { set c "\0u43F" }
        р { set c "\0u440" }
        с { set c "\0u441" }
        т { set c "\0u442" }
        у { set c "\0u443" }
        ф { set c "\0u444" }
        х { set c "\0u445" }
        ц { set c "\0u446" }
        ч { set c "\0u447" }
        ш { set c "\0u448" }
        щ { set c "\0u449" }
        ъ { set c "\0u44A" }
        ы { set c "\0u44B" }
        ь { set c "\0u44C" }
        э { set c "\0u44D" }
        ю { set c "\0u44E" }
        я { set c "\0u44F" }
    }
    puts -nonewline $f $c 
}
close $f
