#!/usr/bin/perl
#
# DESCRIPTION: Nagios plugin for checking the status of multipath devices on Linux servers.
#         
#
# AUTHOR:      Hinnerk Rümenapf (hinnerk.ruemenapf@rrz.uni-hamburg.de)
#              Based on work by 
#              - Trond H. Amundsen <t.h.amundsen@usit.uio.no>
#              - Gunther Schlegel  <schlegel@riege.com>
#              - Matija Nalis      <mnalis+debian@carnet.hr>
#
#-------------------------------------------------------------
#
# == IMPORTANT ==
#
# "sudo" must be configured to allow 'multipath -l' 
# and/or 'multipath -ll' if you intend to use the option -ll
# (and also 'multipath -r', if you intend to use the --reload option)
# for the NAGIOS-user without password
#
#-------------------------------------------------------------
#
#
# Copyright (C) 2011-2022
# Hinnerk Rümenapf, Trond H. Amundsen, Gunther Schlegel, Matija Nalis, 
# Bernd Zeimetz, Sven Anders, Ben Evans
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
#  Vs  0.0.1    Initial Version 
#      0.0.2    added check if path is 'active', fixed messages sorting,
#               shorter messages, path state line check more flexible
#
#      0.1.0    added support for older 'multipath'-tool version, added
#               testcase 14 and 15
#
#      0.1.1    bugfix, improved flexibility, added testcases 16 and 17
#      0.1.2    added support for more 'multipath'-tool versions, added testcases 18 and 19
#      0.1.3    minor improvements
#      0.1.4    add hostname to "unknown error" message, improve help text
#      0.1.5    add debian testcases and patch by Bernd Zeimetz
#      0.1.6    Added checklunline test for "-" character, thanks to Sven Anders <s.anders@digitec.de> also for test data (testcase 22)
#      0.1.7    Added test option
#      0.1.8    Added Support for LUN names without WWID (e.g. iSCSI LUNs)
#      0.1.9    Added extraconfig option
#
#      0.2.0    Improved flexibility, more testcases. Thanks to Benjamin von Mossner and Ben Evans
#               Warning if data for LUNs in --extraconfig is missing
#               Added --reload option (based on Ben Evans' idea)
#      0.2.1    Improved LUN-line check, thanks to Michal Svamberg
#      0.2.2    Improved path error check, extended extraconfig capabilities (thanks to Nasimuddin Ansari for his comment)
#      
#      0.3.0    Added Option --ll, added handling of checker messages. Thanks to Andreas Steinel <Andreas.Steinel@exirius.de>
#
#      0.4.0    Added check if multipathd is running (suggested by Dmitry Sakoun)            11. Dec. 2015
#               Added --group option (based on comments by Robert Towster and Tom Schier)
#      0.4.1    minor changes                                                                14. Dec. 2015
#
#      0.4.5    distinguish between different attributes identifying a LUN (OPTIONAL) (based on suggestions by Séverin Launiau)
#               for output and extraconfig LUN-selector (see usage message)
#               Added ability to check counts of policies per LUN  (suggested by Jim Clark)
#               Added ability to check counts of scsi-hosts and scsi-ids per LUN              3. Aug. 2016
#      0.4.6    Bugfix (output)
#      0.4.7    Compatibility with CentOS/RHEL 5-7: no "switch", check second directory for multipath binary   (thanks to Christian Zettel) 25. Aug. 2016
#      0.4.8    More characters allowed in LUN Name               (thanks to Ivan Zikyamov)  06. JAN 2020
#      0.4.9    Bugfix in  --extraconfig  handling                (thanks to Jeffrey Honig <jeffrey.honig@xandr.com>)  24. MAR 2020
#      0.4.10   minor code cleanup after bugfix; handle local NVMe drive (thanks to Jeffrey Honig <jeffrey.honig@xandr.com>)  26. JAN 2021
#      0.4.11   New nvme examples, paser edited                   (thanks to  Paul Garn <paul.garn@hpe.com>)  28. JAN 2021
#      0.4.12   Recognise and store (some) messages from multipath call (thanks to Philip Morales) 12. APR 2022
#


use strict;
use warnings;
#use Switch; ## causes compatibility issues (perl version)
use POSIX qw(isatty);
use Getopt::Long qw(:config no_ignore_case);

# Global (package) variables used throughout the code
use vars qw( $NAME $VERSION $AUTHOR $CONTACT $E_OK $E_WARNING $E_CRITICAL
	     $E_UNKNOWN $USAGE $HELP $LICENSE $SUDO $MULTIPATH_LIST $MULTIPATH_LIST_LONG $MULTIPATH_RELOAD
             $linebreak $counter $exit_code
	     %opt %reverse_exitcode %text2exit @multipathStateLines %nagios_level_count
	     @perl_warnings @reports  @ok_reports @debugInput 
	  );

#---------------------------------------------------------------------
# Initialization and global variables
#---------------------------------------------------------------------


# === Version and similar info ===
$NAME    = 'check-multipath.pl';
$VERSION = '0.4.12  12. Apr 2022';
$AUTHOR  = 'Hinnerk Rümenapf';
$CONTACT = 'hinnerk [DOT] ruemenapf [AT] uni-hamburg [DOT] de   (or  hinnerk [AT] ruemenapf [DOT] de)';



# Collect perl warnings in an array
$SIG{__WARN__} = sub { push @perl_warnings, [@_]; };


