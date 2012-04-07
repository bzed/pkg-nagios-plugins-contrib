ifndef PREFIX
	PREFIX=/usr/local
endif
ifndef NAGIOS_LIB
	NAGIOS_LIB=/usr/lib/nagios/plugins
endif
ifndef BACKUPPC_LIB
	BACKUPPC_LIB=/usr/share/backuppc/lib
endif

install:
	sed -e "s|NAGIOS_LIB|$(NAGIOS_LIB)|g" -e \
		"s|BACKUPPC_LIB|${BACKUPPC_LIB}|g" check_backuppc \
		> check_backuppc.processed
	install -d ${PREFIX}/lib/nagios/plugins
	install -m 755 check_backuppc.processed ${PREFIX}/lib/nagios/plugins
	mv ${PREFIX}/lib/nagios/plugins/check_backuppc.processed \
		${PREFIX}/lib/nagios/plugins/check_backuppc
	install -m 644 check_backuppc.8 ${PREFIX}/man/man8

uninstall:
	rm -f ${PREFIX}/lib/nagios/plugins/check_backuppc
	rm -f ${PREFIX}/man/man8/check_backuppc.8
