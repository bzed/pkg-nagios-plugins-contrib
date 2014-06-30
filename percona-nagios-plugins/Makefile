#/usr/bin/make -f

PLUGIN = $(wildcard nagios/bin/*)
MANPAGES = $(shell find nagios/bin -type f -printf '%f\n' | sed 's,$$,.7,')
CLEANFILES = $(MANPAGES)

include ../common.mk


%.7: $(PLUGIN)
	pod2man -s 7 $< > $@


