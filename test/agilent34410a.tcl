#!/usr/bin/tclsh

package require tcom

namespace eval Agilent34410ResolutionEnum {}
set Agilent34410ResolutionEnum::Agilent34410ResolutionLeast 0
set Agilent34410ResolutionEnum::Agilent34410ResolutionDefault 1
set Agilent34410ResolutionEnum::Agilent34410ResolutionBest 2

namespace eval Agilent34410AutoZeroEnum {
	set Agilent34410AutoZeroOff 0
	set Agilent34410AutoZeroOn 1
	set Agilent34410AutoZeroOnce 2
}

namespace eval Agilent34410TriggerSourceEnum {
	set Agilent34410TriggerSourceBus 0
	set Agilent34410TriggerSourceImmediate 1
	set Agilent34410TriggerSourceExternal 2
	set Agilent34410TriggerSourceInternal 3
}

namespace eval Agilent34410SampleSourceEnum {
	set Agilent34410SampleSourceImmediate 0
	set Agilent34410SampleSourceTimer 1
}

namespace eval Agilent34410DataFormatEnum {
	set Agilent34410DataFormatASCII 0
	set Agilent34410DataFormatReal32 1
	set Agilent34410DataFormatReal64 2
}

namespace eval Agilent34410MemoryTypeEnum {
	set Agilent34410MemoryTypeReadingMemory 0
	set Agilent34410MemoryTypeNonVolatileMemory 1
}

proc dump_interface { i msg } {
	set inf [::tcom::info interface $i]
	puts "== $msg ==========================="
	foreach m [$inf methods] {
		puts "$m"
	}
	puts "============================="
	}

#tcom::import "IviDriverTypeLib.dll"
set ns [tcom::import "IviDmmTypeLib.dll"]
puts "ns = $ns"
foreach cs [info commands "${ns}::*"] {
	puts $cs
}

set dmm [tcom::ref createobject "Agilent34410.Agilent34410"]

set ivi ["${ns}::IIviDmm" $dmm]
dump_interface $ivi IIviDmm

# dump_interface $dmm Dmm
$dmm Initialize "TCPIP0::g11.ind.agilent.com::inst0::INSTR" 0 0 "Simulate=true"

set id [$dmm Identity]
# dump_interface $id Identity
puts "Revision: [$id Revision]"
puts "Description: [$id Description]"
puts "InstrumentModel: [$id InstrumentModel]"
puts "Vendor: [$id Vendor]"
puts "InstrumentFirmwareRevision: [$id InstrumentFirmwareRevision]"

# Configure the 34410A/11A for voltage measurement, using 10 V range
# driverDmm.Voltage.DCVoltage.Configure(10, Agilent34410ResolutionEnum.Agilent34410ResolutionDefault)set voltage [$dmm Voltage]

set voltage [$dmm Voltage]
# dump_interface $voltage Voltage
set dcVoltage [$voltage DCVoltage]

set inf [::tcom::info interface $dcVoltage]
#puts "=== DCVoltage ============================"
foreach m [$inf methods] {
#	puts "$m"
}
#puts "=========================================="

$dcVoltage Configure [expr 10.0] $Agilent34410ResolutionEnum::Agilent34410ResolutionDefault
# driverDmm.Voltage.DCVoltage.AutoZero = Agilent34410AutoZeroEnum.Agilent34410AutoZeroOnce
$dcVoltage AutoZero $Agilent34410AutoZeroEnum::Agilent34410AutoZeroOnce

# Set aperture to 100usec (34411A can be set to 20usec)
# driverDmm.Voltage.DCVoltage.Aperture = 0.0001
$dcVoltage Aperture [expr 0.0001]

# Set up triggering for 1000 samples from a single trigger event
# driverDmm.Trigger.TriggerSource = Agilent34410TriggerSourceEnum.Agilent34410TriggerSourceInternal
set trigger [$dmm Trigger]
$trigger TriggerSource $Agilent34410TriggerSourceEnum::Agilent34410TriggerSourceExternal

#driverDmm.Trigger.TriggerCount = 1
$trigger TriggerCount 1

#driverDmm.Trigger.TriggerDelay = 0
$trigger TriggerDelay 0

#driverDmm.Trigger.SampleCount = 1000
$trigger SampleCount 1000

#driverDmm.Trigger.SampleInterval = 0.0001
$trigger SampleInterval [expr 0.0001]

#driverDmm.Trigger.SampleSource = Agilent34410SampleSourceEnum.Agilent34410SampleSourceTimer
$trigger SampleSource $Agilent34410SampleSourceEnum::Agilent34410SampleSourceTimer

# Set up data format for binary transfer 64-bit transfer
set dataFormat [$dmm DataFormat]
$dataFormat DataFormat $Agilent34410DataFormatEnum::Agilent34410DataFormatReal64

# Initiate the measurement
# driverDmm.Measurement.Initiate()
set measurement [$dmm Measurement]
# dump_interface $measurement Measurement
$measurement Initiate

# We will now read the results.  The method below illustrates how to read data out of the 
# 34410 as it becomes available.  This is more useful when taking large amounts of data or perhaps
# when doing a "continuous" measurement.  With this method, the application does not need to wait
# until all the data is taken to begin accessing (and possibly processing) some of the data. Instead
# a "block" of data is accumulated and then read out and processed in some way before getting the
# next "block".

