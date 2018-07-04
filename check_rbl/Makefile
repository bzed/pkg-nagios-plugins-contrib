#/usr/bin/make -f

PLUGIN = src/check_rbl
MANPAGES = check_rbl.7
INIFILES = src/check_rbl.ini
DOCFILES = src/README.md
CLEANFILES = check_rbl.7


include ../common.mk


check_rbl.7: src/check_rbl.pod
	pod2man -s 7 $< > $@


