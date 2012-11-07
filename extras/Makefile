#!/usr/bin/make -f

DM_DIR=/usr/share/icinga/plugins/eventhandlers/distributed-monitoring/
MULTI_DIR=/etc/check_multi

all:
	#nothing to do.

install:
	install -d $(DESTDIR)$(MULTI_DIR)
	install -m 644 -o root -g root check_apt.cmd $(DESTDIR)$(MULTI_DIR)
	install -d $(DESTDIR)$(DM_DIR)
	install -m 755 -o root -g root send_nsca_host_or_service_check_result $(DESTDIR)$(DM_DIR)

