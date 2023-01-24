PLUGIN := check_printer_health
CLEANFILES := check_printer_health

include ../common.mk

check_printer_health:
	set -e; for i in guess sub; do if [ ! -e src/config.$$i.bak ]; then cp src/config.$$i src/config.$$i.bak; fi; done
	cp /usr/share/misc/config.* src
	cd src && ./configure --prefix=/usr --enable-perfdata --enable-extendedinfo --with-nagios-user=nagios --with-nagios-group=nagios --with-degrees=celsius
	make -C src
	sed -i '/#.*nagios: .epn/d' src/plugins-scripts/check_printer_health
	sed '2s,^,# nagios: -epn\n,' src/plugins-scripts/check_printer_health > $@

clean::
	[ ! -f src/Makefile ] || make -C src distclean
	set -e; for i in guess sub; do if [ -e src/config.$$i.bak ]; then mv src/config.$$i.bak src/config.$$i; fi; done
