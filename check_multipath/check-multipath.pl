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
# (and also 'multipath -r', if you intend to use the --reload option)
# for the NAGIOS-user without password
#
#-------------------------------------------------------------
#
#
# $Id: $
#
# Copyright (C) 2011-2014
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
#      0.1.8    Added Support for LUN names without HEX-ID (e.g. iSCSI LUNs)
#      0.1.9    Added extraconfig option
#
#      0.2.0    Improved flexibility, more testcases. Thanks to Benjamin von Mossner and Ben Evans
#               Warning if data for LUNs in --extraconfig is missing
#               Added --reload option (based on Ben Evans' idea)
#      0.2.1    Improved LUN-line check, thanks to Michal Svamberg
#


use strict;
use warnings;
use Switch;
use POSIX qw(isatty);
use Getopt::Long qw(:config no_ignore_case);

# Global (package) variables used throughout the code
use vars qw( $NAME $VERSION $AUTHOR $CONTACT $E_OK $E_WARNING $E_CRITICAL
	     $E_UNKNOWN $USAGE $HELP $LICENSE $SUDO $MULTIPATH_LIST $MULTIPATH_RELOAD
             $linebreak $counter $exit_code
	     %opt %reverse_exitcode %text2exit @multipathStateLines %nagios_level_count
	     @perl_warnings @reports  @ok_reports @debugInput 
	  );

#---------------------------------------------------------------------
# Initialization and global variables
#---------------------------------------------------------------------


# === Version and similar info ===
$NAME    = 'check-multipath.pl';
$VERSION = '0.2.1   31. MAR. 2014';
$AUTHOR  = 'Hinnerk Rümenapf';
$CONTACT = 'hinnerk.ruemenapf@uni-hamburg.de  hinnerk.ruemenapf@gmx.de';



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

#23. LUN without HEX-ID (iSCSI) thanks to Ernest Beinrohr <Ernest.Beinrohr@axonpro.sk>
"1STORAGE_server_target2 dm-2 IET,VIRTUAL-DISK\n"
."size=1.0T features='0' hwhandler='0' wp=rw\n"
."`-+- policy='round-robin 0' prio=0 status=active\n"
."  |- 9:0:0:1  sdc 8:32 active undef running\n"
."  `- 10:0:0:1 sdd 8:48 active undef running\n",

#24. LUN without HEX-ID (iSCSI) thanks to Ernest Beinrohr <Ernest.Beinrohr@axonpro.sk>
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
    );

# Commands with full path
$SUDO             = '/usr/bin/sudo';
$MULTIPATH_LIST   = '/sbin/multipath -l';
$MULTIPATH_RELOAD = '/sbin/multipath -r';

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

Usage: $NAME [OPTION]...
END_USAGE

# Help text
$HELP = <<'END_HELP';

check-multipath.pl - Nagios plugin to check multipath connections
see:
 http://exchange.nagios.org/directory/Plugins/Operating-Systems/Linux/check-2Dmultipath-2Epl/details
 http://www.nagios.org/documentation

OPTIONS:

  -s, --state         Prefix alerts with alert state
  -S, --short-state   Prefix alerts with alert state abbreviated
  -h, --help          Display this help text
  -V, --version       Display version info
  -v, --verbose
  -m, --min-paths     Low mark,  less paths per LUN are CRITICAL   [2]
  -o, --ok-paths      High mark, less paths per LUN raise WARNING  [4]
  -n, --no-multipath  Exitcode for no LUNs or no multipath driver  [warning]

  -r, --reload        force devmap reload if status is WARNING or CRITICAL
                      (multipath -r)
                      Can help to pick up LUNs coming back to life.

  -l, --linebreak     Define end-of-line string:
                      REG      regular UNIX-Newline
                      HTML     <br/>
                      -other-  use specified string as linebreak symbol, 
                               e.g. ', ' (all in one line, comma seperated)

  -e, --extraconfig   Specify different low/high thresholds for LUNs:
                      "<LUN>,<LOW>,<HIGH>:"  for each LUN with deviant thresholds
                      e.g.  "iscsi_lun_01,2,2:dummyLun,1,1:paranoid_lun,8,16:"
                            "oddLun,3,3:"
                      Use option -v to see LUN names used by this plugin. 

  -d, --di            Run testcase instead of real check           [0]
  -t, --test          Do not display testcase input, just result

  -h, --help          Display this message


