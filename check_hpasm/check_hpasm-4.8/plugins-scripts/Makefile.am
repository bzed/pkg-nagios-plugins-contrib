## Process this file with automake to produce Makefile.in

SED=/bin/sed
GREP=/bin/grep
CAT=/bin/cat
ECHO=/bin/echo

SUFFIXES = .pl .pm .sh

VPATH=$(top_srcdir) $(top_srcdir)/plugins-scripts $(top_srcdir)/plugins-scripts/t

libexec_SCRIPTS=check_hpasm
MY_MODULES=
EXTRA_MODULES=\
  Nagios/MiniPlugin.pm \
  HP/SNMP/Utils.pm \
  HP/Proliant/Component/EventSubsystem.pm \
  HP/Proliant/Component/EventSubsystem/CLI.pm \
  HP/Proliant/Component/EventSubsystem/SNMP.pm \
  HP/Proliant/Component/PowersupplySubsystem.pm \
  HP/Proliant/Component/PowersupplySubsystem/CLI.pm \
  HP/Proliant/Component/PowersupplySubsystem/SNMP.pm \
  HP/Proliant/Component/TemperatureSubsystem.pm \
  HP/Proliant/Component/TemperatureSubsystem/CLI.pm \
  HP/Proliant/Component/TemperatureSubsystem/SNMP.pm \
  HP/Proliant/Component/CpuSubsystem.pm \
  HP/Proliant/Component/CpuSubsystem/CLI.pm \
  HP/Proliant/Component/CpuSubsystem/SNMP.pm \
  HP/Proliant/Component/FanSubsystem.pm \
  HP/Proliant/Component/FanSubsystem/CLI.pm \
  HP/Proliant/Component/FanSubsystem/SNMP.pm \
  HP/Proliant/Component/MemorySubsystem/CLI.pm \
  HP/Proliant/Component/MemorySubsystem/SNMP.pm \
  HP/Proliant/Component/MemorySubsystem.pm \
  HP/Proliant/Component/NicSubsystem/SNMP.pm \
  HP/Proliant/Component/NicSubsystem.pm \
  HP/Proliant/Component/AsrSubsystem/CLI.pm \
  HP/Proliant/Component/AsrSubsystem/SNMP.pm \
  HP/Proliant/Component/AsrSubsystem.pm \
  HP/Proliant/Component/SNMP.pm \
  HP/Proliant/Component/DiskSubsystem/Da/CLI.pm \
  HP/Proliant/Component/DiskSubsystem/Da/SNMP.pm \
  HP/Proliant/Component/DiskSubsystem/Da.pm \
  HP/Proliant/Component/DiskSubsystem/Sas/CLI.pm \
  HP/Proliant/Component/DiskSubsystem/Sas/SNMP.pm \
  HP/Proliant/Component/DiskSubsystem/Sas.pm \
  HP/Proliant/Component/DiskSubsystem/Scsi/CLI.pm \
  HP/Proliant/Component/DiskSubsystem/Scsi/SNMP.pm \
  HP/Proliant/Component/DiskSubsystem/Scsi.pm \
  HP/Proliant/Component/DiskSubsystem/Ide/CLI.pm \
  HP/Proliant/Component/DiskSubsystem/Ide/SNMP.pm \
  HP/Proliant/Component/DiskSubsystem/Ide.pm \
  HP/Proliant/Component/DiskSubsystem/Fca/CLI.pm \
  HP/Proliant/Component/DiskSubsystem/Fca/SNMP.pm \
  HP/Proliant/Component/DiskSubsystem/Fca.pm \
  HP/Proliant/Component/DiskSubsystem.pm \
  HP/Proliant/Component/BatterySubsystem/CLI.pm \
  HP/Proliant/Component/BatterySubsystem/SNMP.pm \
  HP/Proliant/Component/BatterySubsystem.pm \
  HP/Proliant/Component.pm \
  HP/Proliant.pm \
  HP/BladeSystem/Component/CommonEnclosureSubsystem.pm \
  HP/BladeSystem/Component/CommonEnclosureSubsystem/FanSubsystem.pm \
  HP/BladeSystem/Component/CommonEnclosureSubsystem/TempSubsystem.pm \
  HP/BladeSystem/Component/CommonEnclosureSubsystem/FuseSubsystem.pm \
  HP/BladeSystem/Component/CommonEnclosureSubsystem/ManagerSubsystem.pm \
  HP/BladeSystem/Component/PowerEnclosureSubsystem.pm \
  HP/BladeSystem/Component/PowerSupplySubsystem.pm \
  HP/BladeSystem/Component/NetConnectorSubsystem.pm \
  HP/BladeSystem/Component/ServerBladeSubsystem.pm \
  HP/BladeSystem/Component.pm \
  HP/BladeSystem.pm \
  HP/Storage.pm \
  HP/StorageWorks.pm \
  HP/Server.pm
EXTRA_DIST=check_hpasm.pl $(EXTRA_MODULES)

CLEANFILES=$(libexec_SCRIPTS)

AM_INSTALL_PROGRAM_FLAGS=@INSTALL_OPTS@

.pm :
	$(AWK) -f ./subst $< > $@
	chmod +x $@

.pl :
	$(AWK) -f ./subst $< > $@
	chmod +x $@

.sh :
	$(AWK) -f ./subst $< > $@
	chmod +x $@

$(libexec_SCRIPTS) : $(EXTRA_DIST)
	$(ECHO) "#! #PERL# -w" | $(AWK) -f ./subst > $@
	$(ECHO) >> $@
	for m in ${EXTRA_MODULES}; do \
		$(SED) -e 's/^1;//g' < $$m | $(AWK) -f ./subst | $(GREP) -v "use Nagios::Plugin" >> $@; \
	done
	$(ECHO) "package main;" >> $@
	$(CAT) check_hpasm.pl | $(AWK) -f ./subst >> $@
	chmod +x $@
#| $(GREP) -v "use Nagios" >> $@;

