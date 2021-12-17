
PD = nagios-plugins-linux

PLUGINS += check_clock
PLUGINS += check_cpu
PLUGINS += check_cpufreq
PLUGINS += check_cswch
PLUGINS += check_fc
PLUGINS += check_ifmountfs
PLUGINS += check_intr
PLUGINS += check_iowait
PLUGINS += check_memory
PLUGINS += check_nbprocs
PLUGINS += check_network
PLUGINS += check_network_collisions
PLUGINS += check_network_dropped
PLUGINS += check_network_errors
PLUGINS += check_network_multicast
PLUGINS += check_paging
PLUGINS += check_pressure
PLUGINS += check_readonlyfs
PLUGINS += check_tcpcount
PLUGINS += check_temperature

PLUGINS_RENAME += check_load
PLUGINS_RENAME += check_multipath
PLUGINS_RENAME += check_swap
PLUGINS_RENAME += check_uptime
PLUGINS_RENAME += check_users

all:
	cd ${PD} && dh_autoreconf
	mkdir build-tree
	cd build-tree && \
	  ../${PD}/configure --prefix=/usr --libexecdir=/usr/lib/nagios/plugins && \
	  $(MAKE)

install:
	install -d $(DESTDIR)/usr/lib/nagios
	for check in $(PLUGINS); do \
	  if [ -h build-tree/plugins/$${check} ]; then \
	    ln -s $$(readlink build-tree/plugins/$${check}) ${DESTDIR}/usr/lib/nagios/plugins/$${check} || exit 1; \
	  else \
	    install -m 755 -o root -g root build-tree/plugins/$${check} ${DESTDIR}/usr/lib/nagios/plugins || exit 1; \
	  fi; \
	done; true

	for check in $(PLUGINS_RENAME); do \
		install -m 755 -o root -g root build-tree/plugins/$${check} ${DESTDIR}/usr/lib/nagios/plugins/check_madrisan_$${check#check_} || exit 1; \
	done; true

clean:
	rm -rf build-tree