#---------------------------------------------
# TESTCASES
#
# These testcases are important documentation
# and thus included in the script!
#---------------------------------------------
@debugInput=(

# 0. DUMMY
"",

# 1.  OK, 2 LUNs, 4 paths each (REAL example)
"mpathb (36000d774000045f655ea91cb4ea41d6f) dm-1 FALCON,IPSTOR DISK\n"
."size=1.9T features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=1 status=active\n"
."  |- 4:0:1:1 sdd 8:48  active ready running\n"
."  |- 4:0:0:1 sdf 8:80  active ready running\n"
."  |- 3:0:0:1 sdh 8:112 active ready running\n"
."  `- 3:0:1:1 sdk 8:160 active ready running\n"
."mpatha (36000d77b000048d117c68c81bf7c160a) dm-0 FALCON,IPSTOR DISK\n"
."size=2.0T features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=1 status=active\n"
."  |- 4:0:1:0 sdc 8:32  active ready running\n"
."  |- 4:0:0:0 sde 8:64  active ready running\n"
."  |- 3:0:0:0 sdg 8:96  active ready running\n"
."  `- 3:0:1:0 sdi 8:128 active ready running\n",


# 2. WARN, 2 LUNs, one path missing (REAL example)
"mpathb (36000d774000045f655ea91cb4ea41d6f) dm-1 FALCON,IPSTOR DISK\n"
."size=1.9T features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=1 status=active\n"
."  |- 3:0:0:1 sdf 8:80  active ready running\n"
."  |- 4:0:0:1 sdi 8:128 active ready running\n"
."  `- 4:0:1:1 sdk 8:160 active ready running\n"
."mpatha (36000d77b000048d117c68c81bf7c160a) dm-0 FALCON,IPSTOR DISK\n"
."size=2.0T features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=1 status=active\n"
."  |- 3:0:0:0 sdc 8:32  active ready running\n"
."  |- 4:0:0:0 sdg 8:96  active ready running\n"
."  |- 3:0:1:0 sdh 8:112 active ready running\n"
."  `- 4:0:1:0 sde 8:64  active ready running\n",


# 3. ERR, 2 LUNs, no paths (REAL example)
"mpathb (36000d774000045f655ea91cb4ea41d6f) dm-1 \n"
."size=1.9T features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."mpatha (36000d77b000048d117c68c81bf7c160a) dm-0 \n"
."size=2.0T features='1 queue_if_no_path' hwhandler='0' wp=rw\n",


#4. OK, 1 LUN, 4 paths (edit)
"mpathb (36000d774000045f655ea91cb4ea41d6f) dm-1 FALCON,IPSTOR DISK\n"
."size=1.9T features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=1 status=active\n"
."  |- 4:0:1:1 sdd 8:48  active ready running\n"
."  |- 4:0:0:1 sdf 8:80  active ready running\n"
."  |- 3:0:0:1 sdh 8:112 active ready running\n"
."  `- 3:0:1:1 sdk 8:160 active ready running\n",


#5. WARN, 1 LUN, 2 paths (edit)
"mpathb (36000d774000045f655ea91cb4ea41d6f) dm-1 FALCON,IPSTOR DISK\n"
."size=1.9T features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=1 status=active\n"
."  |- 4:0:1:1 sdd 8:48  active ready running\n"
."  `- 3:0:1:1 sdk 8:160 active ready running\n",


#6. WARN, 1 LUN, 1 path (edit)
"mpathb (36000d774000045f655ea91cb4ea41d6f) dm-1 FALCON,IPSTOR DISK\n"
."size=1.9T features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=1 status=active\n"
."  `- 3:0:1:1 sdk 8:160 active ready running\n",


#7. WARN, 1 LUN, 1 no paths (edit)
"mpathb (36000d774000045f655ea91cb4ea41d6f) dm-1 \n"
."size=1.9T features='1 queue_if_no_path' hwhandler='0' wp=rw\n",



#8. WARN 2 LUNs, 4 paths each, TEST: failed/faulty (edit)
"mpathb (36000d774000045f655ea91cb4ea41d6f) dm-1 FALCON,IPSTOR DISK\n"
."size=1.9T features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=1 status=active\n"
."  |- 4:0:1:1 sdd 8:48  active ready running\n"
."  |- 4:0:0:1 sdf 8:80  failed ready running\n"
."  |- 3:0:0:1 sdh 8:112 active faulty running\n"
."  `- 3:0:1:1 sdk 8:160 dadada ready running\n"
."mpatha (36000d77b000048d117c68c81bf7c160a) dm-0 FALCON,IPSTOR DISK\n"
."size=2.0T features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=1 status=active\n"
."  |- 4:0:1:0 sdc 8:32  faulty ready running\n"
."  |- 4:0:0:0 sde 8:64  dadada ready failed\n"
."  `- 3:0:1:0 sdi 8:128 active ready running\n",


#9. NO LUN
"",


#10. Syntax error 1
"mpathb (36000d774000045f655ea91cb4ea41d6f) dm-1 FALCON,IPSTOR DISK\n"
."size=1.9T features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=1 status=active\n"
."4:0:1:1 sdd 8:48  active ready running\n"
."  |- 4:0:0:1 sdf 8:80  failed ready running\n"
."  |- 3:0:0:1 sdh 8:112 active faulty running\n"
."  `- 3:0:1:1 sdk 8:160 active ready running\n",


# 11. Syntax error 2
"mpatha 36000d77b000048d117c68c81bf7c160a) dm-0 FALCON,IPSTOR DISK\n"
."size=2.0T features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=1 status=active\n"
."  |- 4:0:1:0 sdc 8:32  faulty ready running\n"
."  |- 4:0:0:0 sde 8:64  active ready failed\n"
."  `- 3:0:1:0 sdi 8:128 active ready running\n",


# 12. Syntax error 3
"mpatha (36000d77b000048d117c68c81bf7c160a) dm-0 FALCON,IPSTOR DISK\n"
."sisze=2.0T features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=1 status=active\n"
."  |- 4:0:1:0 sdc 8:32  faulty ready running\n"
."  |- 4:0:0:0 sde 8:64  active ready failed\n"
."  `- 3:0:1:0 sdi 8:128 active ready running\n",


#13. Syntax error 4
"  |- 4:0:1:1 sdd 8:48  active ready running\n"
."  `- 3:0:1:1 sdk 8:160 active ready running\n",


#14. old syntax OK (REAL example)
"mpathb (36000d774000045f655ea91cb4ea41d6f) dm-1 FALCON,IPSTOR DISK\n"
."[size=1.9T][features=1 queue_if_no_path][hwhandler=0][rw]\n"
."\\_ round-robin 0 [prio=-4][active]\n"
." \\_ 3:0:1:1 sde 8:64  [active][undef]\n"
." \\_ 3:0:0:1 sdi 8:128 [active][undef]\n"
." \\_ 4:0:1:1 sdj 8:144 [active][undef]\n"
." \\_ 4:0:0:1 sdf 8:80  [active][undef]\n"
."mpatha (36000d77b000048d117c68c81bf7c160a) dm-0 FALCON,IPSTOR DISK\n"
."[size=2.0T][features=1 queue_if_no_path][hwhandler=0][rw]\n"
."\\_ round-robin 0 [prio=-4][active]\n"
." \\_ 3:0:0:0 sdg 8:96  [active][undef]\n"
." \\_ 3:0:1:0 sdc 8:32  [active][undef]\n"
." \\_ 4:0:0:0 sdd 8:48  [active][undef]\n"
." \\_ 4:0:1:0 sdh 8:112 [active][undef]\n",


#15. old syntax ERR (edit)
"mpathb (36000d774000045f655ea91cb4ea41d6f) dm-1 FALCON,IPSTOR DISK\n"
."[size=1.9T][features=1 queue_if_no_path][hwhandler=0][rw]\n"
."\\_ round-robin 0 [prio=-4][active]\n"
." \\_ 3:0:1:1 sde 8:64  [fault][undef]\n"
." \\_ 4:0:1:1 sdj 8:144 [active][undef]\n"
." \\_ 4:0:0:1 sdf 8:80  [active][undef]\n"
."mpatha (36000d77b000048d117c68c81bf7c160a) dm-0 FALCON,IPSTOR DISK\n"
."[size=2.0T][features=1 queue_if_no_path][hwhandler=0][rw]\n"
."\\_ round-robin 0 [prio=-4][active]\n"
." \\_ 3:0:0:0 sdg 8:96  [active][undef]\n"
." \\_ 3:0:1:0 sdc 8:32  [dadada][undef]\n"
." \\_ 4:0:0:0 sdd 8:48  [active][fail]\n"
." \\_ 4:0:1:0 sdh 8:112 [fault][undef]\n",


#16. Other sample (REAL example, thanks to Kai Groshert)
"36006016019e02a00d009495ddbf3e011 dm-2 DGC,VRAID\n"
."size=450G features='1 queue_if_no_path' hwhandler='1 emc' wp=rw\n"
."|-+- policy='round-robin 0' prio=0 status=active\n"
."| |- 2:0:0:1 sdi 8:128 active undef running\n"
."| `- 1:0:0:1 sdc 8:32  active undef running\n"
."`-+- policy='round-robin 0' prio=0 status=enabled\n"
."  |- 1:0:1:1 sdf 8:80  active undef running\n"
."  `- 2:0:1:1 sdl 8:176 active undef running\n"
."36006016019e02a008e1c5f67dbf3e011 dm-5 DGC,VRAID\n"
."size=550G features='1 queue_if_no_path' hwhandler='1 emc' wp=rw\n"
."|-+- policy='round-robin 0' prio=0 status=active\n"
."| |- 1:0:1:2 sdg 8:96  active undef running\n"
."| `- 2:0:1:2 sdm 8:192 active undef running\n"
."`-+- policy='round-robin 0' prio=0 status=enabled\n"
."  |- 1:0:0:2 sdd 8:48  active undef running\n"
."  `- 2:0:0:2 sdj 8:144 active undef running\n"
."36003005700f0eb70160c9b590a77c13e dm-0 LSI,RAID 5/6 SAS 6G\n"
."size=136G features='0' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=0 status=active\n"
."  `- 0:2:0:0 sda 8:0   active undef running\n",


#17. Other sample, modified (thanks to Kai Groshert)
"36006016019e02a00d009495ddbf3e011 dm-2 DGC,VRAID\n"
."size=450G features='1 queue_if_no_path' hwhandler='1 emc' wp=rw\n"
."|-+- policy='round-robin 0' prio=0 status=active\n"
."| |- 2:0:0:1 sdi 8:128 active undef running\n"
."| `- 1:0:0:1 sdc 8:32  undef undef running\n"
."`-+- policy='round-robin 0' prio=0 status=enabled\n"
."  |- 1:0:1:1 sdf 8:80  active undef running\n"
."  `- 2:0:1:1 sdl 8:176 active undef running\n"
."36006016019e02a008e1c5f67dbf3e011 dm-5 DGC,VRAID\n"
."size=550G features='1 queue_if_no_path' hwhandler='1 emc' wp=rw\n"
."|-+- policy='round-robin 0' prio=0 status=active\n"
."| |- 1:0:1:2 sdg 8:96  active undef running\n"
."`-+- policy='round-robin 0' prio=0 status=enabled\n"
."  |- 1:0:0:2 sdd 8:48  active undef running\n"
."  `- 2:0:0:2 sdj 8:144 failed undef dadada\n"
."36003005700f0eb70160c9b590a77c13e dm-0 LSI,RAID 5/6 SAS 6G\n"
."size=136G features='0' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=0 status=active\n"
."  `- 0:2:0:0 sda 8:0   active undef running\n",


#18. RedHat 4 sample, (thanks to Sébastien Maury)
"MYVOLUME (36005076801810523100000000000006f)\n"
."[size=576 GB][features=\"1 queue_if_no_path\"][hwhandler=\"0\"]\n"
."\\_ round-robin 0 [active]\n"
." \\_ 13:0:1:0  sdc 8:32  [active]\n"
." \\_ 13:0:2:0  sdd 8:48  [active]\n"
." \\_ 13:0:3:0  sde 8:64  [active]\n"
." \\_ 13:0:4:0  sdf 8:80  [active]\n"
." \\_ 14:0:1:0  sdh 8:112 [active]\n"
." \\_ 14:0:2:0  sdi 8:128 [active]\n"
." \\_ 14:0:3:0  sdj 8:144 [active]\n"
." \\_ 14:0:4:0  sdk 8:160 [active]\n",


#19. RedHat 4 sample, modified (thanks to Sébastien Maury)
"MYVOLUME (36005076801810523100000000000006f)\n"
."[size=576 GB][features=\"1 queue_if_no_path\"][hwhandler=\"0\"]\n"
."\\_ round-robin 0 [active]\n"
." \\_ 13:0:1:0  sdc 8:32  [active]\n"
." \\_ 13:0:2:0  sdd 8:48  [active]\n"
." \\_ 13:0:3:0  sde 8:64  [failed]\n"
." \\_ 13:0:4:0  sdf 8:80  [active]\n"
." \\_ 14:0:1:0  sdh 8:112 [faulty]\n"
." \\_ 14:0:2:0  sdi 8:128 [active]\n"
." \\_ 14:0:3:0  sdj 8:144 [dadada]\n"
." \\_ 14:0:4:0  sdk 8:160 [active]\n",


#20. netapp / Debian Squeeze sample (thanks to Bernd Zeimetz)
"foobar_backup_lun0 (360a98aaaa72d444e423464685a786175) dm-1 NETAPP,LUN\n"
."size=299G features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."|-+- policy='round-robin 0' prio=8 status=active\n"
."| |- 0:0:0:0 sda 8:0   active ready running\n"
."| `- 1:0:0:0 sde 8:64  active ready running\n"
."`-+- policy='round-robin 0' prio=2 status=enabled\n"
."  |- 0:0:1:0 sdb 8:16  active ready running\n"
."  `- 1:0:1:0 sdf 8:80  active ready running\n"
."foobar_postgresql_lun0 (360a98aaaa470505a684a656930385a4a) dm-2 NETAPP,LUN\n"
."size=4.9T features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."|-+- policy='round-robin 0' prio=8 status=active\n"
."| |- 0:0:2:0 sdc 8:32  active ready running\n"
."| `- 1:0:2:0 sdg 8:96  active ready running\n"
."`-+- policy='round-robin 0' prio=2 status=enabled\n"
."  |- 0:0:3:0 sdd 8:48  active ready running\n"
."  `- 1:0:3:0 sdh 8:112 active ready running\n",


#21. netapp / Debian Squeeze failed path sample (thanks to Bernd Zeimetz)
"foobar_postgresql_lun0 (360a98aaaa470505a684a656930385a4a) dm-2 NETAPP,LUN\n"
."size=299G features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=0 status=enabled\n"
."  `- #:#:#:# - #:# active faulty running\n",

#22. "-" in LUN name (thanks to Sven Anders <s.anders@digitec.de>)
"tex-lun4 (3600000e00d0000000002161200120000) dm-7 FUJITSU ,ETERNUS_DXL\n"
."[size=1.2T][features=1 queue_if_no_path][hwhandler=0]\n"
."\\_ round-robin 0 [prio=0][active]\n"
." \\_ 7:0:1:4 sdt 65:48 [active][undef]\n"
." \\_ 2:0:1:4 sdu 65:64 [active][undef]\n"
."tex-lun3 (3600000e00d0000000002161200110000) dm-8 FUJITSU ,ETERNUS_DXL\n"
."[size=1.0T][features=1 queue_if_no_path][hwhandler=0]\n"
."\\_ round-robin 0 [prio=0][active]\n"
." \\_ 2:0:1:3 sds 65:32 [active][undef]\n"
." \\_ 7:0:1:3 sdr 65:16 [active][undef]\n",

#23. LUN without WWID (iSCSI) thanks to Ernest Beinrohr <Ernest.Beinrohr@axonpro.sk>
"1STORAGE_server_target2 dm-2 IET,VIRTUAL-DISK\n"
."size=1.0T features='0' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=0 status=active\n"
."  |- 9:0:0:1  sdc 8:32 active undef running\n"
."  `- 10:0:0:1 sdd 8:48 active undef running\n",

#24. LUN without WWID (iSCSI) thanks to Ernest Beinrohr <Ernest.Beinrohr@axonpro.sk>
"1STORAGE_server_target2 dm-2 IET,VIRTUAL-DISK\n"
."size=1.0T features='0' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=1 status=active\n"
."  |- 9:0:0:1  sdc 8:32 active ready  running\n"
."  `- 10:0:0:1 sdd 8:48 failed faulty running\n",

#25. Old Debian Lenny example (edited) thanks to Benjamin von Mossner <benjamin.von.mossner@insparx.com>
"360a98000503361754b5a58724f6f7a59dm-2 NETAPP  ,LUN\n"
."size=450G features='1 queue_if_no_path' hwhandler='1 emc' wp=rw\n"
."|-+- policy='round-robin 0' prio=0 status=active\n"
."| |- 2:0:0:1 sdi 8:128 active undef running\n"
."| `- 1:0:0:1 sdc 8:32  active undef running\n"
."`-+- policy='round-robin 0' prio=0 status=enabled\n"
."  |- 1:0:1:1 sdf 8:80  active undef running\n"
."  `- 2:0:1:1 sdl 8:176 active undef running\n",

#26. thanks to Ben Evans <Ben.Evans@terascala.com>
"map00 (36d4ae52000a2666a0000083751e90c16) dm-1 DELL,MD32xx\n"
."size=9.1T features='2 pg_init_retries 50' hwhandler='1 rdac' wp=rw\n"
."|-+- policy='round-robin 0' prio=0 status=active\n"
."| `- 1:0:0:0 sdb 8:16  active undef running\n"
."`-+- policy='round-robin 0' prio=0 status=enabled\n"
."  `- 2:0:0:0 sdf 8:80  active failed running\n",

#27. thanks to Ben Evans <Ben.Evans@terascala.com>
"map00 (36d4ae52000a2666a0000083751e90c16) dm-1 DELL,MD32xx\n"
."size=9.1T features='2 pg_init_retries 50' hwhandler='1 rdac' wp=rw\n"
."|-+- policy='round-robin 0' prio=0 status=active\n"
."| `- 1:0:0:0 sdb 8:16  active undef running\n"
."`-+- policy='round-robin 0' prio=0 status=enabled\n"
."  `- #:#:#:# - #:#  active undef running\n",

#28. thanks to Michal Svamberg <svamberg@civ.zcu.cz>
"fc-p6-vicepb (1Proware_FF010000333001EC) dm-1 Proware,R_laila\n"
."size=4.8T features='0' hwhandler='0' wp=rw\n"
."|-+- policy='round-robin 0' prio=1 status=active\n"
."| `- 9:0:1:0 sdd 8:48  active ready running\n"
."|-+- policy='round-robin 0' prio=1 status=enabled\n"
."| `- 9:0:0:0 sdc 8:32  active ready running\n"
."|-+- policy='round-robin 0' prio=1 status=enabled\n"
."| `- 9:0:2:0 sde 8:64  active ready running\n"
."`-+- policy='round-robin 0' prio=1 status=enabled\n"
."  `- 9:0:5:0 sdh 8:112 active ready running",

#29. more errors (edited)
"mpathb (36000d7700000c5780d68e963a7d30695) dm-1 FALCON,IPSTOR DISK\n"
."size=1.9T features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."`-+- policy='service-time 0' prio=1 status=active\n"
."  |- 7:0:0:1 sdd 8:48  active ready  running\n"
."  |- 7:0:1:1 sdg 8:96  active ready  running\n"
."  |- 8:0:0:1 sdj 8:144 failed faulty offline\n"
."  `- 8:0:1:1 sdm 8:192 active ready  running\n"
."mpatha (36000d77e0000c9f549b7b04ab12f4f29) dm-0 FALCON,IPSTOR DISK\n"
."size=1.9T features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."`-+- policy='service-time 0' prio=1 status=active\n"
."  |- 7:0:0:0 sdc 8:32  active shaky  running\n"
."  |- 7:0:1:0 sdf 8:80  active ready  running\n"
."  |- 8:0:0:0 sdi 8:128 failed faulty offline\n"
."  `- 8:0:1:0 sdl 8:176 active ready  running\n",

#30. thanks to Andreas Steinel <Andreas.Steinel@exirius.de>
"sddv: checker msg is \"tur checker reports path is down\"\n"
."mpatha (3aaaabbbbccccddddeeeeffff00001111) dm-16 DGC,VRAID\n"
."[size=300G][features=1 queue_if_no_path][hwhandler=1 alua][rw]\n"
."\\_ round-robin 0 [prio=100][active]\n"
." \\_ 2:0:2:10 sdao 66:128  [active][ready] \n"
." \\_ 1:0:2:10 sddk 71:32   [active][ready] \n"
."\\_ round-robin 0 [prio=10][enabled]\n"
." \\_ 2:0:3:10 sdaz 67:48   [active][ready] \n"
."\\_ round-robin 0 [prio=0][enabled]\n"
." \\_ 1:0:3:10 sddv 71:208  [active][faulty]\n",

#31. thanks to Robert Towster
"3600507606700440c1d0bba930b81dd65 dm-1 IBM,ServeRAID M1210e\n"
."size=185G features='0' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=1 status=active\n"
."  `- 2:2:0:0  sdaa 65:160 active ready running\n"
."360050768018106d97800000000000134 dm-13 IBM,2145\n"
."size=200G features='1 queue_if_no_path' hwhandler='0' wp=rw\n"
."|-+- policy='round-robin 0' prio=50 status=active\n"
."| |- 0:0:2:11 sdt  65:48  active ready running\n"
."| `- 1:0:2:11 sdau 66:224 active ready running\n"
."`-+- policy='round-robin 0' prio=10 status=enabled\n"
."  |- 0:0:3:11 sdz  65:144 active ready running\n"
."  `- 1:0:3:11 sdba 67:64  active ready running\n",

#32. thanks to Séverin Launiau
"3600a098038303039492b473242384661 dm-19 NETAPP  ,LUN C-Mode\n"
."size=5.0T features='4 queue_if_no_path pg_init_retries 50 retain_attached_hw_handle' hwhandler='1 alua' wp=rw\n"
."|-+- policy='service-time 0' prio=50 status=active\n"
."| `- 7:0:0:0  sdb 8:16  active ready running\n"
."`-+- policy='service-time 0' prio=10 status=enabled\n"
."  `- 11:0:0:0 sdg 8:96  active ready running\n"
."360a98000375432714a3f336733636843 dm-3 NETAPP  ,LUN\n"
."size=10T features='4 queue_if_no_path pg_init_retries 50 retain_attached_hw_handle' hwhandler='0' wp=rw\n"
."`-+- policy='service-time 0' prio=2 status=active\n"
."  |- 8:0:0:0  sdd 8:48  active ready running\n"
."  |- 9:0:0:0  sde 8:64  active ready running\n"
."  |- 10:0:0:0 sdf 8:80  active ready running\n"
."  `- 12:0:0:0 sdi 8:128 active ready running\n"
."3600a098038303039365d4671616a756e dm-2 NETAPP  ,LUN C-Mode\n"
."size=150G features='4 queue_if_no_path pg_init_retries 50 retain_attached_hw_handle' hwhandler='1 alua' wp=rw\n"
."|-+- policy='service-time 0' prio=50 status=active\n"
."| `- 11:0:0:1 sdh 8:112 active ready running\n"
."`-+- policy='service-time 0' prio=10 status=enabled\n"
."  `- 7:0:0:1  sdc 8:32  active ready running\n",

#33. thanks to Ivan Zikyamov
"u00.2 (360002ac000000000000000400000adfc) dm-6 3PARdata,VV\n"
."size=34G features='1 queue_if_no_path' hwhandler='1 alua' wp=rw\n"
."`-+- policy='round-robin 0' prio=50 status=active\n"
."  |- 2:0:6:10 sdep 129:16  active ready running\n"
."  |- 1:0:6:10 sddo 71:96   active ready running\n"
."  |- 2:0:9:10 sdgr 132:112 active ready running\n"
."  `- 1:0:9:10 sdfq 130:192 active ready running\n",

#34. Lun name character test
"TEST+-_.{~}_TEST (360002ac000000000000000400000adfc) dm-6 3PARdata,VV\n"
."size=34G features='1 queue_if_no_path' hwhandler='1 alua' wp=rw\n"
."`-+- policy='round-robin 0' prio=50 status=active\n"
."  |- 2:0:6:10 sdep 129:16  active ready running\n"
."  |- 1:0:6:10 sddo 71:96   active ready running\n"
."  |- 2:0:9:10 sdgr 132:112 active ready running\n"
."  `- 1:0:9:10 sdfq 130:192 active ready running\n",


#35. Local NVMe drive (multipath configuration error)   thanks to: Jeffrey Honig <jeffrey.honig@xandr.com>
"eui.354358304e6107500025384100000004 [nvme]:nvme0n1 NVMe,Dell Express Flash PM1725b 3.2TB SFF,1.2.1   \n"
."size=6251233968 features='n/a' hwhandler='n/a' wp=rw\n"
."`-+- policy='n/a' prio=n/a status=n/a\n"
."  `- 0:33:1   nvme0c33n1 0:0   n/a   n/a   live   \n",

#36. NVMe drive  thanks to: Paul Garn <paul.garn@hpe.com>
"mpathq (eui.62326136306365612d636434382d3430) dm-32 NVME,PVL-MX18S0P2L2C1-F100TP0TY1\n"          
."size=43T features='3 queue_if_no_path pg_init_retries 50' hwhandler='0' wp=rw\n"
."|-+- policy='service-time 0' prio=50 status=active\n"
."| `- 22:8209:1:1   nvme22n1  259:33  active ready running\n"
."`-+- policy='service-time 0' prio=1 status=enabled\n"
."  `- 23:12293:1:1  nvme23n1  259:35  active ready running\n",

#37. NVMe drive  thanks to: Paul Garn <paul.garn@hpe.com>
"mpathdz (eui.62303566643065632d336666332d3434) dm-297 NVME,PVL-MX18S0P2L2C1-F100TP0TY1  \n"           
."size=43T features='3 queue_if_no_path pg_init_retries 50' hwhandler='0' wp=rw\n"
."|-+- policy='service-time 0' prio=50 status=active\n"
."| `- 289:19:1:1    nvme289n1 259:433 active ready running\n"
."`-+- policy='service-time 0' prio=1 status=enabled\n"
."  `- 288:4115:1:1  nvme288n1 259:432 active ready running\n",


#38. Messages from multipath call, thanks to Philip Morales 
# added dummy wwid to: "lun-name (xxxx) dm-6 NETAPP  ,LUN C-Mode\n"
"lun-name (3600a098038303039492b473242384661) dm-6 NETAPP  ,LUN C-Mode\n"
."size=400G features='3 pg_init_retries 50 retain_attached_hw_handler' hwhandler='1 alua' wp=rw\n"
."|-+- policy='service-time 0' prio=50 status=active\n"
."| |- 1:0:1:0 sdb 8:16  active ready running\n"
."| |- 1:0:2:0 sdd 8:48  active ready running\n"
."| |- 2:0:2:0 sde 8:64  active ready running\n"
."| `- 2:0:4:0 sdg 8:96  active ready running\n"
."`-+- policy='service-time 0' prio=10 status=enabled\n"
."  |- 1:0:5:0 sdf 8:80  active ready running\n"
."  |- 1:0:7:0 sdh 8:112 active ready running\n"
."  |- 2:0:1:0 sdc 8:32  active ready running\n"
."  `- 2:0:5:0 sdi 8:128 active ready running\n"
."Apr 08 09:21:04 | multipath device maps are present, but 'multipathd' service is not running\n"
."Apr 08 09:21:04 | IO failover/failback will not work without 'multipathd' service running\n"

    );


