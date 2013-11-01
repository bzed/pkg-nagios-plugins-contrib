#!/usr/bin/perl -w 
############################## check_snmp_time.pl #################
my $Version='1.1';
# Date    : Dec 08 2010
# Purpose : Nagios plugin to check the time on a server using SNMP.\n";
# Author  : Karl Bolingbroke, 2007
# Updated : Frank Migge (support at frank4dd dot com)
# Help    : http://www.frank4dd.com/howto
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
#################################################################
#
# Help : ./check_snmp_time.pl -h
#
# This plugin queries the remote systems time through SNMP and compares
# it against the local time on the Nagios server. This identifies systems
# with no correct time set and sends alarms if the time is off to far.
# HOST-RESOURCES-MIB::hrSystemDate.0 used here returns 8 or 11 byte octets.
# SNMP translation needs to be switched off and we need to convert the
# received SNMP data into readable strings.
#
# snmpget example data on Windows 2003
# susie112:~ > snmpget -v 1 -c SECro 192.168.100.21 1.3.6.1.2.1.25.1.2.0
# HOST-RESOURCES-MIB::hrSystemDate.0 = STRING: 2010-12-10,14:27:36.5
# example data on Linux 2.6
# susie112:~ > snmpget -v 1 -c SECro 192.168.103.32 1.3.6.1.2.1.25.1.2.0
# HOST-RESOURCES-MIB::hrSystemDate.0 = STRING: 2010-12-10,14:27:44.0,+9:0
# example data on AIX 6.1
# susie112:~ > snmpget -v 1 -c SECro 192.168.98.109 1.3.6.1.2.1.25.1.2.0
# HOST-RESOURCES-MIB::hrSystemDate.0 = STRING: 2010-12-10,14:27:59.0


use strict;
use Net::SNMP 5.0;
use Getopt::Long;
use Date::Format;
use Time::Local;

# Nagios specific

my $TIMEOUT = 15;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# HOST-RESOURCES-MIB::hrSystemDate.0 OID
my $remote_time_oid   = '1.3.6.1.2.1.25.1.2.0';

# Globals
my $o_host = 	undef; 		# hostname
my $o_community = undef; 	# community
my $o_port = 	161; 		# port
my $o_help=	undef; 		# wan't some help ?
my $o_verb=	undef;		# verbose mode
my $o_version=	undef;		# print version
# End compatibility
my $o_tzoff=	0;		# remote TZ offset in mins
my $o_warn=	undef;		# warning level in seconds
my $o_crit=	undef;		# critical level in seconds
my $o_timeout=  undef; 		# Timeout (Default 5)
my $o_perf=     undef;          # Output performance data
my $o_version2= undef;          # use snmp v2c
# SNMPv3 specific
my $o_login=	undef;		# Login for snmpv3
my $o_passwd=	undef;		# Pass for snmpv3
my $v3protocols=undef;	        # V3 protocol list.
my $o_authproto='md5';		# Auth protocol
my $o_privproto='des';		# Priv protocol
my $o_privpass= undef;		# priv password

# functions

sub p_version { print "check_snmp_time version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>])  [-p <port>] -w <warn level> -c <crit level> [-f] [-t <timeout>] [-V]\n";
}

sub isnnum { # Return true if arg is not a number
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$|^-(\d+\.?\d*)|(^-\.\d+)$/ ) { return 0 ;}
  return 1;
}

sub help {
   print "\nRemote SNMP System Time Monitor for Nagios version ",$Version,"\n";
   print "GPL licence, (c) 2007 Karl Bolingbroke, update (c)2010 Frank Migge\n\n";
   print_usage();
   print <<EOT;

This plugin queries the remote systems time through SNMP and compares it against the local time on the Nagios server. This identifies systems with no correct time set and sends alarms if the time is off to far.

-v, --verbose
   print extra debugging information 
-h, --help
   print this help message
-H, --hostname=HOST
   name or IP address of host to check
-C, --community=COMMUNITY NAME
   community name for the host's SNMP agent (implies v1 protocol)
-2, --v2c
   Use snmp v2c
-l, --login=LOGIN ; -x, --passwd=PASSWD
   Login and auth password for snmpv3 authentication 
   If no priv password exists, implies AuthNoPriv 
-X, --privpass=PASSWD
   Priv password for snmpv3 (AuthPriv protocol)
-L, --protocols=<authproto>,<privproto>
   <authproto> : Authentication protocol (md5|sha : default md5)
   <privproto> : Priv protocole (des|aes : default des) 
-P, --port=PORT
   SNMP port (Default 161)
-o, --tzoffset=MINS
   the remote systems timezone offset to the Nagios server, in minutes
-w, --warn=INTEGER
   warning level for time difference in seconds
-c, --crit=INTEGER
   critical level for time difference in seconds
-f, --perfparse
   Perfparse compatible output
-t, --timeout=INTEGER
   timeout for SNMP in seconds (Default: 5)
-V, --version
   prints version number
EOT
}

