#/usr/bin/make -f

PLUGIN = check_backuppc
MANPAGES = src/check_backuppc.8
DOCFILES = src/README
NAGIOS_LIB = /usr/lib/nagios/plugins
BACKUPPC_LIB = /usr/share/backuppc/lib
CLEANFILES = $(PLUGIN)

include ../common.mk

$(PLUGIN):
	sed -e "s|NAGIOS_LIB|$(NAGIOS_LIB)|g" -e \
		"s|BACKUPPC_LIB|${BACKUPPC_LIB}|g" src/check_backuppc > $@

