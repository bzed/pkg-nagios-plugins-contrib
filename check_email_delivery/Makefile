#/usr/bin/make -f

PLUGIN = $(wildcard src/check_*) $(wildcard src/imap_ssl_*)
MANPAGES = $(shell find src/docs -regex '[^ ]*.pod' -printf '%f\n' | sed 's,pod$$,7,')
DOCFILES = src/docs/*.html src/docs/*.txt src/README.txt
CLEANFILES = $(MANPAGES)

include ../common.mk


%.7: src/docs/%.pod
	pod2man -s 7 $< > $@