# Commands with full path
$SUDO                = '/usr/bin/sudo';


# check path for multipath command
my $multipathCmd = '/usr/sbin/multipath';
if (! -e $multipathCmd ) {
    $multipathCmd = '/sbin/multipath';
    if ( ! -e $multipathCmd ) {
	$multipathCmd = '';
    } # if
} # if

# commands with options
$MULTIPATH_LIST_LONG = $multipathCmd.' -ll';
$MULTIPATH_LIST      = $multipathCmd.' -l';
$MULTIPATH_RELOAD    = $multipathCmd.' -r';


# Exit codes
$E_OK       = 0;
$E_WARNING  = 1;
$E_CRITICAL = 2;
$E_UNKNOWN  = 3;

# Nagios error levels reversed
%reverse_exitcode
  = (
     0 => 'OK',
     1 => 'WARNING',
     2 => 'CRITICAL',
     3 => 'UNKNOWN',
    );


# Translate text exit codes to values
%text2exit
  = ( 'ok'       => $E_OK,
      'warning'  => $E_WARNING,
      'critical' => $E_CRITICAL,
      'unknown'  => $E_UNKNOWN,
    );


# Usage text
$USAGE = <<"END_USAGE";

Usage: $NAME [OPTIONS]
END_USAGE

# Help text
$HELP = <<"END_HELP";

