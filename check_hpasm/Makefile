PLUGIN := check_hpasm
CLEANFILES := check_hpasm

include ../common.mk

check_hpasm:
	set -e; for i in guess sub; do if [ ! -e src/config.$$i.bak ]; then cp src/config.$$i src/config.$$i.bak; fi; done
	cp /usr/share/misc/config.* src
	cd src && ./configure --prefix=/usr --enable-perfdata --enable-extendedinfo --with-nagios-user=nagios --with-nagios-group=nagios --with-degrees=celsius
	make -C src
	sed '2s,^,# nagios: -epn\n,' src/plugins-scripts/check_hpasm > $@

clean::
	[ ! -f src/Makefile ] || make -C src distclean
	set -e; for i in guess sub; do if [ -e src/config.$$i.bak ]; then mv src/config.$$i.bak src/config.$$i; fi; done
