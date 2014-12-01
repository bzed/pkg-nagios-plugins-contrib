#!/usr/bin/make -f

INIFILES = check-libs.conf
PLUGIN = check_libs
CLEANFILES = $(INIFILES) $(PLUGIN)
CRONJOBS:= update-check_libs-status

include ../common.mk

check_libs:
	cp nagios-check-libs $@
	chmod 755 $@

check-libs.conf:
	cp nagios-check-libs.conf $@