check-multipath.pl - Nagios plugin to check multipath connections  $VERSION
see:
 http://exchange.nagios.org/directory/Plugins/Operating-Systems/Linux/check-2Dmultipath-2Epl/details
 http://www.nagios.org/documentation

The number of parameters and options has increased over the time, as a result of feature requests by users. 
You might not need most of them.

A configuration for a specific LUN name via --extraconfig has highest priority and overrides group and global config.
If a regex defined in --group matches a LUN line the specified group values are used. (First regex in List, checked from left to right)
Otherwise the global defaults are used (--min-paths, --ok-paths).

OPTIONS:
  -m, --min-paths     Low mark,  less paths per LUN are CRITICAL   [2]
  -o, --ok-paths      High mark, less paths per LUN raise WARNING  [4]
  -n, --no-multipath  Exitcode for no LUNs, no multipath driver and multipathd not running  [warning]
  -M, --mdskip        Skip extra check if multipathd is running (check uses '--no-multipath' returncode)

  -a, --addchecks     define low/high marks for additional checks
                        number of policies   per LUN   p,<LOW>,<HIGH>  DEFAULT: p,0,0
                        number of scsi-hosts per LUN  sh,<LOW>,<HIGH>  DEFAULT: sh,0,0
                        number of scsi-ids,  per LUN  si,<LOW>,<HIGH>  DEFAULT: si,0,0
                      e.g. 'p,1,2,sh,1,2';  'si,1,2,p,1,2,sh,2,4';  'p,1,2'
                      See documentation of multipath output. If the HIGH value is 0, the check is skipped.
                      A typical standard-configuration uses 2 scsi-hosts and 2 scsi-ids, resulting in four paths
                      representing all possible combinations: h0-i0, h0-i1, h1-i0, h1-i1. 

 --scsi-all           Count all scsi-hosts and scsi-ids, even from paths that report an error state. 

  -r, --reload        force devmap reload if status is WARNING or CRITICAL
                      (multipath -r)
                      Can help to pick up LUNs coming back to life.

  -L, --ll            use multipath -ll instead of multipath -l
                      Can improve detection of failed paths with older versions of multipath tools


  -l, --linebreak     Define end-of-line string:
                      REG      regular UNIX-Newline
                      HTML     <br/>
                      -other-  use specified string as linebreak symbol, 
                               e.g. ', ' (all in one line, comma seperated)

  -g, --group         Specify perl-regex to identify groups of LUNs with other default-thresholds.
                      Overrides global config for LUNs with LUN lines that math a group regex.
                      In most cases a simple String should be sufficient. NOTE: special regex characters must be escaped!
                      "<LUN_LINE_REGEX>,<LOW>,<HIGH>[\@#,<ADDCHECKS>]:"  for each group with deviant thresholds (see explanation of --addchecks)
                      e.g.  "IBM,ServeRAID,1,1:HAL,ChpRAID,1,2:"  or "IBM,ServeRAID,1,1\@#,p,1,2:HAL,ChpRAID,1,2\@#,sh,1,2,si,1,2:"
                      Use command multipath -l to see the LUN lines and to identify groups.

  -e, --extraconfig   Specify different low/high thresholds for LUNs.
                      Overrides group and global config for the specified LUNs.
                      optional: specify return code if no data for LUN selector was found 
                                (ok, warning, critical), default is warning
                                the return code MAY be followed by definitions of additional check, see explanation of --addchecks above
                      "<LUN-selector>,<LOW>,<HIGH>[,<RETURNCODE>[,<ADDCHECKS>]]:"  for each LUN with deviant thresholds
                      e.g.  "iscsi_lun_01,2,2:dummyLun,1,1,ok:paranoid_lun,8,16,critical:"
                            "oddLun,3,5:"
                            "paranoidOddLun,5,11,critical,p,3,5,sh,5,9,si,3,7:"
                            "default,2,4,warning:DonalLunny,6,8,warning,sh,1,4,si,1,4:" 

                      <LUN-selector> is by default checked against the "generic Name", as used in older plugin versions. 
                      You can specify a prefix to select a LUN attribute as identifier. 
                      Not all attributes may be available, depending on the specific multipath configuration.
                      Use command multipath -l to see the complete LUN lines.
                        "G!" generic name, as used in older versions. Exists always. Content depends on the specific configuration. DEFAULT
                        "W!" WWID as reported by the multipath command
                        "D!" dm Identifier (dm-3 or similar)
                        "N!" user-firendly name 
                      e.g. 'W!36000d774000045f655ea91cb4ea41d6f,4,8,critical:DonalLunny,6,8:D!dm-3,1,2,warning,sh,1,2,si,1,2:'
                      NOTE: enclose parameter value in SINGLE-quotes for this notation!

  -p, --print         List to determine which attribute of the LUN should be printed as identifier in the output
                      The letters in the list are checked from left to right, the first coresponding attribute that exists is printed. 
                      The letter G is always appended to the list.
                      Avalible are:
                        G: generic name, as used in older versions. Exists always. Content depends on the specific configuration.
                        W: WWID as reported by the multipath command
                        D: dm Identifier (dm-3 or similar)
                        N: user-firendly name 
                      e.g. "DN":  print dm-identifier (if present), else user friendly name (if present) else generic name (as G is always appended to the list) 
                           "WDN": print WWID (if present), else print dm-identifier (if present), else user friendly name (if present) else generic name (as G ist always appended to the list)  

  -s, --state         Prefix alerts with alert state
  -S, --short-state   Prefix alerts with alert state abbreviated
  -h, --help          Display this help text
  -V, --version       Display version info
  -v, --verbose       More text output

  -d, --di            Run testcase instead of real check           [0]
  -t, --test          Do not display testcase input, just result

  -h, --help          Display this message