# For verbose output
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
   	'v'	=> \$o_verb,		'verbose'	=> \$o_verb,
        'h'     => \$o_help,    	'help'        	=> \$o_help,
        'H:s'   => \$o_host,		'hostname:s'	=> \$o_host,
        'p:i'   => \$o_port,   		'port:i'	=> \$o_port,
        'C:s'   => \$o_community,	'community:s'	=> \$o_community,
	'l:s'	=> \$o_login,		'login:s'	=> \$o_login,
	'x:s'	=> \$o_passwd,		'passwd:s'	=> \$o_passwd,
	'X:s'	=> \$o_privpass,	'privpass:s'	=> \$o_privpass,
	'L:s'	=> \$v3protocols,	'protocols:s'	=> \$v3protocols,   
        't:i'   => \$o_timeout,       	'timeout:i'     => \$o_timeout,
	'V'	=> \$o_version,		'version'	=> \$o_version,
	'2'     => \$o_version2,        'v2c'           => \$o_version2,
        'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
        'w:s'   => \$o_warn,            'warn:s'        => \$o_warn,
        'o:i'   => \$o_tzoff,           'tzoffset:s'    => \$o_tzoff,
        'f'     => \$o_perf,            'perfparse'     => \$o_perf,
	);
    # Basic checks
    if (defined($o_timeout) && (isnnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 60))) 
      { print "Timeout must be >1 and <60 !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    if (!defined($o_timeout)) {$o_timeout=5;}
    if (defined ($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}};
    if ( ! defined($o_host) ) # check host and filter 
      { print_usage(); exit $ERRORS{"UNKNOWN"}}
    # check snmp information
    if ( !defined($o_community) && (!defined($o_login) || !defined($o_passwd)) )
	  { print "Put snmp login info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    if ((defined($o_login) || defined($o_passwd)) && (defined($o_community) || defined($o_version2)) )
	  { print "Can't mix snmp v1,2c,3 protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    if (defined ($v3protocols)) {
      if (!defined($o_login)) { print "Put snmp V3 login info with protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
      my @v3proto=split(/,/,$v3protocols);
      if ((defined ($v3proto[0])) && ($v3proto[0] ne "")) {$o_authproto=$v3proto[0];	}	# Auth protocol
      if (defined ($v3proto[1])) {$o_privproto=$v3proto[1];	}	# Priv  protocol
      if ((defined ($v3proto[1])) && (!defined($o_privpass))) {
        print "Put snmp V3 priv login info with priv protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    }
    # Check remote timezone offset
    if (defined($o_tzoff) && (isnnum($o_tzoff) || ($o_tzoff < -600) || ($o_tzoff > 600))) 
      { print "Timezone offset must be > -600 and < 600 !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    # Check warnings and critical
    if (!defined($o_warn) || !defined($o_crit))
 	{ print "put warning and critical info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    # Get rid of % sign
    $o_warn =~ s/\%//g; 
    $o_crit =~ s/\%//g;
    if ( isnnum($o_warn) || isnnum($o_crit) ) 
		{ print "Numeric value for warning or critical !\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
    if ($o_warn > $o_crit) 
            { print "warning <= critical ! \n";print_usage(); exit $ERRORS{"UNKNOWN"}}
}

########## MAIN #######
check_options();

# Check gobal timeout if snmp screws up
if (defined($TIMEOUT)) {
  verb("Alarm at $TIMEOUT + 5");
  alarm($TIMEOUT+5);
} else {
  verb("no global timeout defined : $o_timeout + 10");
  alarm ($o_timeout+10);
}

$SIG{'ALRM'} = sub {
 print "No answer from host\n";
 exit $ERRORS{"UNKNOWN"};
};

# Connect to host
my ($session,$error);
if ( defined($o_login) && defined($o_passwd)) {
  # SNMPv3 login
  verb("SNMPv3 login");
    if (!defined ($o_privpass)) {
  verb("SNMPv3 AuthNoPriv login : $o_login, $o_authproto");
    ($session, $error) = Net::SNMP->session(
      -hostname   	=> $o_host,
      -version		=> '3',
      -username		=> $o_login,
      -authpassword	=> $o_passwd,
      -authprotocol	=> $o_authproto,
      -translate        => 0,
      -timeout          => $o_timeout
    );  
  } else {
    verb("SNMPv3 AuthPriv login : $o_login, $o_authproto, $o_privproto");
    ($session, $error) = Net::SNMP->session(
      -hostname   	=> $o_host,
      -version		=> '3',
      -username		=> $o_login,
      -authpassword	=> $o_passwd,
      -authprotocol	=> $o_authproto,
      -privpassword	=> $o_privpass,
      -privprotocol     => $o_privproto,
      -translate        => 0,
      -timeout          => $o_timeout
    );
  }
} else {
    if (defined ($o_version2)) {
        # SNMPv2 Login
        verb("SNMP v2c login");
          ($session, $error) = Net::SNMP->session(
         -hostname  => $o_host,
         -version   => 2,
         -community => $o_community,
         -port      => $o_port,
         -translate => 0,
         -timeout   => $o_timeout
        );
      } else {
      # SNMPV1 login
      verb("SNMP v1 login");
      ($session, $error) = Net::SNMP->session(
        -hostname  => $o_host,
        -community => $o_community,
        -port      => $o_port,
        -translate => 0,
        -timeout   => $o_timeout
      );
    }
}
if (!defined($session)) {
   printf("ERROR opening session: %s.\n", $error);
   exit $ERRORS{"UNKNOWN"};
}

my $exit_val=undef;

############## Start SNMP time check ################

# 1. get local time "seconds since epoch, UTC" into local_timestamp
my $local_timestamp = time;

# 2. get remote date and time
my $result = $session->get_request(-varbindlist => [$remote_time_oid],);

if (!defined($result)) {
   printf("ERROR: Description table : %s.\n", $session->error);
   $session->close;
   exit $ERRORS{"UNKNOWN"};
}

$session->close;

if (!defined ($$result{$remote_time_oid})) {
  print "No time information : UNKNOWN\n";
  exit $ERRORS{"UNKNOWN"};
}

# 3. convert remote date and time into remote_timestamp "seconds since epoch, localtime"
my $remote_octets = $result->{$remote_time_oid};
# translate the received binary data i.e. #0x07da0c0a17393a002b0900
my @remote_date = unpack 'n C6 a C2', $remote_octets;
# 
my $remote_timestamp = timelocal($remote_date[5],$remote_date[4],$remote_date[3],
                                 $remote_date[2],$remote_date[1]-1, $remote_date[0]);

# 4. calculate remote timezone offset
$remote_timestamp = $remote_timestamp + ($o_tzoff * 60);

my $local_timestring = time2str("%Y-%m-%e_%T", $local_timestamp);
my $remote_timestring = time2str("%Y-%m-%e_%T", $remote_timestamp);
verb("Local Time:  $local_timestring\nRemote Time: $remote_timestring");

# 5. compare offset against -w and -c values
my $offset = $local_timestamp - $remote_timestamp;

# 6. return offset in seconds, together with Nagios status:
if ( $offset == 0 ) {
  print "$o_host clock is accurate to the second";
} else {
  if ( abs($offset) != $offset ) {
     print "$o_host clock is ".abs($offset)." seconds late";
  }
  if ( abs($offset) == $offset ) {
    print "$o_host clock is $offset seconds early";
  }
}


$exit_val=$ERRORS{"OK"};
if ( abs($offset) > $o_crit ) {
   print " ($offset > +/-$o_crit) : CRITICAL";
   $exit_val=$ERRORS{"CRITICAL"};
  }
if ( abs($offset) > $o_warn ) {
   # output warn error only if no critical was found
   if ($exit_val eq $ERRORS{"OK"}) {
     print " ($offset > +/-$o_warn) : WARNING"; 
     $exit_val=$ERRORS{"WARNING"};
   }
}
print " : OK" if ($exit_val eq $ERRORS{"OK"});
if (defined($o_perf)) {
   print " | local=$local_timestring remote=$remote_timestring offset=$offset";
}
print "\n";


exit $exit_val;
