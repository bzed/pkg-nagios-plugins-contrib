
# import buildflags
CFLAGS := $(shell dpkg-buildflags --get CFLAGS)
CPPFLAGS := $(shell dpkg-buildflags --get CPPFLAGS)
CXXFLAGS := $(shell dpkg-buildflags --get CXXFLAGS)
LDFLAGS := $(shell dpkg-buildflags --get LDFLAGS)

# define common directories
PLUGINDIR := /usr/lib/nagios/plugins
CONFIGDIR := /etc/nagios-plugins/config
CONFIGFILES := $(wildcard *.cfg)

# guess the name of the plugin to build if not defined
ifndef PLUGIN
PLUGIN := $(shell basename $(CURDIR))
endif

# add some default files to clean
CLEANFILES += $(wildcard *.o) $(wildcard *.a) $(wildcard *.so)


# build the stuff actually
all: $(PLUGIN)

install:
	install -d $(DESTDIR)$(PLUGINDIR)
	install -m 755 -o root -g root $(PLUGIN) $(DESTDIR)$(PLUGINDIR)
ifdef CONFIGFILES
	install -d $(DESTDIR)$(CONFIGDIR)
	install -m 644 -o root -g root $(CONFIGFILES) $(DESTDIR)$(CONFIGDIR)
endif

clean:
ifdef CLEANFILES
	rm -f $(CLEANFILES)
endif