NOTE: 
- 'sudo' MUST be configured to allow the nagios-user to call multipath -l and/or multipath -ll if you use the -ll option
  (and also multipath -r, if you intend to use the --reload option) *without* password.
- Local drives SHOULD NOT be handled by the multipth driver. They SHOULD be excluded in the multipath configuration!
  RTFM; (e.g. add wwid to blacklist in /etc/multipath.conf and reboot)
- Error messages from multipath call should be reported as WARNING, with 'MP-MSG ' as prefix.
  Still, some error messages can lead to 'line not recognised' error messages from the plugin. 
  So, in case of 'line not recognised' errors always check  multipath -l  and  multipath -ll

END_HELP

# Version and license text
$LICENSE = <<"END_LICENSE";

$NAME   $VERSION

Copyright (C) 2011-2022 $AUTHOR
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by
$AUTHOR <$CONTACT>

Thanks for contributions to
Bernd Zeimetz, Sven Anders, Ben Evans and others

Based on work by 
- Trond H. Amundsen <t.h.amundsen\@usit.uio.no>
- Gunther Schlegel  <schlegel\@riege.com>
- Matija Nalis      <mnalis+debian\@carnet.hr>
END_LICENSE


# Options with default values
%opt
  = ( #'timeout'       => 5,  # default timeout is 5 seconds
      'help'          => 0,
      'version'       => 0,
      'no_multipath'  => 'warning',
      'min-paths'     => 2,
      'ok-paths'      => 4,
      'state'         => 0,
      'di'            => 0,
      'shortstate'    => 0,
      'linebreak'     => undef,
      'extraconfig'   => '',
      'verbose'       => 0,
      'test'          => 0, 
      'reload'        => 0, 
      'll'            => 0, 
      'mdskip'        => 0,
      'group'         => '',
      'print'         => '',
      'scsi-all'      => 0,
      'addchecks'     => '',
    );


# the hash keys define the valid check identifiers. only  \w  characters for IDs!
# Initialize the hash with defaults (no checks)
my %addChecks 
 = (
    'sh' => [0,0],      # scsi-hosts
    'si' => [0,0],      # scsi-ids
    'p'  => [0,0],      # policies
    );

# short human readable description
my %addCheckNames
 = (
    'sh' => 'scsi-hosts',
    'si' => 'scsi-ids',
    'p'  => 'policies',
    );


# Get options
GetOptions(#'t|timeout=i'      => \$opt{timeout},
	   'h|help'           => \$opt{'help'},
	   'V|version'        => \$opt{'version'},
	   'n|no-multipath=s' => \$opt{'no_multipath'},
           'm|min-paths=i'    => \$opt{"min-paths"},
           'o|ok-paths=i'     => \$opt{"ok-paths"},
           'd|di=i'           => \$opt{"di"},
	   's|state'          => \$opt{'state'},
	   'S|short-state'    => \$opt{'shortstate'},
	   'l|linebreak=s'    => \$opt{'linebreak'},
	   'e|extraconfig=s'  => \$opt{'extraconfig'},
	   'v|verbose'        => \$opt{'verbose'},
	   't|test'           => \$opt{'test'},
	   'r|reload'         => \$opt{'reload'},
	   'L|ll'             => \$opt{'ll'},
	   'M|mdskip'         => \$opt{'mdskip'},
	   'g|group=s'        => \$opt{'group'},
	   'p|print=s'        => \$opt{'print'},
	   'scsi-all'         => \$opt{'scsi-all'},
	   'a|addchecks=s'    => \$opt{'addchecks'},
	  ) or do { print $USAGE; exit $E_UNKNOWN };

# If user requested help
if ($opt{'help'}) {
    print $USAGE, $HELP;
    exit $E_OK;
}

# If user requested version info
if ($opt{'version'}) {
    print $LICENSE;
    exit $E_OK;
}

# Reports (messages) are gathered in this array
@reports = ();

#
# DOES NOT WORK when calling commands with  qx()
#
# Setting timeout
#$SIG{ALRM} = sub {
#    print "PLUGIN TIMEOUT: $NAME timed out after $opt{timeout} seconds\n";
#    exit $E_UNKNOWN;
#};
#alarm $opt{timeout};



#---------------------------------------
#
# Initialise a hash with current addcheck defaults
# copy the arrays, not just the references!
#
sub getNewAddCheckHash {
    my %h;

    foreach my $k (keys %addChecks) {
	#print "getNewAddCheckHash : '$k'\n";
	my @arr = @{$addChecks{$k}};
	$h{$k}= \@arr;
    } # foreach

    return \%h;
} # sub


#---------------------------------------
#
# analyse definition of additional checks, write check-values to referenced hash
#
sub getAddChecks {
    my ($inString, $rOuthash, $errPrefix) = @_;
    
    if ( !defined($inString) ) {         # undefined or empty means no change
	return;
    } elsif ($inString eq '') { 
	return;
    } # if

    if ( !defined($errPrefix) ) {        # errorPrefix should give information about the call context
	$errPrefix = '';
    } # if

    if ($inString !~ m!^\w+,\d+,\d+(,\w+,\d+,\d+)*$! ) {
	unknown_error($errPrefix."invalid addcheck definition: '$inString', syntax error. See help information.");
    } # if
    
    while ($inString =~ m!(\w+),(\d+),(\d+)!g) {
	my ( $id, $low, $high ) = ($1, $2, $3); 
	#print "AddCheck: id='$id', low='$low', high='$high', errprefix='$errPrefix'\n";

	if ( defined($$rOuthash{$id}) ) {            # hash keys define valid ids
	    if ( $low <= $high ) {                   # make sure low and high value are in the right order
		@{$$rOuthash{$id}} = ($low, $high);  # only set values found in input string, leave the others untouched
	    } else {
		unknown_error($errPrefix."invalid addcheck definition for id '$id', low value bigger than high value. See help information.");
	    } # if
	} else {
	    unknown_error($errPrefix."invalid addcheck identifier '$id' in '$inString', syntax error. See help information.");
	} # if
    } # while
} # sub

#---------------------------------------



# Default line break
$linebreak = isatty(*STDOUT) ? "\n" : '<br/>';


# Line break from option
if (defined $opt{linebreak}) {
    if ($opt{linebreak} eq 'REG') {
	$linebreak = "\n";
    }
    elsif ($opt{linebreak} eq 'HTML') {
	$linebreak = '<br/>';
    }
    else {
	$linebreak = $opt{linebreak};
    }
} # if

# Analyse additional check definitions. Parameter sets defaults
# exit on Error
getAddChecks( $opt{'addchecks'}, \%addChecks, "Parameter '--addchecks'; " );


# group option
my @group = ();

