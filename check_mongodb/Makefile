PLUGIN := check_mongodb
CLEANFILES := check_mongodb
DOCFILES := README.md

include ../common.mk

check_mongodb:
	cp $@.py $@
	chmod 755 $@

install::
	install -d $(DESTDIR)$(PLUGINDIR)
	ln -s $(PLUGINDIR)/$(PLUGIN) $(DESTDIR)$(PLUGINDIR)/$(PLUGIN).py

