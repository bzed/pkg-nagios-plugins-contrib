PLUGINS := $(strip $(shell find . -mindepth 2 -maxdepth 2 -name Makefile -printf '%h '))

ifeq ($(wildcard '/etc/debian_version'),'/etc/debian_version')
HOST_ARCH := $(strip $(shell dpkg-architecture -q DEB_HOST_ARCH))
else
ifeq ($(wildcard '/usr/bin/rpm'),'/usr/bin/rpm')
HOST_ARCH := $(strip $(shell rpm --eval '%{_arch}'))
endif
endif

ifeq ($(HOST_ARCH),$(filter $(HOST_ARCH), hurd-i386))
	PLUGINS := $(filter-out check_memcached check_varnish,$(PLUGINS))
endif
ifeq ($(HOST_ARCH),$(filter $(HOST_ARCH), arm64))
	PLUGINS := $(filter-out check_memcached,$(PLUGINS))
endif
ifeq ($(HOST_ARCH),$(filter $(HOST_ARCH), m68k))
	PLUGINS := $(filter-out check_varnish,$(PLUGINS))
endif


default: all

$(PLUGINS)::
	$(MAKE) -C $@ $(MAKECMDGOALS)

all clean install : $(PLUGINS)

