#/usr/bin/make -f

PLUGIN = src/check_lm_sensors
MANPAGES = check_lm_sensors.7
DOCFILES = src/README
CLEANFILES = check_lm_sensors.7

include ../common.mk


check_lm_sensors.7: src/check_lm_sensors.pod
	pod2man -s 7 $< > $@


