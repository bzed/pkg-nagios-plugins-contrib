#!/usr/bin/make -f

PLUGIN:=$(shell cd checks; ls -1 | sed 's,^dsa-,,;s,-,_,g')
CRONJOBS:=$(shell cd sbin; ls -1 | sed 's,^dsa-,,')
INIFILES:=etc/obsolete-packages-ignore
DOCFILES:=$(wildcard *.cmd)

check_%:
	cp checks/dsa-`echo $@ | sed 's,_,-,g'` $@
	chmod 755 $@

update-%-status:
	cp sbin/dsa-$@ $@
	chmod 755 $@

CLEANFILES=$(PLUGIN) $(CRONJOBS)


include ../common.mk

install::
	install -d $(DESTDIR)$(INIDIR)/obsolete-packages-ignore.d