# Get 1000 readings in "blocks" of 100
# Dim dataPts As Integer = 0
set dataPts 0
# Dim data As New ArrayList
set data [list]

# If (driverDmm.DriverOperation.Simulate = False) Then
set driverOperation [$dmm DriverOperation]
if { 1 || ![$driverOperation Simulate] } {

#   Dim i As Integer
#     For i = 0 To 9
	for { set i 0 } { $i < 10 } { incr i } {
#       While dataPts < 100
		while { $dataPts < 100 } {
#         dataPts = driverDmm.Measurement.ReadingCount(Agilent34410MemoryTypeEnum.Agilent34410MemoryTypeReadingMemory)
			set dataPts [$measurement ReadingCount $Agilent34410MemoryTypeEnum::Agilent34410MemoryTypeReadingMemory]
			if { [$driverOperation Simulate] } {
				break
			}
#       End While
		}
#
#       We have 100 data points, lets read them out
#       Dim tempData As Double()
#       tempData = driverDmm.Measurement.RemoveReadings(100)
		set tempData [$measurement RemoveReadings $dataPts] 
#       Add them to the "collection" array
#       At this point you could also "process" the data in some way while waiting for the next
#       "block" of measurements to be acquired by the instrument.
#       data.AddRange(tempData)
		set data [concat $data $tempData]
#       dataPts = 0
		set dataPts 0 
#
#     Next
	}
#
#   Console.WriteLine("Read out: {0} readings", data.Count)
	puts "Read out: [llength $data] readings"
#
#   Print first and last reading values
#   Console.WriteLine("First reading of 1000 taken was: {0} V", data(0))
	puts "First reading of [llength $data] taken was: [lindex $data 0] V"
#   Console.WriteLine("Last reading of 1000 taken was: {0} V", data(999))
	puts "Last reading of [llength $data] taken was: [lindex $data end] V"
# End If
}

# Measure DCV that has AC ripple
# Show using Peak Detect to capture peaks of ripple
# Make ACV and Frequency measurements of same signal
# Using Peak Detect essentially gives you an AC + DC measurement

# Configure the 34410 for a single reading, 10 Volt range
# driverDmm.Voltage.DCVoltage.Configure(10, Agilent34410ResolutionEnum.Agilent34410ResolutionDefault)
$dcVoltage Configure [expr 10.0] $Agilent34410ResolutionEnum::Agilent34410ResolutionDefault

# Set 10 Power Line Cycles of integration time on the measurement
# driverDmm.Voltage.DCVoltage.NPLC = 10.0
$dcVoltage NPLC [expr 10.0]

# Enable peak detection to capture any "noise" on the measurement
# driverDmm.Voltage.DCVoltage.PeakState = True
$dcVoltage PeakState 1

# Initiate the measurement
# driverDmm.Measurement.Initiate()
$measurement Initiate

# Allow a 2 second timeout when before trying to fetch
# driverDmm.System.WaitForOperationComplete(1100)
# driverDmm.System.TimeoutMilliseconds = 2000
set system [$dmm System]
# dump_interface $system System
$system TimeoutMilliseconds 2000

# Read the results -- only a single reading
# Dim data2 As Double()
# data2 = driverDmm.Measurement.Fetch()
set data2 [$measurement Fetch]

# Console.WriteLine("10 PLC reading was: {0} V", data2(0))
puts "10 PLC reading was: [lindex $data2 0] V"

# Dim maxPeak As Double = driverDmm.Voltage.DCVoltage.MaxPeak
set maxPeak [$dcVoltage MaxPeak]

# Dim minPeak As Double = driverDmm.Voltage.DCVoltage.MinPeak
set minPeak [$dcVoltage MinPeak]

# Dim pkToPk As Double = driverDmm.Voltage.DCVoltage.PeakToPeak
set pkToPk [$dcVoltage PeakToPeak]

# Console.WriteLine("maxPeak = {0} V; minPeak = {1} V; pkTopk = {2} V", maxPeak, minPeak, pkToPk)
puts "maxPeak = $maxPeak V; minPeak = $minPeak V; pkTopk = $pkToPk V"

# Measurement the AC RMS value of the ripple voltage
# Dim voltsAC As Double = driverDmm.Voltage.ACVoltage.Measure(-1, Agilent34410ResolutionEnum.Agilent34410ResolutionDefault)
set acVoltage [$voltage ACVoltage]
set voltsAC [$acVoltage Measure [expr -1.0] $Agilent34410ResolutionEnum::Agilent34410ResolutionDefault] 

# Console.WriteLine("An AC Volts measurement returned: {0} VAC", voltsAC)
puts "An AC Volts measurement returned: $voltsAC VAC"

# Measure frequency of the ripple voltage
# Dim freq As Double = driverDmm.Frequency.Measure(-1, Agilent34410ResolutionEnum.Agilent34410ResolutionDefault)
set frequency [$dmm Frequency]
set freq [$frequency Measure [expr -1.0] $Agilent34410ResolutionEnum::Agilent34410ResolutionDefault]

# Console.WriteLine("Frequency measurement returned: {0} Hz", freq)
puts "Frequency measurement returned: $freq Hz"

# driverDmm.Close()
$dmm Close