#print "--group='".$opt{'group'}."'\n";
if ($opt{'group'} ne '') {
    if ( $opt{'group'} !~ m!^(.+?,\d+,\d+(?:@#(,\w+,\d+,\d+)*)?:)+$! ) {
	unknown_error("Wrong usage of '--group' option: '"
		      . $opt{'group'}
		      . "' syntax error. See help information.");
    } # if

    while ( $opt{'group'} =~ m/(.+?),(\d+),(\d+)(?:@#,([\w\d,]+))?:/g ) {
	my $regex     = $1;
	my $crit      = $2;
	my $warn      = $3;
	my $addchecks = $4;
	if ( !defined($addchecks) ) {
	    $addchecks = '';
	} # if
	#print "GROUP: Regex='$regex', c=$crit, w=$warn, addchecks='$addchecks'\n";

	if ($crit > $warn) {
	    unknown_error("Error in '--group' option '"
			  . $opt{'group'}
			  . "' for group rule '$regex': critical threshold ($crit) must not be higher than warning threshold ($warn).");
	} # if

	my $rHash = getNewAddCheckHash();              # initialise with default
	getAddChecks( $addchecks, $rHash, "Parameter '--group'; " );
	push ( @group, { 'regex' => $regex, 'warn' => $warn, 'crit' => $crit, 'addchecks' => $rHash } );
    } # while 
} # if


# print option
$opt{'print'} .= 'G';                  # last resort: "generic name" (always present) als default
if  ($opt{'print'} !~ m!^[GWND]+$!) {
    unknown_error("Error in '--print' option: invalid character in value '". $opt{'print'} ."'. Please check usage.");
} # if


# extraconfig option
my @extraconfig = ();

if ($opt{extraconfig} ne '') {
    # regular expression that defines ONE entry in option string
    my $rx = '(?:([GWDN])!)?([\w\-]+),(\d+),(\d+)(?:,(ok|warning|critical)(?:,([\w\d,]+))?)?:+';

   if ( $opt{extraconfig} !~ m/^($rx)+$/ ) {                       # use defined regex to check; improved bugfix (thanks to Jeffrey Honig <jeffrey.honig@xandr.com>)
	unknown_error("Wrong usage of '--extraconfig' option: '". $opt{extraconfig} ."' syntax error. See help information.");
    } # if

    #print "EXTRA-Param '$opt{extraconfig}'\n";
    #while ( $opt{extraconfig} =~ m/(?:([GWDN])!)?([\w\-]+),(\d+),(\d+)(?:,(ok|warning|critical)(?:,([\w\d,]+))?)?:+/g ) {
    while ( $opt{extraconfig} =~ m/$rx/g ) {                       # use defined regex for consistancy(!)
        my $attribute   = $1;
	my $attribValue = $2;
	my $crit        = $3;
	my $warn        = $4;
	my $ret         = $5;
	my $addchecks   = $6;
        my $missingRet  = $E_WARNING;                               # set default
	
	if ( defined($ret) ) {                                      # if retcode is given: convert and store
	    $missingRet=$text2exit{$ret};
	} else {
	    $ret = '#UNDEF#';
	} # if
	if ( !defined($addchecks) ) {
	    $addchecks = '';
	} # if
	if ( !defined($attribute) ) {
	    $attribute = 'G';                                       # DEFAULT: generic Name
	} # if

	#print "EXTRA: attrib='$attribute', val='$attribValue', c=$crit, w=$warn, m=$missingRet, '$ret', addchecks='$addchecks'\n";

	if ($crit > $warn) {
	    unknown_error("Error in '--extraconfig' option '"
			  . $opt{extraconfig}
			  . "' for LUN selector '".$attribute.'!'.$attribValue."': critical threshold ($crit) must not be higher than warning threshold ($warn).");
	} # if

	my $rHash = getNewAddCheckHash ();             # initialise with default
	getAddChecks( $addchecks, $rHash, "Parameter '--extraconfig'; " );
	push ( @extraconfig, {'attrib' => $attribute, 'val' =>$attribValue, 'warn' => $warn, 'crit' => $crit, 'missingRet' => $missingRet, 'addchecks' => $rHash, 'found' => 0 });
    } # while 
} # if



# Check syntax of '--no-multipath' option
if (!exists $text2exit{$opt{no_multipath}}) {
    unknown_error("Wrong usage of '--no-multipath' option: '"
		  . $opt{no_multipath}
		  . "' is not a recognized keyword");
}

# Check min-paths option
if ( $opt{"min-paths"} < 1 ) {
    unknown_error("Wrong usage of '--min-paths' option: '"
		  . $opt{"min-paths"}
		  . "' (must be at least 1)");
}

# Check ok-paths option
if ( $opt{"ok-paths"} < $opt{"min-paths"} ) {
    unknown_error("Wrong usage of '--ok-paths' option: '"
		  . $opt{"ok-paths"}
		  . "' (must NOT be less than '--min-paths': "
		  . $opt{"min-paths"}
	          . ")") ;
}

# Check di (Debug-Input)  option
if ( $opt{"di"} > $#debugInput ) {
    unknown_error("Wrong usage of '--di' option: '"
		  . $opt{"di"}
		  . "' (must NOT be bigger than: "
		  . $#debugInput
	          . ")") ;
}


#---------------------------------------------------------------------
# Functions
#---------------------------------------------------------------------

#---------------------------------------
#
# Store a message in the message array
#
sub report {
    my ($msg, $exval) = @_;
    return push @reports, [ $msg, $exval ];
}

#---------------------------------------
#
# Give an error and exit with unknown state
#
sub unknown_error {
    my $msg = shift;
		
    if ($opt{"test"}) {
	print "ERROR: $msg |TESTCASE|\n";
    } else {
	my $hostname = qx('hostname');           # add hostname to error message
	chomp $hostname;
	print "ERROR: $msg |Host: $hostname|\n";
    }
    exit $E_UNKNOWN;
}

#---------------------------------------
#
# get attribute to print from LUN data
#
sub getLunPrintName {
    my ( $rLunDef ) = @_;

    my $lunPrintName = 'UNDEF';
    my $displayPrio   = $opt{'print'};
    for(my $i = 0; $i < length($displayPrio); $i++) {  # all characters in prio-string
	my $c = substr ($displayPrio, $i, 1);
	#print "i=$i, c='$c'\n";
	if ($$rLunDef{$c}) {                          # first non-empty attribute wins
	    $lunPrintName = $$rLunDef{$c};
	    #print "FOUND: $lunPrintName i=$i, c='$c'\n";
	    last;
	} # if
    } # for

    return $lunPrintName;
} # sub


#---------------------------------------
#
# get output of multipath -l
# or debug input (testcase)
#
sub get_multipath_text {
    my ( $cmd ) = @_;

    if ( !defined($cmd) || $cmd !~ m!^/\w+! ) {
	unknown_error ("INVALID system command '$cmd' specified.");
    }
    my $cmdFull = $cmd.' 2>/dev/null';                            # ignore error output

    my $output = "";
    
    if ( ! $opt{"di"} ) {                                         # normal action, NO debug input
	#print "Reale USER-ID : $< Effektive USER-ID : $>\n";
	#print getpwuid( $< )."\n";
	my $command = "";
	if ($< == 0 ) {                                           # called by root?
	    $command = $cmdFull;                                  # use command "as is"
	} else {
	    $command = "$SUDO $cmdFull";                          # otherwise: use sudo
	}
	#print "exec [$command]\n";

	$output = qx($command);
        my $err = $!;
	if ($? != 0) {

	    # if no multipath driver found just set empty string (no LUNs)
	    if ( $output =~ m/multipath kernel driver not loaded/ ) {
		$output = "";
	    } else {
		if ($< != 0) {
		    # (root) NOPASSWD: /sbin/multipath -l
		    # (root) NOPASSWD: /sbin/multipath -ll
		    # (root) NOPASSWD: /sbin/multipath -r
		    my $sudoListCommand = "$SUDO -l 2>/dev/null";
		    my $sudoList = qx($sudoListCommand);
		    if ($sudoList !~ m!\(root\) \s+ NOPASSWD\: \s+ $cmd!x ) {
			unknown_error ("Command failed, 'sudo' not configured for command: '$cmd'?" );
		    } # if
		} # if 

		unknown_error ("command '$command' FAILED: '$output', '$err'");
	    }
	}
	#print "-----\ndi=". $opt{"di"} ."\n-----\n[". $output ."]\n-----\n\n";
    } else {                                                      # TESTCASE
	$output = $debugInput[$opt{"di"}];
	if (!$opt{"test"} ) {
	    print "=====\nTESTCASE di=". $opt{"di"} ."\n-----\n". $output ."=====\n";
	} # if
    }

    $output =~ s/[\[\]\\]+/ /g;                                   # substitute special characters with space
    my @textArray = split (/[\n\r]+/, $output);                   # Array of text lines
    return \@textArray;
}


#---------------------------------------
#
# check if text is a LUN description line
# if so, set variables for new LUN
#
sub checkLunLine {
    my ($textLine, $rCurrentLun, $rLunData) = @_;
    #print "checkLunLine: '$textLine'\n";

    my $idGeneric = '';
    my $idWWID    = '';
    my $idDm      = '';
    my $idName    = '';

    # mpathb (36000d774000045f655ea91cb4ea41d6f) dm-1 FALCON,IPSTOR DISK
    # mpathb (36000d774000045f655ea91cb4ea41d6f) dm-1 
    # MYVOLUME (36005076801810523100000000000006f)
    # tex-lun4 (3600000e00d0000000002161200120000) dm-7 FUJITSU ,ETERNUS_DXL
    # fc-p6-vicepb (1Proware_FF010000333001EC) dm-1 Proware,R_laila            thanks to Michal Svamberg
    # u00.2 (360002ac000000000000000400000adfc) dm-6 3PARdata,VV               thanks to Ivan Zikyamov
    # TEST+-_.{~}_TEST (360002ac000000000000000400000adfc) dm-6 3PARdata,VV    generic test
    # mpathq (eui.62326136306365612d636434382d3430) dm-32 NVME,PVL-MX18S0P2L2C1-F100TP0TY1
    #if ($textLine =~ m/^([\w\-]+) \s+ \([\w\-]+\)/x) {
    #if ($textLine =~ m/^([\w\-]+) \s+ \(([\w\-]+)\) (?: \s+ ([\w\-]+))?/x) {
    #if ($textLine =~ m/^([\w\-\.\{\}\+~]+) \s+ \(([\w\-]+)\) (?: \s+ ([\w\-]+))?/x) {
    if ($textLine =~ m/^([\w\-\.\{\}\+~]+) \s+ \((?: [a-zA-Z]+ [\.:;,])?([\w\-]+)\) (?: \s+ ([\w\-]+))?/x) {
	$$rCurrentLun = $1;
	$idGeneric    = $1;
	$idName       = $1;
	$idWWID       = $2;
	$idDm         = $3;
	
	if ( !defined($idDm) ) {
	    $idDm ='';
	}
	#report("named LUN $$rCurrentLun found, G='$idGeneric', W='$idWWID', D='$idDm', N='$idName'", $E_OK);
    } 
    # 36006016019e02a00d009495ddbf3e011 dm-2 DGC,VRAID
    # 360a98000503361754b5a58724f6f7a59 dm-2 NETAPP  ,LUN
    # 360a98000503361754b5a58724f6f7a59 dm-2 NETAPP  ,LUN C-Mode
    # eui.354358304e6107500025384100000004 [nvme]:nvme0n1 NVMe,Dell Express Flash PM1725b 3.2TB SFF,1.2.1    thanks to Jeffrey Honig <jeffrey.honig@xandr.com>
    # eui.354358304e6107500025384100000004  nvme :nvme0n1 NVMe,Dell Express Flash PM1725b 3.2TB SFF,1.2.1    above, after input processing!
    #elsif ($textLine =~ m/^[0-9a-fA-F]+ \s+ ([\w\-\_]+)/x) {
    #elsif ($textLine =~ m/^([0-9a-fA-F]+) \s+ ([\w\-\_]+)/x) {
    elsif ($textLine =~ m/^(?:[a-zA-Z]+[\.:;,])?([0-9a-fA-F]+) \s+ (?: [a-zA-Z]+ [\.:;,])?([\w\-\_]+)/x) {  
	$$rCurrentLun = $2;
	$idGeneric    = $2;
	$idWWID       = $1;
	$idDm         = $2;
	#report("simple (1) LUN $$rCurrentLun found, G='$idGeneric', W='$idWWID', D='$idDm', N='$idName'", $E_OK); # <<<<<<<
    } 
    # 360a98000503361754b5a58724f6f7a59dm-2 NETAPP  ,LUN
    #elsif ($textLine =~ m/^[0-9a-fA-F]{3,33} \s* ([\w\-\_]+) \s+/x) {    
    #elsif ($textLine =~ m/^([0-9a-fA-F]{33}) ([\w\-]+) \s+ ([\w\-\_]+)/x) {   # add wwid-prefix part for nvme drives
    elsif ($textLine =~ m/^(?: [a-zA-Z]+ [\.:;,])?([0-9a-fA-F]{33}) ([\w\-]+) \s+ ([\w\-\_]+)/x) {
	$$rCurrentLun = $2;
	$idGeneric    = $2;
	$idWWID       = $1;
	$idDm         = $2;
	#report("simple (2) LUN $$rCurrentLun found, G='$idGeneric', W='$idWWID', D='$idDm', N='$idName'", $E_OK);
    } 
    # iscsi-LUN example
    # 1STORAGE_server_target2 dm-2 IET,VIRTUAL-DISK
    #elsif ($textLine =~ m/^([\w\-]+) \s+ [a-z]+\-\d+ \s+ [\w\-\,]+/x) {
    elsif ($textLine =~ m/^([\w\-_]+) \s+ ([\w\-]+) \s+ [\w\-\_]+/x) {
	$$rCurrentLun = $1;
	$idGeneric    = $1;
	$idName       = $1;
	$idDm         = $2;
	
	#report("LUN without WWID $$rCurrentLun found, G='$idGeneric', W='$idWWID', D='$idDm', N='$idName'", $E_OK);
    }
    else {
	return 0;   ## Not a LUN line, stop here and return zero
    } # if

    # initialise data of found LUN
    ${$rLunData}{$$rCurrentLun} = { 'paths' => 0, 'policies' => 0,
				    'lunline' => $textLine, 
				    'G' => $idGeneric, 'W' => $idWWID, 'D' => $idDm, 'N' => $idName, 
				    'sh-hash' => {}, 'si-hash' => {}
    };
    return 1;
} # sub


#---------------------------------------
#
# check if text is a policy description line
#
sub checkPolicyLine {
    my ($textLine, $currentLun, $rLunData) = @_;
    #print "checkPolicyLine: '$textLine'\n";

    # `-+- policy='round-robin 0' prio=-1 status=active
    # |-+- policy='round-robin 0' prio=0 status=active
    # `-+- policy='n/a' prio=n/a status=n/a              thanks to Jeffrey Honig <jeffrey.honig@xandr.com>
    ##\_ round-robin 0 [prio=-4][active]
    ## _ round-robin 0  prio=-4  active 
    #\_ round-robin 0 [active]
    # _ round-robin 0  active 
    # 
    #if ( $textLine =~ m/^[|\`\-\+_\s]+ \s+ (?:policy=\')?[\w\.\-\_]+ \s \d(?:\')? \s+ prio=/x ) {
    #if ( $textLine =~ m/^[|\`\-\+_\s]+ \s+ (?:policy=\')?[\w\.\-\_]+ \s \d(?:\')? \s+ \w+/x ) {
    if ( $textLine =~ m/^[|\`\-\+_\s]+ \s+ (?:policy=\')?[\w\.\-\_]+ \s \d(?:\')? \s+ \w+/x ) {
	${$$rLunData{$currentLun}}{'policies'}++;
	#print "checkPolicyLine: found policy no. ".${$$rLunData{$currentLun}}{'policies'}."\n";
	return 1;
    } elsif ( $textLine =~ m/^[|\`\-\+_\s]+ \s+ (?:policy='n\/a')? \s+ \w+/x ) {
	report("LUN ".getLunPrintName($$rLunData{$currentLun}).": policy is 'n/a'. Local drive?", $E_WARNING);
	return 1;
    } else {
	return 0;
    } # if
} # sub


#---------------------------------------
#
# analyse multipath state
# (output lines)
#
sub checkMultipathText {
    my ($rTextArray, $rCommonLunData, $rMessages) = @_;

    my $state      = "pathDesc";
    my $currentLun = "";
    my $i          = 0;

    foreach my $textLine (@$rTextArray) {
	$i++;
#	print "$i: '$textLine'\n"; # <<<<<<<<<<<<<<

	# filter log messages from multipath call and store then in an array to be handled later
	# Apr 08 09:21:04 | IO failover/failback will not work without 'multipathd' service running
	# Apr 08 09:21:04 | multipath device maps are present, but 'multipathd' service is not running
	if ($textLine =~ m!^[a-zA-Z]{3}\s+\d{2}\s+(\d{2}|\:)+?\s\|\s(.+)!) {
	    my $m = $2;
#	    print ">m> $i  '$m'\n"; # <<<<<<<<<<<<<<
	    push (@$rMessages, $m);                                   # add to messages array
	    next;                                                     # skip line
#	} else {                   # <<<<<<<<<<<<<<<
#	    print ">m> $i  NOM\n"; # <<<<<<<<<<<<<<<
	} # if

	if ($state eq 'pathDesc') {                                   # initial state: look for path state, new LUN Name, policy
	     	                                                      # check for path status line
		#  |- 3:0:0:1 sdf 8:80  active undef running 
                ## \_ 3:0:1:1 sde 8:64  [active][undef]
                ##  _ 3:0:1:1 sde 8:64   active  undef 
                ## \_ 13:0:1:0  sdc 8:32  [active]
                ##  _ 13:0:1:0  sdc 8:32   active

		#  (thanks to Bernd Zeimetz)
                #  `- #:#:#:# - #:# active faulty running

		#  (thanks to Ben Evans)
                #  `- #:#:#:# - #:#  active undef running

                #  (thanks to Jeffrey Honig <jeffrey.honig@xandr.com>)
                #  `- 0:33:1   nvme0c33n1 0:0   n/a   n/a   live

               #if ( $textLine =~ m/^[\s_\|\-\`\\\+]+ [#\d\:]+ \s+ ([\w\-]+) \s+ [#\d\:]+ \s+ \w+/xi ) { 
               #if ( $textLine =~ m/^[\s_\|\-\`\\\+]+ ([#\d]+):[#\d]+:([#\d]+):[#\d]+ \s+ ([\w\-]+) \s+ [#\d\:]+ \s+ \w+/xi ) { 
                if ( $textLine =~ m/^[\s_\|\-\`\\\+]+ ([#\d]+):[#\d]+:([#\d]+)(?::[#\d]+)? \s+ ([\w\-]+) \s+ [#\d\:]+ \s+ [\/\w+]/xi ) {
		    my $sh         = $1;
		    my $si         = $2;
		    my $pathName   = $3;
		    my $ok         = 0;
		    
		    my $rLunData   = $$rCommonLunData{$currentLun};

		    #print "pathDesc: [$textLine], ";
		    #print "LUN '$currentLun', path '$pathName', sh='$sh', si='$si'\n";

		    if ($textLine =~ m/fail|fault|offline|shaky/) {     # fail or fault, offline or shaky?
			#print "ERROR: $textLine\n";
			report("LUN ".getLunPrintName ($rLunData).", path $pathName: ERROR.", $E_WARNING);
		    } 
		    elsif ($textLine !~ m/\s(active|live)\s/) {         # path is active or live?
			#print "NOT active: $textLine\n";
			report("LUN ".getLunPrintName ($rLunData).", path $pathName: NOT active.", $E_WARNING);
		    }
		    elsif ($pathName eq "-") {                   # empty path name => path is missing (thanks to Ben Evans)
			report("LUN ".getLunPrintName ($rLunData).": missing path (empty path name)", $E_WARNING);
		    }
		    else {
			if ( $currentLun eq "") {                # YES => check logic, increase path count for LUN
			     unknown_error ("Path info before LUN name. Line $i:\n'$textLine'")
			}
			$$rLunData{'paths'}++;
			$ok =1;
		    } # if

		    
		    if ( $ok || $opt{'scsi-all'}) {              # if path is OK or ALL paths are to be counted
			if ($sh =~ m!^\d+$! ) {
			    ${$$rLunData{'sh-hash'}}{$sh}=1;     # store scsi-host as hash key
			} # if

			if ($si =~ m!^\d+$! ) {
			    ${$$rLunData{'si-hash'}}{$si}=1;     # store scsi-id as hash key
			} # if
		    } # if
		}                                                # check for new LUN name
		elsif ( checkLunLine ($textLine, \$currentLun, $rCommonLunData) ) {
		    $state="lunInfo";
		}                                                # check for new LUN name
		elsif ( ($currentLun ne "") && checkPolicyLine ($textLine, $currentLun, $rCommonLunData) ) {
		   ; # SKIP NESTED POLICY 
		} 
		elsif ( $textLine =~ m/checker msg is /) {
		    ; # SKIP tur message stuff
		}
		else {                                           # error: unknown line format
		    unknown_error ("Line $i not recognised. Expected path info, new LUN or nested policy:\n'$textLine'")
		}
            } # case

	    # after new LUN was found skip the INFO-Line (nothing else...)
	    elsif ($state eq 'lunInfo') {
		if ( $currentLun eq "" ) {                       # check logic
		    unknown_error ("No current LUN while looking for LUN info. Line $i:\n'$textLine'")
		}
		# size=2.0T features='1 queue_if_no_path' hwhandler='0' wp=rw
                ##[size=1.9T][features=1 queue_if_no_path][hwhandler=0][rw]
                ## size=1.9T  features=1 queue_if_no_path  hwhandler=0  rw 
                #[size=576 GB][features="1 queue_if_no_path"][hwhandler="0"]
                # size=576 GB  features="1 queue_if_no_path"  hwhandler="0"

               #if ($textLine =~ m/^\s*size=[\w\.]+\s+features=/x) {
                if ($textLine =~ m/^\s*size=[\w\.]+\s+ ([a-zA-Z]+\s+)? features=/x) {
		    $state = "pathPolicy";
		} else {                                         # error: unknown line format
		    unknown_error ("Line $i not recognised. Expected LUN info:\n'$textLine'")
		}
	    } # case

	    # after LUN info was found skip the path policy (nothing else...)
            # or handle new LUN if no paths available
	    elsif ($state eq 'pathPolicy') {
		if ( $currentLun eq "") {                       # check logic
		    unknown_error ("No current LUN while looking for path policy. Line $i:\'$textLine'")
		}

                if ( checkPolicyLine ($textLine, $currentLun, $rCommonLunData)) {
		    $state = "pathDesc";
		}                                               # new LUN found
		elsif ( checkLunLine ($textLine, \$currentLun, $rCommonLunData) ) {
		    $state = "lunInfo";
		} else {                                        # error: unknown line format
		    unknown_error ("Line $i not recognised. Expected path policy or new LUN:\n'$textLine'")
		}
	    }
	    else {
		unknown_error ("Internal error: unknown state '$state' of parser")
	    } # if
    } # foreach

    return 1;
} # sub



#---------------------------------------
#
# test value
#
sub testValue {
    my ($val, $low, $high, $lunPrintName, $txtErr, $txtOk) = @_;
    
    if ( !defined($txtOk) ) {
	$txtOk = '';
    } elsif ($txtOk ne '')  {
	$txtOk .= ' ';
    } #if

    #print "TEST val='$val', low='$low', high='$high', LUN='$lunPrintName', txtErr='$txtErr', txtOk='$txtOk'\n";

    if ($val < $low){
	report("LUN $lunPrintName: less than $low $txtErr ($val/$high)!", $E_CRITICAL);
    } elsif ($val < $high){
	report("LUN $lunPrintName: less than $high $txtErr ($val/$high).", $E_WARNING);
    } else {
	report("LUN $lunPrintName: $txtOk$val/$high.", $E_OK);
    } # if 
} # sub

#---------------------------------------
#
# test additional checks
#
sub testAddChecks {
    my ($rDefHash, $rValueHash, $lunPrintName) = @_;

    foreach my $id (sort keys %{$rDefHash} ) {
	my $rDefArr = $$rDefHash{$id};

	if ($$rDefArr[1] > 0 ) {                                  # high mark 0 => NO check
	    testValue ($$rValueHash{$id}, $$rDefArr[0], $$rDefArr[1], $lunPrintName, $addCheckNames{$id}, $addCheckNames{$id});
	} else {
	   #print "SKIP $$rValueHash{$id}, $$rDefArr[0], $$rDefArr[1], $lunPrintName, $addCheckNames{$id}, $addCheckNames{$id} \n"  
	}# if
    } # foreach
} # sub

#=====================================================================
# Main program
#=====================================================================


# check if multipathd is running
if ( !$opt{'mdskip'} ) {                                              # check is not disabled
    my $cmd = 'ps -e';
    my $output = qx($cmd);
    #print "####\n$output\n####\n";

    my $err = $!;
    if ($? != 0) {
	report("Check if multipathd is running FAILED. (There is an option to disable this check.) Command '$cmd': '$err'", $E_WARNING);
    } else {
	if ( $output !~ m!\smultipathd\n!s ) {
	    report ("No multipathd running. (Not found in process list.)", $text2exit{$opt{'no_multipath'}} );
	} else {
	    #print "FOUND: multipathd process.\n";
	}# if
    }# if
} # if


if ( ($opt{'di'} == 0) && ($multipathCmd eq '') ) {
    # No testcase called and no multipath binary found
    unknown_error ("No multipath binary found. Unable to perform check.");
} # if


my $mpListCmd = $MULTIPATH_LIST;
if ($opt{'ll'}) {
    $mpListCmd = $MULTIPATH_LIST_LONG;
}

my @multipathStateText = @{ get_multipath_text( $mpListCmd ) };       # get input data

my %lunData;                                                          # to store LUN data
my @messages;                                                         # to store log messages from multipath call
checkMultipathText ( \@multipathStateText, \%lunData, \@messages);    # analyse input, get LUN data

foreach my $m (@messages) {                                           # each log message from call (if any...)
    report("MP-MSG '$m'", $E_WARNING);                                # report as warning
} # for


# if no LUN found...
if (scalar keys %lunData == 0) {
    report ("No LUN found or no multipath driver.", $text2exit{$opt{'no_multipath'}});
}


#
# Check path count for each LUN
#
foreach my $lunName ( sort {$a cmp $b} keys %lunData) {
    my $rLunDef        = $lunData{$lunName};
    my $pathCount      = $$rLunDef{'paths'};
    my $policiesCount  = $$rLunDef{'policies'};
    my $lunLine        = $$rLunDef{'lunline'};

    my $warn           = $opt{'ok-paths'};
    my $crit           = $opt{'min-paths'};

    my $rAddChecks     = \%addChecks;  # initialise with default

    # Get the LUN-ID to be displayed, a 'G' in appended to the option-string at parameter check
    my $lunPrintName = getLunPrintName ($rLunDef);

    # check if an extraconfig entry matches
    my $extraconfigMatched = 0;
    foreach my $rExtraConf( @extraconfig ) {
	if ( $$rExtraConf{'val'} eq $$rLunDef{$$rExtraConf{'attrib'}}) {
	    $warn    = $$rExtraConf{'warn'};
	    $crit    = $$rExtraConf{'crit'};

	    $rAddChecks = $$rExtraConf{'addchecks'};
	    $$rExtraConf{'found'} = 1;
	    $extraconfigMatched   = 1;
	    #print "EXTRA: ".$$rExtraConf{'attrib'}."!".$$rExtraConf{'val'}." c=$crit w=$warn \n";
	    last;
	} # if
    } # foreach

    if ( !$extraconfigMatched ) {                  # NO extaconfig entry matched
	foreach my $rGroupDef ( @group ) {         # LUN-Line matches a group definition?
	    my $regex = ${$rGroupDef}{'regex'};
	    #print "GRP: '$regex'\n";
	    if ($lunLine =~ m!$regex! ) {
		$warn    = ${$rGroupDef}{'warn'};
		$crit    = ${$rGroupDef}{'crit'};
		$rAddChecks = ${$rGroupDef}{'addchecks'};
		#print "GRP: '$regex' MATCH: c=$crit w=$warn\n";
		last;
	    } # if
	} # foreach
    }# if

    #print "LUN '$lunPrintName'\n";
    
    testValue ($pathCount, $crit, $warn, $lunPrintName, 'paths', '' );

    my %addCheckValues = ( 
	'sh' => scalar( keys %{$$rLunDef{'sh-hash'}}), 
	'si' => scalar( keys %{$$rLunDef{'si-hash'}}), 
	'p' => $policiesCount 
	);
    testAddChecks ( $rAddChecks, \%addCheckValues, $lunPrintName);
} # foreach


#
# Check if all LUNs in extraconfig were found
#
foreach my $rExtraConf ( @extraconfig ) {
    if (! $$rExtraConf{'found'} ) {
	report("NO DATA found for extra-config LUN selector '". $$rExtraConf{'attrib'}.'!'.$$rExtraConf{'val'}."'", $$rExtraConf{'missingRet'} );
    }
} # foreach



# Counter variable
%nagios_level_count
  = (
     'OK'       => 0,
     'WARNING'  => 0,
     'CRITICAL' => 0,
     'UNKNOWN'  => 0,
    );

# holds only ok messages
@ok_reports = ();

# Reset the WARN signal
$SIG{__WARN__} = 'DEFAULT';

# Print any perl warnings that have occured
if (@perl_warnings) {
    foreach (@perl_warnings) {
	chop @$_;
        report("INTERNAL ERROR: @$_", $E_UNKNOWN);
    } # foreach
} # if

$counter = 0;
ALERT:
foreach (sort {$a->[1] <= $b->[1]} @reports) {
    my ($msg, $level) = @{ $_ };
    $nagios_level_count{$reverse_exitcode{$level}}++;

    # Prefix with nagios level if specified with option '--state'
    $msg = $reverse_exitcode{$level} . ": $msg" if $opt{state};

    # Prefix with one-letter nagios level if specified with option '--short-state'
    $msg = (substr $reverse_exitcode{$level}, 0, 1) . ": $msg" if $opt{shortstate};

    if ($level == $E_OK && !$opt{verbose}) {
	push @ok_reports, $msg;
	next ALERT;
    }

    ($counter++ == 0) ? print $msg : print $linebreak, $msg;
} # foreach

# Determine our exit code
$exit_code = $E_OK;
if ($nagios_level_count{UNKNOWN} > 0)  { $exit_code = $E_UNKNOWN;  }
if ($nagios_level_count{WARNING} > 0)  { $exit_code = $E_WARNING;  }
if ($nagios_level_count{CRITICAL} > 0) { $exit_code = $E_CRITICAL; }


# Print OK messages
$counter = 0;
if ($exit_code == $E_OK && !$opt{verbose}) {
    if ( (!$opt{'state'}) && (!$opt{'shortstate'})  ) {
	print 'OK'.$linebreak;
    }
    foreach my $msg (@ok_reports) {
	($counter++ == 0) ? print $msg : print $linebreak, $msg;
    } # foreach
} # if

# Call reload command if NOT ok and parameter --reload is set
if ( ($exit_code != $E_OK) && $opt{'reload'}  ){
    my $txt = get_multipath_text($MULTIPATH_RELOAD);
    print $linebreak.'Reload was issued.';
}

print $linebreak;
#print "$exit_code\n";
# Exit with proper exit code
exit $exit_code;
