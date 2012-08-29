#!/usr/bin/make -f

DM_DIR=/usr/share/icinga/plugins/eventhandlers/distributed-monitoring/

all:
	#nothing to do.

install:
	install -d $(DESTDIR)$(DM_DIR)
	install -m 755 -o root -g root send_nsca_host_or_service_check_result $(DESTDIR)$(DM_DIR)

