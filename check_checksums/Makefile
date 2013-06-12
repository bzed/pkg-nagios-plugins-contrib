PLUGIN := check_checksums

include ../common.mk

install::
	install -d $(DESTDIR)/usr/lib/nagios
	install -m 755 -o root -g root update_checksums $(DESTDIR)/usr/lib/nagios

