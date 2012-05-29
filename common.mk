
# import buildflags
CFLAGS += $(shell dpkg-buildflags --get CFLAGS)
CPPFLAGS += $(shell dpkg-buildflags --get CPPFLAGS)
CXXFLAGS += $(shell dpkg-buildflags --get CXXFLAGS)
LDFLAGS += $(shell dpkg-buildflags --get LDFLAGS)

# define common directories
PLUGINDIR := /usr/lib/nagios/plugins
CRONJOBDIR := /usr/lib/nagios/cronjobs
CONFIGDIR := /etc/nagios-plugins/config
INIDIR := /etc/nagios-plugins
CONFIGFILES := $(wildcard *.cfg)

# guess the name of the plugin to build if not defined
PLUGINNAME := $(shell basename $(CURDIR))
ifndef PLUGIN
PLUGIN := $(PLUGINNAME)
endif

DOCDIR := /usr/share/doc/nagios-plugins-contrib/$(PLUGINNAME)

# add some default files to clean
# we actually need strip here. make is weird sometimes.
CLEANEXTRAFILES := $(strip $(wildcard *.o) $(wildcard *.a) $(wildcard *.so))

# build the stuff actually
all:: $(PLUGIN) $(MANPAGES) $(INIFILES) $(CRONJOBS)

install::
	install -d $(DESTDIR)$(PLUGINDIR)
	install -m 755 -o root -g root $(PLUGIN) $(DESTDIR)$(PLUGINDIR)
ifdef CONFIGFILES
	install -d $(DESTDIR)$(CONFIGDIR)
	install -m 644 -o root -g root $(CONFIGFILES) $(DESTDIR)$(CONFIGDIR)
endif
ifdef MANPAGES
	set -e; for m in $(MANPAGES); do \
		section=`echo $$m | sed 's,\.gz$$,,;s,.*\.,,'` ;\
		mandir="/usr/share/man/man$${section}" ;\
		install -d $(DESTDIR)$${mandir} ;\
		install -m 644 -o root -g root $${m} $(DESTDIR)$${mandir} ;\
	done
endif
ifdef INIFILES
	install -d $(DESTDIR)$(INIDIR)
	install -m 644 -o root -g root $(INIFILES) $(DESTDIR)$(INIDIR)
endif
ifdef DOCFILES
	install -d $(DESTDIR)$(DOCDIR)
	install -m 644 -o root -g root $(DOCFILES) $(DESTDIR)$(DOCDIR)
endif
ifdef CRONJOBS
	install -d $(DESTDIR)$(CRONJOBDIR)
	install -m 755 -o root -g root $(CRONJOBS) $(DESTDIR)$(CRONJOBDIR)
endif

clean::
ifdef CLEANFILES
	rm -f $(CLEANFILES)
endif
ifneq (,$(CLEANEXTRAFILES))
	rm -f $(CLEANEXTRAFILES)
endif

.PHONY: clean
