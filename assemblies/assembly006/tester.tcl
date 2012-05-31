#!/usr/bin/tclsh

###############################################################################
# ������������� ��������� � 006
# �������� ������, ���������� �����, ����� �� �������� ������������� ������
# ��� ������ - ������������ ������� ��������� �������� 
#   � �������� � ���� ���������
###############################################################################

package require measure::logger
package require measure::config
package require hardware::owen::mvu8
package require scpi
package require hardware::agilent::mm34410a
package require measure::interop
package require measure::sigma
package require measure::tsclient
package require measure::datafile
package require measure::measure

###############################################################################
# ������������
###############################################################################

# �������������� ����������
proc openDevices {} {
	# ���� � ��������
	setConnectors { 0 0 0 0 }

	# ���������� ����������� � ����������� � �� ���������
	measure::measure::setupMmsForResistance -noFrontCheck
}

# ��������� ���������� ������������� ����� �������� � ������� ��������� �� �����
proc run {} {
	# �������������� ����������
	openDevices

	# �������� � ����� ���� �� ������� ������ ��������
	while { ![measure::interop::isTerminated] }	{
		set tm [clock milliseconds]

		# �������� ������������� � ������� ���������� � ���� ���������
		testMeasureAndDisplay

		# ����������� �����
		measure::interop::sleep [expr int(500 - ([clock milliseconds] - $tm))]
	}
}

###############################################################################
# ������ ������
###############################################################################

# ���������� ������ � ����������� ������ ����������
source [file join [file dirname [info script]] utils.tcl]

# �������������� ����������������
set log [measure::logger::init measure]

# ������ ��������� ���������
measure::config::read

# ��������� ������������ ��������
validateSettings

###############################################################################
# �������� ���� ���������
###############################################################################

# ��� ������� ����� ��������� � ������ ��������������� ��������� ������
measure::interop::registerFinalization { finish }

# ��������� ��������� ���������
run

# ��������� ������
finish

after 1000
