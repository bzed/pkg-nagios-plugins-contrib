SUBDIRS := $(strip $(shell find . -mindepth 2 -maxdepth 2 -name Makefile -printf '%h '))

default: all

$(SUBDIRS)::
	    $(MAKE) -C $@ $(MAKECMDGOALS)

all clean install : $(SUBDIRS)