NOTE: 'sudo' must be configured to allow the nagios-user to call 
      multipath -l (and also multipath -r, if you intend to use the --reload option)
      without password.

END_HELP

# Version and license text
$LICENSE = <<"END_LICENSE";

$NAME   $VERSION

Copyright (C) 2011-2014 $AUTHOR
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
    );

# Get options
GetOptions(#'t|timeout=i'      => \$opt{timeout},
	   'h|help'           => \$opt{help},
	   'V|version'        => \$opt{version},
	   'n|no-multipath=s' => \$opt{no_multipath},
           'm|min-paths=i'    => \$opt{"min-paths"},
           'o|ok-paths=i'     => \$opt{"ok-paths"},
           'd|di=i'           => \$opt{"di"},
	   's|state'          => \$opt{state},
	   'S|short-state'    => \$opt{shortstate},
	   'l|linebreak=s'    => \$opt{linebreak},
	   'e|extraconfig=s'  => \$opt{extraconfig},
	   'v|verbose'        => \$opt{verbose},
	   't|test'           => \$opt{test},
	   'r|reload'         => \$opt{reload},
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



# extraconfig option
my %extraconfig = ();

if ($opt{extraconfig} ne '') {
    if ($opt{extraconfig} !~ m!^(:?[\w\-]+,\d+,\d+:)+$!  ) {
	unknown_error("Wrong usage of '--extraconfig' option: '"
		      . $opt{extraconfig}
		      . "' syntax error. See help information.");
    } # if

    while ( $opt{extraconfig} =~ m!(:?[\w\-]+),(\d+),(\d+):+!g ) {
	my $name =$1;
	my $crit =$2;
	my $warn =$3;

	if ($crit > $warn) {
	    unknown_error("Error in '--extraconfig' option '"
			  . $opt{extraconfig}
			  . "' for LUN '$name': critical threshold ($crit) must not be higher than warning threshold ($warn).");
	} # if

	#print "\n ['$name', '$crit', '$warn' ] \n";
	$extraconfig{$name} = {'warn' => $warn, 'crit' => $crit, 'found' => 0};
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
		
    my $hostname = qx('hostname');           # add hostname to error message
    chomp $hostname;
    if ($opt{"test"}) {
	print "ERROR: $msg |TESTCASE|\n";
    } else {
	print "ERROR: $msg |Host: $hostname|\n";
    }
    exit $E_UNKNOWN;
}

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
    my ($textLine, $rCurrentLun, $rLunPaths) = @_;
    #print "checkLunLine: '$textLine'\n";

    # mpathb (36000d774000045f655ea91cb4ea41d6f) dm-1 FALCON,IPSTOR DISK
    # mpathb (36000d774000045f655ea91cb4ea41d6f) dm-1 
    # MYVOLUME (36005076801810523100000000000006f)
    # tex-lun4 (3600000e00d0000000002161200120000) dm-7 FUJITSU ,ETERNUS_DXL
    # fc-p6-vicepb (1Proware_FF010000333001EC) dm-1 Proware,R_laila            thanks to Michal Svamberg
    if ($textLine =~ m/^([\w\-]+) \s+ \([\w\-]+\)/x) {
	$$rCurrentLun = $1;                           # do initialisations for new LUN
	#report("named LUN $$rCurrentLun found", $E_OK);
	$$rLunPaths{$$rCurrentLun} = 0;
	return 1;
    } 
    # 36006016019e02a00d009495ddbf3e011 dm-2 DGC,VRAID
    elsif ($textLine =~ m/^[0-9a-fA-F]+ \s+ ([\w\-\_]+)/x) {
	$$rCurrentLun = $1;                           # do initialisations for new LUN
	#report("simple (1) LUN $$rCurrentLun found", $E_OK);
	$$rLunPaths{$$rCurrentLun} = 0;
	return 1;
    } 
    # 360a98000503361754b5a58724f6f7a59dm-2 NETAPP  ,LUN
    elsif ($textLine =~ m/^[0-9a-fA-F]{3,33} \s* ([\w\-\_]+) \s+/x) {
	$$rCurrentLun = $1;                           # do initialisations for new LUN
	#report("simple (2) LUN $$rCurrentLun found", $E_OK);
	$$rLunPaths{$$rCurrentLun} = 0;
	return 1;
    } 
    # iscsi-LUN example
    # 1STORAGE_server_target2 dm-2 IET,VIRTUAL-DISK
    #elsif ($textLine =~ m/^([\w\-]+) \s+ [a-z]+\-\d+/x) {
    elsif ($textLine =~ m/^([\w\-]+) \s+ [a-z]+\-\d+ \s+ [\w\-\,]+/x) {
	$$rCurrentLun = $1;                           # do initialisations for new LUN
	#report("LUN without HEX-ID $$rCurrentLun found", $E_OK);
	$$rLunPaths{$$rCurrentLun} = 0;
	return 1;
    }
    else {
	return 0;
    } # if
} # sub


#---------------------------------------
#
# check if text is a policy description line
#
sub checkPolicyLine {
    my ($textLine) = @_;
    #print "checkPolicyLine: '$textLine'\n";

    # `-+- policy='round-robin 0' prio=-1 status=active
    # |-+- policy='round-robin 0' prio=0 status=active
    ##\_ round-robin 0 [prio=-4][active]
    ## _ round-robin 0  prio=-4  active 
    #\_ round-robin 0 [active]
    # _ round-robin 0  active 
    #if ( $textLine =~ m/^[|\`\-\+_\s]+ \s+ (?:policy=\')?[\w\.\-\_]+ \s \d(?:\')? \s+ prio=/x ) {
    if ( $textLine =~ m/^[|\`\-\+_\s]+ \s+ (?:policy=\')?[\w\.\-\_]+ \s \d(?:\')? \s+ \w+/x ) {
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
    my ($rTextArray) = @_;

    my $state      = "pathDesc";
    my $currentLun = "";
    my %lunPaths   = ();
    my $i          = 0;

    foreach my $textLine (@$rTextArray) {
	$i++;
	#print "$i:\n";
	switch($state) {
                                                                 # initial state: look for path state, new LUN Name, policy
	    case "pathDesc"
	    { 	                                                 # check for path status line
		#  |- 3:0:0:1 sdf 8:80  active undef running 
                ## \_ 3:0:1:1 sde 8:64  [active][undef]
                ##  _ 3:0:1:1 sde 8:64   active  undef 
                ## \_ 13:0:1:0  sdc 8:32  [active]
                ##  _ 13:0:1:0  sdc 8:32   active

		#  (thanks to Bernd Zeimetz)
                #  `- #:#:#:# - #:# active faulty running

		#  (thanks to Ben Evans)
                #  `- #:#:#:# - #:#  active undef running

	        #if ( $textLine =~ m/^[\s_\|\-\`\\\+]+ [\d\:]+ \s+ (\w+) \s+ [\d\:]+ \s+ \w+ \s+ \w+/xi ) {
                if ( $textLine =~ m/^[\s_\|\-\`\\\+]+ [#\d\:]+ \s+ ([\w\-]+) \s+ [#\d\:]+ \s+ \w+/xi ) { 
		    my $pathName   = $1;
		    #print "'$textLine', ";
		    #print "LUN '$currentLun', path '$pathName'\n";

		    if ($textLine =~ m/fail|fault/) {            # fail or fault?
			#print "FAULT: $textLine\n";
			report("LUN $currentLun, path $pathName: ERROR.", $E_WARNING);
		    } 
		    elsif ($textLine !~ m/\sactive\s/) {         # path is active?
			#print "NOT active: $textLine\n";
			report("LUN $currentLun, path $pathName: NOT active.", $E_WARNING);
		    }
		    elsif ($pathName eq "-") {                   # empty path name => path is missing (thanks to Ben Evans)
			report("LUN $currentLun: missing path (empty path name)", $E_WARNING);
		    }
		    else {
			if ( $currentLun eq "") {                # YES => check logic, increase path count for LUN
			     unknown_error ("Path info before LUN name. Line $i:\n'$textLine'")
			}
			$lunPaths{$currentLun}++;
		    } # if
		}                                               # check for new LUN name
		elsif ( checkLunLine ($textLine, \$currentLun, \%lunPaths) ) {
		    $state="lunInfo";
		}                                               # check for new LUN name
		elsif ( ($currentLun ne "") && checkPolicyLine ($textLine) ) {
		   ; # SKIP NESTED POLICY 
		} else {                                        # error: unknown line format
		    unknown_error ("Line $i not recognised. Expected path info, new LUN or nested policy:\n'$textLine'")
		}
            } # case

	    # after new LUN was found skip the INFO-Line (nothing else...)
	    case "lunInfo" {
		if ( $currentLun eq "") {                       # check logic
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
		} else {                                        # error: unknown line format
		    unknown_error ("Line $i not recognised. Expected LUN info:\n'$textLine'")
		}
	    } # case

	    # after LUN info was found skip the path policy (nothing else...)
            # or handle new LUN if no paths available
	    case "pathPolicy" {
		if ( $currentLun eq "") {                       # check logic
		    unknown_error ("No current LUN while looking for path policy. Line $i:\'$textLine'")
		}

                if ( checkPolicyLine ($textLine) ) {
		    $state = "pathDesc";
		}                                               # new LUN found
		elsif ( checkLunLine ($textLine, \$currentLun, \%lunPaths) ) {
		    $state = "lunInfo";
		} else {                                        # error: unknown line format
		    unknown_error ("Line $i not recognised. Expected path policy or new LUN:\n'$textLine'")
		}
	    } # case
	} # switch
    } # foreach

    return \%lunPaths
} # sub

#=====================================================================
# Main program
#=====================================================================


my @multipathStateText = @{ get_multipath_text( $MULTIPATH_LIST ) };  # get input data

my %lunPaths = %{checkMultipathText ( \@multipathStateText )};        # analyse it


# if no LUN found...
if (scalar keys %lunPaths == 0) {
    report ("No LUN found or no multipath driver.", $text2exit{$opt{no_multipath}});
}

#
# Check path count for each LUN
#
foreach my $lunName ( sort {$a cmp $b} keys %lunPaths) {
    my $pathCount = $lunPaths{$lunName};

    my $warn = $opt{'ok-paths'};
    my $crit = $opt{'min-paths'};

    # 	$extraconfig{$name} = {'warn' => $warn, 'crit' => $crit};
    if (defined ($extraconfig{$lunName}) ) {       # deviant thresholds from options?
	$warn = ${$extraconfig{$lunName}}{'warn'};
	$crit = ${$extraconfig{$lunName}}{'crit'};
	#print "$lunName: $pathCount  EXTRA: crit=$crit, warn=$warn\n";
	${$extraconfig{$lunName}}{'found'} = 1;
    } else {	
	#print "$lunName: $pathCount  STANDARD\n";
    }# if
    
    if ($pathCount < $crit){
	report("LUN $lunName: less than $crit paths ($pathCount/$warn)!", $E_CRITICAL);
    } elsif ($pathCount < $warn){
	report("LUN $lunName: less than $warn paths ($pathCount/$warn).", $E_WARNING);
    } else {
	report("LUN $lunName: $pathCount/$warn.", $E_OK);
    }
} # foreach


#
# Check if all LUNs in extraconfig were found
#
foreach my $lunName ( keys %extraconfig ) {
    if (! ${$extraconfig{$lunName}}{'found'} ) {
	report("LUN '$lunName' in extraconfig, but NO DATA found.", $E_WARNING);
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
