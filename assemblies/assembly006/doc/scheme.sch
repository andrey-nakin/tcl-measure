v 20100214 2
C 40000 40000 0 0 0 title-B.sym
C 53000 49900 1 180 0 current-1.sym
{
T 52400 48900 5 10 0 0 180 0 1
device=CURRENT_SOURCE
T 53000 49900 5 10 1 1 180 0 1
refdes=I2
}
C 43600 44500 1 270 0 resistor-2.sym
{
T 43950 44100 5 10 0 0 270 0 1
device=RESISTOR
T 43800 44000 5 10 1 1 0 0 1
refdes=R1
}
C 53000 49000 1 180 0 resistor-2.sym
{
T 52600 48650 5 10 0 0 180 0 1
device=RESISTOR
T 52700 48800 5 10 1 1 180 0 1
refdes=R3
}
T 54000 40100 9 10 1 0 0 0 1
NAKIN A. V.
T 54000 40400 9 10 1 0 0 0 1
1
T 50000 40100 9 10 1 0 0 0 1
1
T 51500 40100 9 10 1 0 0 0 1
1
T 51500 40900 9 14 1 0 0 0 1
Building #6 Schematic Diagram
C 43200 43000 1 270 0 resistor-1.sym
{
T 43600 42700 5 10 0 0 270 0 1
device=RESISTOR
T 43400 42500 5 10 1 1 0 0 1
refdes=R2
}
C 43600 47000 1 0 0 current-1.sym
{
T 44200 48000 5 10 0 0 0 0 1
device=CURRENT_SOURCE
T 43600 47300 5 10 1 1 0 0 1
refdes=I1
}
C 44500 44800 1 90 0 testpt-1.sym
{
T 44500 45200 5 10 1 1 180 0 1
refdes=TC1
T 43600 45200 5 10 0 0 90 0 1
device=TESTPOINT
T 43800 45200 5 10 0 0 90 0 1
footprint=none
}
C 44500 43200 1 90 0 testpt-1.sym
{
T 44500 43600 5 10 1 1 180 0 1
refdes=TC2
T 43600 43600 5 10 0 0 90 0 1
device=TESTPOINT
T 43800 43600 5 10 0 0 90 0 1
footprint=none
}
C 43600 48500 1 0 0 voltmeter-1.sym
{
T 43700 49350 5 10 0 0 0 0 1
device=VOLTAGE_SOURCE
T 43600 48900 5 10 1 1 0 0 1
refdes=V2
}
C 43600 47700 1 0 0 voltmeter-1.sym
{
T 43700 48550 5 10 0 0 0 0 1
device=VOLTAGE_SOURCE
T 43600 48100 5 10 1 1 0 0 1
refdes=V3
}
C 43600 49300 1 0 0 voltmeter-1.sym
{
T 43700 50150 5 10 0 0 0 0 1
device=VOLTAGE_SOURCE
T 43600 49700 5 10 1 1 0 0 1
refdes=V1
}
T 42250 45750 5 10 0 1 0 0 1
device=HEADER16
T 42200 46200 8 10 0 0 0 0 1
pins=16
T 42200 46000 8 10 0 0 0 0 1
class=IO
T 44150 44950 5 10 0 1 0 0 1
device=HEADER16
T 44100 45400 8 10 0 0 0 0 1
pins=16
T 44100 45200 8 10 0 0 0 0 1
class=IO
C 44700 46700 1 0 0 EMBEDDEDjack1.sym
[
T 44700 45900 8 10 0 0 0 0 1
class=IO
T 44700 46100 8 10 0 0 0 0 1
pins=16
T 45300 50000 8 10 0 1 0 0 1
refdes=J?
T 44750 45650 5 10 0 1 0 0 1
device=HEADER16
L 45400 49900 45400 46700 3 0 0 0 -1 -1
L 45000 47900 45800 47900 3 0 0 0 -1 -1
B 45000 46700 800 3200 3 0 0 0 -1 -1 0 -1 -1 -1 -1 -1
P 44700 47700 45000 47700 1 0 0
{
T 45100 47650 5 8 1 1 0 0 1
pinnumber=6-F
T 44800 47750 5 8 0 0 0 0 1
pinseq=11
T 44800 47750 5 8 0 1 0 0 1
pinlabel=11
T 44800 47750 5 8 0 1 0 0 1
pintype=pas
}
P 45800 47700 46100 47700 1 0 1
{
T 45500 47650 5 8 1 1 0 0 1
pinnumber=6-R
T 45900 47750 5 8 0 0 0 0 1
pinseq=12
T 45900 47750 5 8 0 1 0 0 1
pinlabel=12
T 45900 47750 5 8 0 1 0 0 1
pintype=pas
}
P 44700 47300 45000 47300 1 0 0
{
T 45100 47250 5 8 1 1 0 0 1
pinnumber=7-F
T 44800 47350 5 8 0 0 0 0 1
pinseq=13
T 44800 47350 5 8 0 1 0 0 1
pinlabel=13
T 44800 47350 5 8 0 1 0 0 1
pintype=pas
}
P 45800 47300 46100 47300 1 0 1
{
T 45500 47250 5 8 1 1 0 0 1
pinnumber=7-R
T 45900 47350 5 8 0 0 0 0 1
pinseq=14
T 45900 47350 5 8 0 1 0 0 1
pinlabel=14
T 45900 47350 5 8 0 1 0 0 1
pintype=pas
}
P 44700 46900 45000 46900 1 0 0
{
T 45100 46850 5 8 1 1 0 0 1
pinnumber=8-F
T 44800 46950 5 8 0 0 0 0 1
pinseq=15
T 44800 46950 5 8 0 1 0 0 1
pinlabel=15
T 44800 46950 5 8 0 1 0 0 1
pintype=pas
}
L 45000 47500 45800 47500 3 0 0 0 -1 -1
L 45000 47100 45800 47100 3 0 0 0 -1 -1
P 45800 46900 46100 46900 1 0 1
{
T 45500 46850 5 8 1 1 0 0 1
pinnumber=8-R
T 45900 46950 5 8 0 0 0 0 1
pinseq=16
T 45900 46950 5 8 0 1 0 0 1
pinlabel=16
T 45900 46950 5 8 0 1 0 0 1
pintype=pas
}
P 45800 48900 46100 48900 1 0 1
{
T 45500 48850 5 8 1 1 0 0 1
pinnumber=3-R
T 45900 48950 5 8 0 0 0 0 1
pinseq=6
T 45900 48950 5 8 0 1 0 0 1
pinlabel=6
T 45900 48950 5 8 0 1 0 0 1
pintype=pas
}
P 44700 48500 45000 48500 1 0 0
{
T 45100 48450 5 8 1 1 0 0 1
pinnumber=4-F
T 44800 48550 5 8 0 0 0 0 1
pinseq=7
T 44800 48550 5 8 0 1 0 0 1
pinlabel=7
T 44800 48550 5 8 0 1 0 0 1
pintype=pas
}
P 45800 48500 46100 48500 1 0 1
{
T 45500 48450 5 8 1 1 0 0 1
pinnumber=4-R
T 45900 48550 5 8 0 0 0 0 1
pinseq=8
T 45900 48550 5 8 0 1 0 0 1
pinlabel=8
T 45900 48550 5 8 0 1 0 0 1
pintype=pas
}
P 44700 48100 45000 48100 1 0 0
{
T 45100 48050 5 8 1 1 0 0 1
pinnumber=5-F
T 44800 48150 5 8 0 0 0 0 1
pinseq=9
T 44800 48150 5 8 0 1 0 0 1
pinlabel=9
T 44800 48150 5 8 0 1 0 0 1
pintype=pas
}
P 45800 48100 46100 48100 1 0 1
{
T 45500 48050 5 8 1 1 0 0 1
pinnumber=5-R
T 45900 48150 5 8 0 0 0 0 1
pinseq=10
T 45900 48150 5 8 0 1 0 0 1
pinlabel=10
T 45900 48150 5 8 0 1 0 0 1
pintype=pas
}
L 45000 48300 45800 48300 3 0 0 0 -1 -1
L 45000 49500 45800 49500 3 0 0 0 -1 -1
L 45000 48700 45800 48700 3 0 0 0 -1 -1
L 45000 49100 45800 49100 3 0 0 0 -1 -1
P 44700 48900 45000 48900 1 0 0
{
T 45100 48850 5 8 1 1 0 0 1
pinnumber=3-F
T 44800 48950 5 8 0 0 0 0 1
pinseq=5
T 44800 48950 5 8 0 1 0 0 1
pinlabel=5
T 44800 48950 5 8 0 1 0 0 1
pintype=pas
}
P 44700 49700 45000 49700 1 0 0
{
T 45050 49650 5 8 1 1 0 0 1
pinnumber=1-F
T 44850 49750 5 8 0 0 0 0 1
pinseq=1
T 44850 49750 5 8 0 1 0 0 1
pinlabel=1
T 44850 49750 5 8 0 1 0 0 1
pintype=pas
}
P 45800 49300 46100 49300 1 0 1
{
T 45500 49250 5 8 1 1 0 0 1
pinnumber=2-R
T 45900 49350 5 8 0 0 0 0 1
pinseq=4
T 45900 49350 5 8 0 1 0 0 1
pinlabel=4
T 45900 49350 5 8 0 1 0 0 1
pintype=pas
}
P 44700 49300 45000 49300 1 0 0
{
T 45100 49250 5 8 1 1 0 0 1
pinnumber=2-F
T 44800 49350 5 8 0 0 0 0 1
pinseq=3
T 44800 49350 5 8 0 1 0 0 1
pinlabel=3
T 44800 49350 5 8 0 1 0 0 1
pintype=pas
}
P 45800 49700 46100 49700 1 0 1
{
T 45500 49650 5 8 1 1 0 0 1
pinnumber=1-R
T 45900 49750 5 8 0 0 0 0 1
pinseq=2
T 45900 49750 5 8 0 1 0 0 1
pinlabel=2
T 45900 49750 5 8 0 1 0 0 1
pintype=pas
}
]
{
T 44750 45650 5 10 0 1 0 0 1
device=HEADER16
T 45000 50000 5 10 1 1 0 0 1
refdes=J1
}
C 44700 41900 1 0 0 EMBEDDEDjack1.sym
[
T 44700 41100 8 10 0 0 0 0 1
class=IO
T 44700 41300 8 10 0 0 0 0 1
pins=16
T 45300 45200 8 10 0 1 0 0 1
refdes=J?
T 44750 40850 5 10 0 1 0 0 1
device=HEADER16
L 45400 45100 45400 41900 3 0 0 0 -1 -1
L 45000 43100 45800 43100 3 0 0 0 -1 -1
B 45000 41900 800 3200 3 0 0 0 -1 -1 0 -1 -1 -1 -1 -1
P 44700 42900 45000 42900 1 0 0
{
T 45100 42850 5 8 1 1 0 0 1
pinnumber=6-F
T 44800 42950 5 8 0 0 0 0 1
pinseq=11
T 44800 42950 5 8 0 1 0 0 1
pinlabel=11
T 44800 42950 5 8 0 1 0 0 1
pintype=pas
}
P 45800 42900 46100 42900 1 0 1
{
T 45500 42850 5 8 1 1 0 0 1
pinnumber=6-R
T 45900 42950 5 8 0 0 0 0 1
pinseq=12
T 45900 42950 5 8 0 1 0 0 1
pinlabel=12
T 45900 42950 5 8 0 1 0 0 1
pintype=pas
}
P 44700 42500 45000 42500 1 0 0
{
T 45100 42450 5 8 1 1 0 0 1
pinnumber=7-F
T 44800 42550 5 8 0 0 0 0 1
pinseq=13
T 44800 42550 5 8 0 1 0 0 1
pinlabel=13
T 44800 42550 5 8 0 1 0 0 1
pintype=pas
}
P 45800 42500 46100 42500 1 0 1
{
T 45500 42450 5 8 1 1 0 0 1
pinnumber=7-R
T 45900 42550 5 8 0 0 0 0 1
pinseq=14
T 45900 42550 5 8 0 1 0 0 1
pinlabel=14
T 45900 42550 5 8 0 1 0 0 1
pintype=pas
}
P 44700 42100 45000 42100 1 0 0
{
T 45100 42050 5 8 1 1 0 0 1
pinnumber=8-F
T 44800 42150 5 8 0 0 0 0 1
pinseq=15
T 44800 42150 5 8 0 1 0 0 1
pinlabel=15
T 44800 42150 5 8 0 1 0 0 1
pintype=pas
}
L 45000 42700 45800 42700 3 0 0 0 -1 -1
L 45000 42300 45800 42300 3 0 0 0 -1 -1
P 45800 42100 46100 42100 1 0 1
{
T 45500 42050 5 8 1 1 0 0 1
pinnumber=8-R
T 45900 42150 5 8 0 0 0 0 1
pinseq=16
T 45900 42150 5 8 0 1 0 0 1
pinlabel=16
T 45900 42150 5 8 0 1 0 0 1
pintype=pas
}
P 45800 44100 46100 44100 1 0 1
{
T 45500 44050 5 8 1 1 0 0 1
pinnumber=3-R
T 45900 44150 5 8 0 0 0 0 1
pinseq=6
T 45900 44150 5 8 0 1 0 0 1
pinlabel=6
T 45900 44150 5 8 0 1 0 0 1
pintype=pas
}
P 44700 43700 45000 43700 1 0 0
{
T 45100 43650 5 8 1 1 0 0 1
pinnumber=4-F
T 44800 43750 5 8 0 0 0 0 1
pinseq=7
T 44800 43750 5 8 0 1 0 0 1
pinlabel=7
T 44800 43750 5 8 0 1 0 0 1
pintype=pas
}
P 45800 43700 46100 43700 1 0 1
{
T 45500 43650 5 8 1 1 0 0 1
pinnumber=4-R
T 45900 43750 5 8 0 0 0 0 1
pinseq=8
T 45900 43750 5 8 0 1 0 0 1
pinlabel=8
T 45900 43750 5 8 0 1 0 0 1
pintype=pas
}
P 44700 43300 45000 43300 1 0 0
{
T 45100 43250 5 8 1 1 0 0 1
pinnumber=5-F
T 44800 43350 5 8 0 0 0 0 1
pinseq=9
T 44800 43350 5 8 0 1 0 0 1
pinlabel=9
T 44800 43350 5 8 0 1 0 0 1
pintype=pas
}
P 45800 43300 46100 43300 1 0 1
{
T 45500 43250 5 8 1 1 0 0 1
pinnumber=5-R
T 45900 43350 5 8 0 0 0 0 1
pinseq=10
T 45900 43350 5 8 0 1 0 0 1
pinlabel=10
T 45900 43350 5 8 0 1 0 0 1
pintype=pas
}
L 45000 43500 45800 43500 3 0 0 0 -1 -1
L 45000 44700 45800 44700 3 0 0 0 -1 -1
L 45000 43900 45800 43900 3 0 0 0 -1 -1
L 45000 44300 45800 44300 3 0 0 0 -1 -1
P 44700 44100 45000 44100 1 0 0
{
T 45100 44050 5 8 1 1 0 0 1
pinnumber=3-F
T 44800 44150 5 8 0 0 0 0 1
pinseq=5
T 44800 44150 5 8 0 1 0 0 1
pinlabel=5
T 44800 44150 5 8 0 1 0 0 1
pintype=pas
}
P 44700 44900 45000 44900 1 0 0
{
T 45050 44850 5 8 1 1 0 0 1
pinnumber=1-F
T 44850 44950 5 8 0 0 0 0 1
pinseq=1
T 44850 44950 5 8 0 1 0 0 1
pinlabel=1
T 44850 44950 5 8 0 1 0 0 1
pintype=pas
}
P 45800 44500 46100 44500 1 0 1
{
T 45500 44450 5 8 1 1 0 0 1
pinnumber=2-R
T 45900 44550 5 8 0 0 0 0 1
pinseq=4
T 45900 44550 5 8 0 1 0 0 1
pinlabel=4
T 45900 44550 5 8 0 1 0 0 1
pintype=pas
}
P 44700 44500 45000 44500 1 0 0
{
T 45100 44450 5 8 1 1 0 0 1
pinnumber=2-F
T 44800 44550 5 8 0 0 0 0 1
pinseq=3
T 44800 44550 5 8 0 1 0 0 1
pinlabel=3
T 44800 44550 5 8 0 1 0 0 1
pintype=pas
}
P 45800 44900 46100 44900 1 0 1
{
T 45500 44850 5 8 1 1 0 0 1
pinnumber=1-R
T 45900 44950 5 8 0 0 0 0 1
pinseq=2
T 45900 44950 5 8 0 1 0 0 1
pinlabel=2
T 45900 44950 5 8 0 1 0 0 1
pintype=pas
}
]
{
T 44750 40850 5 10 0 1 0 0 1
device=HEADER16
T 45000 45200 5 10 1 1 0 0 1
refdes=J4
}
C 51900 46700 1 0 1 EMBEDDEDjack1.sym
[
T 51900 45900 8 10 0 0 0 6 1
class=IO
T 51900 46100 8 10 0 0 0 6 1
pins=16
T 51300 50000 8 10 0 1 0 6 1
refdes=J?
T 51850 45650 5 10 0 1 0 6 1
device=HEADER16
L 51200 49900 51200 46700 3 0 0 0 -1 -1
L 51600 47900 50800 47900 3 0 0 0 -1 -1
B 50800 46700 800 3200 3 0 0 0 -1 -1 0 -1 -1 -1 -1 -1
P 51900 47700 51600 47700 1 0 0
{
T 51500 47650 5 8 1 1 0 6 1
pinnumber=6-F
T 51800 47750 5 8 0 0 0 6 1
pinseq=11
T 51800 47750 5 8 0 1 0 6 1
pinlabel=11
T 51800 47750 5 8 0 1 0 6 1
pintype=pas
}
P 50800 47700 50500 47700 1 0 1
{
T 51100 47650 5 8 1 1 0 6 1
pinnumber=6-R
T 50700 47750 5 8 0 0 0 6 1
pinseq=12
T 50700 47750 5 8 0 1 0 6 1
pinlabel=12
T 50700 47750 5 8 0 1 0 6 1
pintype=pas
}
P 51900 47300 51600 47300 1 0 0
{
T 51500 47250 5 8 1 1 0 6 1
pinnumber=7-F
T 51800 47350 5 8 0 0 0 6 1
pinseq=13
T 51800 47350 5 8 0 1 0 6 1
pinlabel=13
T 51800 47350 5 8 0 1 0 6 1
pintype=pas
}
P 50800 47300 50500 47300 1 0 1
{
T 51100 47250 5 8 1 1 0 6 1
pinnumber=7-R
T 50700 47350 5 8 0 0 0 6 1
pinseq=14
T 50700 47350 5 8 0 1 0 6 1
pinlabel=14
T 50700 47350 5 8 0 1 0 6 1
pintype=pas
}
P 51900 46900 51600 46900 1 0 0
{
T 51500 46850 5 8 1 1 0 6 1
pinnumber=8-F
T 51800 46950 5 8 0 0 0 6 1
pinseq=15
T 51800 46950 5 8 0 1 0 6 1
pinlabel=15
T 51800 46950 5 8 0 1 0 6 1
pintype=pas
}
L 51600 47500 50800 47500 3 0 0 0 -1 -1
L 51600 47100 50800 47100 3 0 0 0 -1 -1
P 50800 46900 50500 46900 1 0 1
{
T 51100 46850 5 8 1 1 0 6 1
pinnumber=8-R
T 50700 46950 5 8 0 0 0 6 1
pinseq=16
T 50700 46950 5 8 0 1 0 6 1
pinlabel=16
T 50700 46950 5 8 0 1 0 6 1
pintype=pas
}
P 50800 48900 50500 48900 1 0 1
{
T 51100 48850 5 8 1 1 0 6 1
pinnumber=3-R
T 50700 48950 5 8 0 0 0 6 1
pinseq=6
T 50700 48950 5 8 0 1 0 6 1
pinlabel=6
T 50700 48950 5 8 0 1 0 6 1
pintype=pas
}
P 51900 48500 51600 48500 1 0 0
{
T 51500 48450 5 8 1 1 0 6 1
pinnumber=4-F
T 51800 48550 5 8 0 0 0 6 1
pinseq=7
T 51800 48550 5 8 0 1 0 6 1
pinlabel=7
T 51800 48550 5 8 0 1 0 6 1
pintype=pas
}
P 50800 48500 50500 48500 1 0 1
{
T 51100 48450 5 8 1 1 0 6 1
pinnumber=4-R
T 50700 48550 5 8 0 0 0 6 1
pinseq=8
T 50700 48550 5 8 0 1 0 6 1
pinlabel=8
T 50700 48550 5 8 0 1 0 6 1
pintype=pas
}
P 51900 48100 51600 48100 1 0 0
{
T 51500 48050 5 8 1 1 0 6 1
pinnumber=5-F
T 51800 48150 5 8 0 0 0 6 1
pinseq=9
T 51800 48150 5 8 0 1 0 6 1
pinlabel=9
T 51800 48150 5 8 0 1 0 6 1
pintype=pas
}
P 50800 48100 50500 48100 1 0 1
{
T 51100 48050 5 8 1 1 0 6 1
pinnumber=5-R
T 50700 48150 5 8 0 0 0 6 1
pinseq=10
T 50700 48150 5 8 0 1 0 6 1
pinlabel=10
T 50700 48150 5 8 0 1 0 6 1
pintype=pas
}
L 51600 48300 50800 48300 3 0 0 0 -1 -1
L 51600 49500 50800 49500 3 0 0 0 -1 -1
L 51600 48700 50800 48700 3 0 0 0 -1 -1
L 51600 49100 50800 49100 3 0 0 0 -1 -1
P 51900 48900 51600 48900 1 0 0
{
T 51500 48850 5 8 1 1 0 6 1
pinnumber=3-F
T 51800 48950 5 8 0 0 0 6 1
pinseq=5
T 51800 48950 5 8 0 1 0 6 1
pinlabel=5
T 51800 48950 5 8 0 1 0 6 1
pintype=pas
}
P 51900 49700 51600 49700 1 0 0
{
T 51550 49650 5 8 1 1 0 6 1
pinnumber=1-F
T 51750 49750 5 8 0 0 0 6 1
pinseq=1
T 51750 49750 5 8 0 1 0 6 1
pinlabel=1
T 51750 49750 5 8 0 1 0 6 1
pintype=pas
}
P 50800 49300 50500 49300 1 0 1
{
T 51100 49250 5 8 1 1 0 6 1
pinnumber=2-R
T 50700 49350 5 8 0 0 0 6 1
pinseq=4
T 50700 49350 5 8 0 1 0 6 1
pinlabel=4
T 50700 49350 5 8 0 1 0 6 1
pintype=pas
}
P 51900 49300 51600 49300 1 0 0
{
T 51500 49250 5 8 1 1 0 6 1
pinnumber=2-F
T 51800 49350 5 8 0 0 0 6 1
pinseq=3
T 51800 49350 5 8 0 1 0 6 1
pinlabel=3
T 51800 49350 5 8 0 1 0 6 1
pintype=pas
}
P 50800 49700 50500 49700 1 0 1
{
T 51100 49650 5 8 1 1 0 6 1
pinnumber=1-R
T 50700 49750 5 8 0 0 0 6 1
pinseq=2
T 50700 49750 5 8 0 1 0 6 1
pinlabel=2
T 50700 49750 5 8 0 1 0 6 1
pintype=pas
}
]
{
T 51850 45650 5 10 0 1 0 6 1
device=HEADER16
T 51600 50000 5 10 1 1 0 6 1
refdes=J5
}
N 44700 49700 44500 49700 4
N 44500 49700 44500 49600 4
N 44700 49300 43600 49300 4
N 43600 49300 43600 49600 4
N 44700 48900 44500 48900 4
N 44500 48900 44500 48800 4
N 44700 48500 43600 48500 4
N 43600 48500 43600 48800 4
N 44700 48100 44500 48100 4
N 44500 48100 44500 48000 4
N 44700 47700 43600 47700 4
N 43600 47700 43600 48000 4
N 44700 47300 44500 47300 4
N 44500 47300 44500 47200 4
N 44700 46900 43600 46900 4
N 43600 46900 43600 47200 4
N 44700 44500 43700 44500 4
N 43700 42900 44700 42900 4
N 44700 44100 44500 44100 4
N 44500 44100 44500 44500 4
N 44700 42500 44500 42500 4
N 44500 42500 44500 42900 4
N 44700 42100 43300 42100 4
N 44700 44900 44500 44900 4
N 44700 43300 44500 43300 4
N 43700 42900 43700 43600 4
N 44000 43700 44700 43700 4
N 44000 43700 44000 43400 4
N 44000 43400 43300 43400 4
N 43300 43400 43300 43000 4
N 52100 49700 51900 49700 4
N 51900 49300 53000 49300 4
N 53000 49300 53000 49700 4
N 52100 48900 51900 48900 4
N 51900 48500 53000 48500 4
N 53000 48500 53000 48900 4
C 48000 46200 1 0 0 switch-spdt-2.sym
{
T 48410 47050 5 10 0 0 0 0 1
device=Dual_Two_Way_Switch
T 48410 47700 5 10 1 1 0 0 1
refdes=S1
T 48310 46500 5 10 0 0 0 0 1
footprint=CONNECTOR 2 3
T 48700 47900 5 10 0 0 0 0 1
symversion=1.0
}
C 48000 44200 1 0 0 switch-spdt-2.sym
{
T 48410 45050 5 10 0 0 0 0 1
device=Dual_Two_Way_Switch
T 48410 45700 5 10 1 1 0 0 1
refdes=S2
T 48310 44500 5 10 0 0 0 0 1
footprint=CONNECTOR 2 3
T 48700 45900 5 10 0 0 0 0 1
symversion=1.0
}
P 48300 43300 48000 43300 1 0 1
{
T 48160 43350 5 10 0 0 0 0 1
pinseq=2
T 48300 43300 5 10 0 1 0 0 1
pinnumber=2
T 48300 43300 5 10 0 1 0 0 1
pinlabel=2
T 48160 43350 5 10 0 1 0 0 1
pinlabel=2
T 48300 43300 5 10 0 1 0 0 1
pintype=pas
T 48160 43350 5 10 0 1 0 0 1
pintype=pas
}
P 48700 43500 49000 43500 1 0 1
{
T 48860 43550 5 10 0 0 0 0 1
pinseq=1
T 48710 43500 5 10 0 1 0 0 1
pinnumber=1
T 48710 43500 5 10 0 1 0 0 1
pinlabel=1
T 48860 43550 5 10 0 1 0 0 1
pinlabel=1
T 48710 43500 5 10 0 1 0 0 1
pintype=pas
T 48860 43550 5 10 0 1 0 0 1
pintype=pas
}
P 48700 43100 49000 43100 1 0 1
{
T 48860 43150 5 10 0 0 0 0 1
pinseq=3
T 48800 43050 5 10 0 1 0 0 1
pinnumber=3
T 48800 43050 5 10 0 1 0 0 1
pinlabel=3
T 48860 43150 5 10 0 1 0 0 1
pinlabel=3
T 48800 43050 5 10 0 1 0 0 1
pintype=pas
T 48860 43150 5 10 0 1 0 0 1
pintype=pas
}
L 48310 43300 48660 43450 3 0 0 0 -1 -1
V 48660 43500 50 3 0 0 0 -1 -1 0 -1 -1 -1 -1 -1
V 48660 43100 50 3 0 0 0 -1 -1 0 -1 -1 -1 -1 -1
T 45410 45450 8 10 0 0 0 0 1
device=Dual_Two_Way_Switch
T 48410 43700 8 10 1 1 0 0 1
refdes=S3
T 45310 44900 8 10 0 0 0 0 1
footprint=CONNECTOR 2 3
T 45700 46300 8 10 0 0 0 0 1
symversion=1.0
B 47800 42900 1400 5600 3 0 0 0 -1 -1 0 -1 -1 -1 -1 -1
T 48200 48200 9 10 1 0 0 0 1
MVU-8
N 46100 49700 49400 49700 4
N 49000 47500 49400 47500 4
N 46100 49300 49600 49300 4
N 49600 46700 49000 46700 4
N 46100 44100 47000 44100 4
N 47000 44100 47000 47300 4
N 47000 47300 48000 47300 4
N 46100 42500 47200 42500 4
N 47200 42500 47200 46500 4
N 47200 46500 48000 46500 4
N 46100 47700 46200 47700 4
N 46200 47700 46200 43300 4
N 46200 43300 46100 43300 4
N 46100 48100 46400 48100 4
N 46400 48100 46400 44900 4
N 46400 44900 46100 44900 4
N 46100 43700 46600 43700 4
N 46600 43700 46600 47300 4
N 46600 47300 46100 47300 4
N 46100 46900 46800 46900 4
N 46800 46900 46800 42100 4
N 46800 42100 46100 42100 4
N 49000 46300 49400 46300 4
N 47400 44500 47400 45300 4
N 47400 45300 48000 45300 4
N 46100 42900 47600 42900 4
N 47600 42900 47600 44500 4
N 47600 44500 48000 44500 4
N 46100 44500 47400 44500 4
N 49400 46300 49400 49700 4
N 49600 46700 49600 49300 4
N 49000 47100 49600 47100 4
N 48000 43300 47400 43300 4
N 47400 43300 47400 42500 4
N 47400 42500 50200 42500 4
N 49000 45500 49800 45500 4
N 49400 45500 49400 44300 4
N 49400 44300 49000 44300 4
N 49000 45100 49600 45100 4
N 49600 43500 49600 45100 4
N 49600 44700 49000 44700 4
N 49000 43500 49600 43500 4
N 46100 48500 47400 48500 4
N 47400 48500 47400 48700 4
N 47400 48700 49800 48700 4
N 49800 48700 49800 45500 4
N 50500 48500 49800 48500 4
N 46100 48900 50500 48900 4
N 50000 48900 50000 49700 4
N 50000 49700 50500 49700 4
N 50500 49300 50200 49300 4
N 50200 49300 50200 42500 4
B 45400 41700 5800 8900 3 0 0 0 -1 -1 0 -1 -1 -1 -1 -1
T 47600 50300 9 10 1 0 0 0 1
Connection Box
T 49000 47600 9 10 1 0 0 0 1
3
T 47900 47400 9 10 1 0 0 0 1
4
T 49000 47200 9 10 1 0 0 0 1
5
T 49000 46800 9 10 1 0 0 0 1
6
T 47900 46600 9 10 1 0 0 0 1
7
T 49000 46400 9 10 1 0 0 0 1
8
T 49000 45600 9 10 1 0 0 0 1
9
T 47900 45400 9 10 1 0 0 0 1
10
T 48900 45200 9 10 1 0 0 0 1
11
T 48900 44800 9 10 1 0 0 0 1
12
T 47900 44600 9 10 1 0 0 0 1
13
T 48900 44400 9 10 1 0 0 0 1
14
T 48900 43600 9 10 1 0 0 0 1
15
T 47900 43400 9 10 1 0 0 0 1
16
T 48900 43200 9 10 1 0 0 0 1
17
