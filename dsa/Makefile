#!/usr/bin/make -f

PLUGIN:=$(shell cd checks; ls -1 | sed 's,^dsa-,,;s,-,_,g')


check_%:
	cp checks/dsa-`echo $@ | sed 's,_,-,g'` $@
	chmod 755 $@


CLEANFILES=$(PLUGIN)






include ../common.mk
