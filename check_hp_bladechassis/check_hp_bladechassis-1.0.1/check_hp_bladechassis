#!/usr/bin/perl
#
# DESCRIPTION: Nagios plugin for checking the status of HP
#              blade chassis via SNMP.
#
# AUTHOR: Trond H. Amundsen <t.h.amundsen@usit.uio.no>
#
# $Id: check_hp_bladechassis 16304 2010-01-22 11:20:34Z trondham $
#
# Copyright (C) 2010 Trond H. Amundsen
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
# HP ASN.1 prefix: 1.3.6.1.4.1.232

use strict;
use warnings;
use POSIX qw(isatty);
use Getopt::Long qw(:config no_ignore_case);

# Global (package) variables used throughout the code
use vars qw( $NAME $VERSION $AUTHOR $CONTACT $E_OK $E_WARNING $E_CRITICAL
	     $E_UNKNOWN $USAGE $HELP $LICENSE $original_sigwarn
	     $snmp_session $snmp_error $linebreak $exit_code
	     $count_ioms $count_blades $global $total_wattage
	     %opt %reverse_exitcode %status2nagios %snmp_status %sysinfo
	     %nagios_alert_count %present_map
	     @reports @perfdata @perl_warnings
	  );

#---------------------------------------------------------------------
# Initialization and global variables
#---------------------------------------------------------------------

# Small subroutine to collect any perl warnings during execution
sub collect_perl_warning {
  push @perl_warnings, [@_];
}

# Set the WARN signal to use our collect subroutine above
$original_sigwarn = $SIG{__WARN__};
$SIG{__WARN__} = \&collect_perl_warning;

# Version and similar info
$NAME    = 'check_hp_bladechassis';
$VERSION = '1.0.1';
$AUTHOR  = 'Trond H. Amundsen';
$CONTACT = 't.h.amundsen@usit.uio.no';

# Exit codes
$E_OK       = 0;
$E_WARNING  = 1;
$E_CRITICAL = 2;
$E_UNKNOWN  = 3;

# Usage text
$USAGE = <<"END_USAGE";
Usage: $NAME -H <HOSTNAME> [OPTION]...
END_USAGE

# Help text
$HELP = <<'END_HELP';

OPTIONS:
   -H, --hostname      Hostname or IP of the enclosure
   -C, --community     SNMP community string
   -P, --protocol      SNMP protocol version
   --port              SNMP port number
   -p, --perfdata      Output performance data
   -t, --timeout       Plugin timeout in seconds
   -i, --info          Prefix alerts with the enclosure's serial number
   -v, --verbose       Append extra info to alerts (part no. etc.)
   -e, --extinfo       Append system info to alerts
   -s, --state         Prefix alerts with alert state
   --short-state       Prefix alerts with alert state (abbreviated)
   -d, --debug         Debug output, reports everything
   -h, --help          Display this help text
   -V, --version       Display version info

For more information and advanced options, see the manual page or URL:
  http://folk.uio.no/trondham/software/check_hp_bladechassis.html
END_HELP

# Version text
$LICENSE = <<"END_LICENSE";
$NAME $VERSION
Copyright (C) 2010 $AUTHOR
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by $AUTHOR <$CONTACT>
END_LICENSE

# Options with default values
%opt
  = (
     'port'         => 161, # default SNMP port
     'hostname'     => undef,
     'community'    => 'public',  # SMNP v1 or v2c
     'protocol'     => 2,   # default is SNMPv2c
     'username'     => undef, # SMNP v3
     'authpassword' => undef, # SMNP v3
     'authkey'      => undef, # SMNP v3
     'authprotocol' => undef, # SMNP v3
     'privpassword' => undef, # SMNP v3
     'privkey'      => undef, # SMNP v3
     'privprotocol' => undef, # SMNP v3
     'timeout'      => 30,  # default timeout is 30 seconds
     'verbose'      => 0,
     'info'         => 0,
     'extinfo'      => 0,
     'help'         => 0,
     'version'      => 0,
     'state'        => 0,
     'short-state'  => 0,
     'linebreak'    => undef,
     'perfdata'     => undef,
     'debug'        => 0,
    );

# Get options
GetOptions('H|hostname=s'   => \$opt{hostname},
	   'C|community=s'  => \$opt{community},
	   'P|protocol=i'   => \$opt{protocol},
	   'port=i'         => \$opt{port},
	   'U|username=s'   => \$opt{username},
	   'authpassword=s' => \$opt{authpassword},
	   'authkey=s'      => \$opt{authkey},
	   'authprotocol=s' => \$opt{authprotocol},
	   'privpassword=s' => \$opt{privpassword},
	   'privkey=s'      => \$opt{privkey},
	   'privprotocol=s' => \$opt{privprotocol},
	   't|timeout=i'    => \$opt{timeout},
	   'v|verbose'      => \$opt{verbose},
	   'i|info'         => \$opt{info},
	   'e|extinfo'      => \$opt{extinfo},
	   'h|help'         => \$opt{help},
	   'V|version'      => \$opt{version},
	   's|state'        => \$opt{state},
	   'short-state'    => \$opt{shortstate},
	   'linebreak=s'    => \$opt{linebreak},
	   'p|perfdata:s'   => \$opt{perfdata},
	   'd|debug'        => \$opt{debug},
	  ) or do { print $USAGE; exit $E_UNKNOWN; };

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

# Error if hostname option is not present
if (!defined $opt{hostname}) {
    print "ERROR: No hostname or address given on command line. Use the '-H' or '--hostname' option\n";
    exit $E_UNKNOWN;
}

# Nagios error levels reversed
%reverse_exitcode
  = (
     0 => 'OK',
     1 => 'WARNING',
     2 => 'CRITICAL',
     3 => 'UNKNOWN',
    );

# HP SNMP status (condition)
%status2nagios
  = (
     'Other'    => $E_CRITICAL,
     'Ok'       => $E_OK,
     'Degraded' => $E_WARNING,
     'Failed'   => $E_CRITICAL,
    );

# Status via SNMP
%snmp_status
  = (
     1 => 'Other',
     2 => 'Ok',
     3 => 'Degraded',
     4 => 'Failed',
    );

# Present map
%present_map
  = (
     1 => 'other',
     2 => 'absent',
     3 => 'present',
     4 => 'OMG!WTF!BUG!', # for blades it can return 4, which is NOT spesified in MIB
    );

# Reports (messages) are gathered in this array
@reports = ();

# Setting timeout
$SIG{ALRM} = sub {
    print "PLUGIN TIMEOUT: $NAME timed out after $opt{timeout} seconds\n";
    exit $E_UNKNOWN;
};
alarm $opt{timeout};

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
}

# System information gathered
%sysinfo
  = (
     'serial'   => 'N/A',  # serial number (service tag)
     'model'    => 'N/A',  # system model
     'firmware' => 'N/A',  # firmware version
    );

# Counter variable
%nagios_alert_count
  = (
     'OK'       => 0,
     'WARNING'  => 0,
     'CRITICAL' => 0,
     'UNKNOWN'  => 0,
    );

# Number of blades
$count_blades = 0;

# Number of IO modules
$count_ioms = 0;

# Overall health status
$global = 'Ok';

# Initialize SNMP
snmp_initialize();

# Check that SNMP works
snmp_check();

#---------------------------------------------------------------------
# Functions
#---------------------------------------------------------------------

#
# Store a message in the message array
#
sub report {
    my ($msg, $exval, $part, $spare, $serial) = @_;
    return push @reports, [ $msg, $exval, $part, $spare, $serial ];
}

#
# Give an error and exit with unknown state
#
sub unknown_error {
    my $msg = shift;
    print "ERROR: $msg\n";
    exit $E_UNKNOWN;
}

#
# Initialize SNMP
#
sub snmp_initialize {
    # Legal SNMP v3 protocols
    my $snmp_v3_privprotocol = qr{\A des|aes|aes128|3des|3desde \z}xms;
    my $snmp_v3_authprotocol = qr{\A md5|sha \z}xms;

    # Parameters to Net::SNMP->session()
    my %param
      = (
	 '-port'     => $opt{port},
	 '-hostname' => $opt{hostname},
	 '-version'  => $opt{protocol},
	);

    # Parameters for SNMP v3
    if ($opt{protocol} == 3) {

	# Username is mandatory
	if (defined $opt{username}) {
	    $param{'-username'} = $opt{username};
	}
	else {
	    print "SNMP ERROR: With SNMPv3 the username must be specified\n";
	    exit $E_UNKNOWN;
	}

	# Authpassword is optional
	if (defined $opt{authpassword}) {
	    $param{'-authpassword'} = $opt{authpassword};
	}

	# Authkey is optional
	if (defined $opt{authkey}) {
	    $param{'-authkey'} = $opt{authkey};
	}

	# Privpassword is optional
	if (defined $opt{privpassword}) {
	    $param{'-privpassword'} = $opt{privpassword};
	}

	# Privkey is optional
	if (defined $opt{privkey}) {
	    $param{'-privkey'} = $opt{privkey};
	}

	# Privprotocol is optional
	if (defined $opt{privprotocol}) {
	    if ($opt{privprotocol} =~ m/$snmp_v3_privprotocol/xms) {
		$param{'-privprotocol'} = $opt{privprotocol};
	    }
	    else {
		print "SNMP ERROR: Unknown privprotocol '$opt{privprotocol}', "
		  . "must be one of [des|aes|aes128|3des|3desde]\n";
		exit $E_UNKNOWN;
	    }
	}

	# Authprotocol is optional
	if (defined $opt{authprotocol}) {
	    if ($opt{authprotocol} =~ m/$snmp_v3_authprotocol/xms) {
		$param{'-authprotocol'} = $opt{authprotocol};
	    }
	    else {
		print "SNMP ERROR: Unknown authprotocol '$opt{authprotocol}', "
		  . "must be one of [md5|sha]\n";
		exit $E_UNKNOWN;
	    }
	}
    }
    # Parameters for SNMP v2c or v1
    elsif ($opt{protocol} == 2 or $opt{protocol} == 1) {
	$param{'-community'} = $opt{community};
    }
    else {
	print "SNMP ERROR: Unknown SNMP version '$opt{protocol}'\n";
	exit $E_UNKNOWN;
    }

    # Try to initialize the SNMP session
    if ( eval { require Net::SNMP; 1 } ) {
	($snmp_session, $snmp_error) = Net::SNMP->session( %param );
	if (!defined $snmp_session) {
	    printf "SNMP: %s\n", $snmp_error;
	    exit $E_UNKNOWN;
	}
    }
    else {
	print "ERROR: Required perl module Net::SNMP not found\n";
	exit $E_UNKNOWN;
    }
    return;
}

#
# Checking if SNMP works by probing for "EnclosureModel", which all
# enclosures should have
#
sub snmp_check {
    my $cpqRackCommonEnclosureModel = '1.3.6.1.4.1.232.22.2.3.1.1.1.3.1';
    my $result = $snmp_session->get_request(-varbindlist => [$cpqRackCommonEnclosureModel]);

    # Typically if remote host isn't responding
    if (!defined $result) {
	printf "SNMP CRITICAL: %s\n", $snmp_session->error;
	exit $E_CRITICAL;
    }

    # If OpenManage isn't installed or is not working
    if ($result->{$cpqRackCommonEnclosureModel} =~ m{\A noSuch (Instance|Object) \z}xms) {
	print "SNMP ERROR: Can't determine model name\n";
	exit $E_UNKNOWN;
    }

    # Store the model name
    $sysinfo{model} = $result->{$cpqRackCommonEnclosureModel};
    $sysinfo{model} =~ s{\s+\z}{}xms; # remove trailing whitespace

    return;
}

# Gets the output from SNMP result according to the OIDs checked
sub get_snmp_output {
    my ($result,$oidref) = @_;
    my @output = ();

    foreach my $oid (keys %{ $result }) {
	my @dummy = split m{\.}xms, $oid;
	my $id = pop @dummy;
	--$id;
	my $foo = join q{.}, @dummy;
	if (exists $oidref->{$foo}) {
	    $output[$id]{$oidref->{$foo}} = $result->{$oid};
	}
    }
    return \@output;
}

# Get enclosure status and firmware info
sub get_enclosure_status {
    my @output = ();

    my $part      = undef;  # part number
    my $spare     = undef;  # spare part number
    my $serial    = undef;  # serial
    my $condition = undef;  # enclosure condition

    # OIDs we are interested in
    my %oid
      = (
	 '1.3.6.1.4.1.232.22.2.3.1.1.1.5'  => 'cpqRackCommonEnclosurePartNumber', # part number
	 '1.3.6.1.4.1.232.22.2.3.1.1.1.6'  => 'cpqRackCommonEnclosureSparePartNumber', # spare
	 '1.3.6.1.4.1.232.22.2.3.1.1.1.7'  => 'cpqRackCommonEnclosureSerialNum',  # serial no.
	 '1.3.6.1.4.1.232.22.2.3.1.1.1.8'  => 'cpqRackCommonEnclosureFWRev',      # firmware rev.
	 '1.3.6.1.4.1.232.22.2.3.1.1.1.16' => 'cpqRackCommonEnclosureCondition',  # condition
	);

    my $result = $snmp_session->get_entries(-columns => [keys %oid]);

    # Error if we don't get anything
    if (!defined $result) {
	printf "SNMP CRITICAL: [enclosure table] %s\n", $snmp_session->error;
	exit $E_CRITICAL;
    }

    @output = @{ get_snmp_output($result, \%oid) };

  ENCL:
    foreach my $out (@output) {
	$sysinfo{'serial'}   = $out->{cpqRackCommonEnclosureSerialNum};
	$sysinfo{'firmware'} = $out->{cpqRackCommonEnclosureFWRev};

	$part      = $out->{cpqRackCommonEnclosurePartNumber};
	$spare     = $out->{cpqRackCommonEnclosureSparePartNumber};
	$serial    = $out->{cpqRackCommonEnclosureSerialNum};
	$condition = $out->{cpqRackCommonEnclosureCondition};
    }

    # report global enclosure condition
    report( (sprintf q{Enclosure overall health condition is %s}, $snmp_status{$condition}),
	    $status2nagios{$snmp_status{$condition}}, $part, $spare, $serial );

    $global = $snmp_status{$condition};

    return;
}

# Check the enclosure managers
sub check_managers {
    my @output = ();

    my $index     = undef;  # index
    my $part      = undef;  # part number
    my $spare     = undef;  # spare part number
    my $serial    = undef;  # serial number
    my $role      = undef;  # manager role (primary / secondary)
    my $condition = undef;  # condition

    # OIDs we are interested in
    my %oid
      = (
	 '1.3.6.1.4.1.232.22.2.3.1.6.1.3'  => 'cpqRackCommonEnclosureManagerIndex',
	 '1.3.6.1.4.1.232.22.2.3.1.6.1.6'  => 'cpqRackCommonEnclosureManagerPartNumber',
	 '1.3.6.1.4.1.232.22.2.3.1.6.1.7'  => 'cpqRackCommonEnclosureManagerSparePartNumber',
	 '1.3.6.1.4.1.232.22.2.3.1.6.1.8'  => 'cpqRackCommonEnclosureManagerSerialNum',
	 '1.3.6.1.4.1.232.22.2.3.1.6.1.9'  => 'cpqRackCommonEnclosureManagerRole',
	 '1.3.6.1.4.1.232.22.2.3.1.6.1.12' => 'cpqRackCommonEnclosureManagerCondition',
	);

    my $default_timeout = $snmp_session->timeout();                   # get existing session timeout
    $snmp_session->timeout(20);                                       # set new session timeout
    my $result = $snmp_session->get_entries(-columns => [keys %oid]); # get entries
    $snmp_session->timeout($default_timeout);                         # reset session timeout

    # Error if we don't get anything
    if (!defined $result) {
	printf "ERROR: [manager table] %s\n", $snmp_session->error;
	exit $E_UNKNOWN;
    }

    @output = @{ get_snmp_output($result, \%oid) };

    my %map_role
      = (
	 1 => 'Standby',
	 2 => 'Active',
	);

  MANAGER:
    foreach my $out (@output) {
	$index     = $out->{cpqRackCommonEnclosureManagerIndex};
	$part      = $out->{cpqRackCommonEnclosureManagerPartNumber};
	$spare     = $out->{cpqRackCommonEnclosureManagerSparePartNumber};
	$serial    = $out->{cpqRackCommonEnclosureManagerSerialNum};
	$role      = $out->{cpqRackCommonEnclosureManagerRole};
	$condition = $out->{cpqRackCommonEnclosureManagerCondition};

	# report manager condition
	if (exists $snmp_status{$condition}) {
	    report( (sprintf q{Enclosure management module %d is %s, status is %s},
		     $index, $map_role{$role}, $snmp_status{$condition}),
		    $status2nagios{$snmp_status{$condition}}, $part, $spare, $serial );
	}
	else {
	    report( (sprintf q{Enclosure management module %d is %s, status is Unknown},
		     $index, $map_role{$role}),
		    $E_OK, $part, $spare, $serial );
	}
    }

    return;
}


# Check the enclosure fans
sub check_fans {
    my @output = ();

    my $index     = undef;  # index
    my $present   = undef;  # if device is present
    my $part      = undef;  # part number
    my $spare     = undef;  # spare part number
    my $condition = undef;  # condition

    # OIDs we are interested in
    my %oid
      = (
	 '1.3.6.1.4.1.232.22.2.3.1.3.1.3'  => 'cpqRackCommonEnclosureFanIndex',
	 '1.3.6.1.4.1.232.22.2.3.1.3.1.6'  => 'cpqRackCommonEnclosureFanPartNumber',
	 '1.3.6.1.4.1.232.22.2.3.1.3.1.7'  => 'cpqRackCommonEnclosureFanSparePartNumber',
	 '1.3.6.1.4.1.232.22.2.3.1.3.1.8'  => 'cpqRackCommonEnclosureFanPresent',
	 '1.3.6.1.4.1.232.22.2.3.1.3.1.11' => 'cpqRackCommonEnclosureFanCondition',
	);

    my $result = $snmp_session->get_entries(-columns => [keys %oid]);

    # Error if we don't get anything
    if (!defined $result) {
	printf "SNMP ERROR: [fan table] %s\n", $snmp_session->error;
	exit $E_UNKNOWN;
    }

    @output = @{ get_snmp_output($result, \%oid) };

  FAN:
    foreach my $out (@output) {
	$index     = $out->{cpqRackCommonEnclosureFanIndex};
	$present   = $out->{cpqRackCommonEnclosureFanPresent};
	$part      = $out->{cpqRackCommonEnclosureFanPartNumber};
	$spare     = $out->{cpqRackCommonEnclosureFanSparePartNumber};
	$condition = $out->{cpqRackCommonEnclosureFanCondition};

	next FAN if $present_map{$present} ne 'present';

	# report fan condition
	report( (sprintf q{Fan %d condition is %s}, $index, $snmp_status{$condition}),
		$status2nagios{$snmp_status{$condition}}, $part, $spare, q{} );
    }

    return;
}


# Check the blades
sub check_blades {
    my @output = ();

    my $index     = undef;  # index
    my $name      = undef;  # blade name
    my $part      = undef;  # part number
    my $spare     = undef;  # spare part number
    my $serial    = undef;  # serial number
    my $position  = undef;  # blade position
    my $present   = undef;  # if device is present
    my $product   = undef;  # product id
    my $status    = undef;  # blade status
    my $major     = undef;  # major fault
    my $minor     = undef;  # minor fault
    my $diag      = undef;  # blade fault diagnostic string
    my $power     = undef;  # if blade is powered up

    # OIDs we are interested in
    my %oid
      = (
	 '1.3.6.1.4.1.232.22.2.4.1.1.1.3'  => 'cpqRackServerBladeIndex',
	 '1.3.6.1.4.1.232.22.2.4.1.1.1.4'  => 'cpqRackServerBladeName',
	 '1.3.6.1.4.1.232.22.2.4.1.1.1.6'  => 'cpqRackServerBladePartNumber',
	 '1.3.6.1.4.1.232.22.2.4.1.1.1.7'  => 'cpqRackServerBladeSparePartNumber',
	 '1.3.6.1.4.1.232.22.2.4.1.1.1.8'  => 'cpqRackServerBladePosition',
	 '1.3.6.1.4.1.232.22.2.4.1.1.1.12' => 'cpqRackServerBladePresent',
	 '1.3.6.1.4.1.232.22.2.4.1.1.1.16' => 'cpqRackServerBladeSerialNum',
	 '1.3.6.1.4.1.232.22.2.4.1.1.1.17' => 'cpqRackServerBladeProductId',
	 '1.3.6.1.4.1.232.22.2.4.1.1.1.21' => 'cpqRackServerBladeStatus',
	 '1.3.6.1.4.1.232.22.2.4.1.1.1.22' => 'cpqRackServerBladeFaultMajor',
	 '1.3.6.1.4.1.232.22.2.4.1.1.1.23' => 'cpqRackServerBladeFaultMinor',
	 '1.3.6.1.4.1.232.22.2.4.1.1.1.24' => 'cpqRackServerBladeFaultDiagnosticString',
	 '1.3.6.1.4.1.232.22.2.4.1.1.1.25' => 'cpqRackServerBladePowered',
	);

    my $result = $snmp_session->get_entries(-columns => [keys %oid]);

    # Error if we don't get anything
    if (!defined $result) {
	printf "SNMP ERROR: [blade table] %s\n", $snmp_session->error;
	exit $E_UNKNOWN;
    }

    @output = @{ get_snmp_output($result, \%oid) };

    sub get {
	my ($hash, $val) = @_;
	return exists $hash->{$val} ? $hash->{$val} : undef;
    }

  BLADE:
    foreach my $out (@output) {
	$index     = get($out, 'cpqRackServerBladeIndex');
	$name      = get($out, 'cpqRackServerBladeName');
	$part      = get($out, 'cpqRackServerBladePartNumber');
	$spare     = get($out, 'cpqRackServerBladeSparePartNumber');
	$serial    = get($out, 'cpqRackServerBladeSerialNum');
	$position  = get($out, 'cpqRackServerBladePosition');
	$present   = get($out, 'cpqRackServerBladePresent');
	$product   = get($out, 'cpqRackServerBladeProductId');
	$status    = get($out, 'cpqRackServerBladeStatus');
	$major     = get($out, 'cpqRackServerBladeFaultMajor');
	$minor     = get($out, 'cpqRackServerBladeFaultMinor');
	$diag      = get($out, 'cpqRackServerBladeFaultDiagnosticString');
	$power     = get($out, 'cpqRackServerBladePowered');

	next BLADE if $present_map{$present} ne 'present';
	++$count_blades;

	$part =~ s{\s+\z}{}xms;            # remove trailing whitespace

	# report blade condition
	if (!defined $status) {
	    report( (sprintf q{Blade %d is a %s with name: %s},
		     $index, $product, $name),
		    $E_OK, $part, $spare, $serial );
	}
	else {
	    report( (sprintf q{Blade %d (%s, %s) status is %s},
		     $index, $name, $product, $snmp_status{$status}),
		    $status2nagios{$snmp_status{$status}}, $part, $spare, $serial );
	}
    }

    return;
}


# Check the enclosure power supplies
sub check_psu {
    my @output = ();

    my $index     = undef;  # index
    my $serial    = undef;  # serial number
    my $present   = undef;  # if device is present
    my $part      = undef;  # part number
    my $spare     = undef;  # spare part number
    my $currpwr   = undef;  # The current power output of the power supply in watts
    my $status    = undef;  # The status of the power supply
    my $inputline = undef;  # The status of line input power
    my $condition = undef;  # The condition of the power supply

    # OIDs we are interested in
    my %oid
      = (
	 '1.3.6.1.4.1.232.22.2.5.1.1.1.3'  => 'cpqRackPowerSupplyIndex',
	 '1.3.6.1.4.1.232.22.2.5.1.1.1.5'  => 'cpqRackPowerSupplySerialNum',
	 '1.3.6.1.4.1.232.22.2.5.1.1.1.6'  => 'cpqRackPowerSupplyPartNumber',
	 '1.3.6.1.4.1.232.22.2.5.1.1.1.7'  => 'cpqRackPowerSupplySparePartNumber',
	 '1.3.6.1.4.1.232.22.2.5.1.1.1.10' => 'cpqRackPowerSupplyCurPwrOutput',
	 '1.3.6.1.4.1.232.22.2.5.1.1.1.14' => 'cpqRackPowerSupplyStatus',
	 '1.3.6.1.4.1.232.22.2.5.1.1.1.15' => 'cpqRackPowerSupplyInputLineStatus',
	 '1.3.6.1.4.1.232.22.2.5.1.1.1.16' => 'cpqRackPowerSupplyPresent',
	 '1.3.6.1.4.1.232.22.2.5.1.1.1.17' => 'cpqRackPowerSupplyCondition',
	);

    my $result = $snmp_session->get_entries(-columns => [keys %oid]);

    # Error if we don't get anything
    if (!defined $result) {
	printf "SNMP ERROR: [psu table] %s\n", $snmp_session->error;
	exit $E_UNKNOWN;
    }

    @output = @{ get_snmp_output($result, \%oid) };

    my %psu_status
      = (
	 1  => 'noError',
	 2  => 'generalFailure',
	 3  => 'bistFailure',
	 4  => 'fanFailure',
	 5  => 'tempFailure',
	 6  => 'interlockOpen',
	 7  => 'epromFailed',
	 8  => 'vrefFailed',
	 9  => 'dacFailed',
	 10 => 'ramTestFailed',
	 11 => 'voltageChannelFailed',
	 12 => 'orringdiodeFailed',
	 13 => 'brownOut',
	 14 => 'giveupOnStartup',
	 15 => 'nvramInvalid',
	 16 => 'calibrationTableInvalid',
	);

    my %inputline_status
      = (
	 1 => 'noError',
	 2 => 'lineOverVoltage',
	 3 => 'lineUnderVoltage',
	 4 => 'lineHit',
	 5 => 'brownOut',
	 6 => 'linePowerLoss',
	);

    $total_wattage = 0;

  PSU:
    foreach my $out (@output) {
	$index     = $out->{cpqRackPowerSupplyIndex};
	$present   = $out->{cpqRackPowerSupplyPresent};
	$part      = $out->{cpqRackPowerSupplyPartNumber};
	$spare     = $out->{cpqRackPowerSupplySparePartNumber};
	$condition = $out->{cpqRackPowerSupplyCondition};
	$serial    = $out->{cpqRackPowerSupplySerialNum};
	$currpwr   = $out->{cpqRackPowerSupplyCurPwrOutput};
	$status    = $out->{cpqRackPowerSupplyStatus};
	$inputline = $out->{cpqRackPowerSupplyInputLineStatus};

	next PSU if $present_map{$present} ne 'present';

	# Calculate total power consumption
	$total_wattage += $currpwr;

	# Report PSU condition
	if ($snmp_status{$condition} eq 'Ok') {
	    report( (sprintf q{PSU %d is %s, output: %d W},
		     $index, $snmp_status{$condition}, $currpwr),
		    $status2nagios{$snmp_status{$condition}}, $part, $spare, $serial );
	}
	else {
	    my $msg = sprintf q{PSU %d is %s},
	      $index, $snmp_status{$condition};
	    $msg .= " ($psu_status{$status})" if $status >= 1;
	    $msg .= ", input line status: $inputline_status{$inputline}" if $inputline >= 1;

	    report( $msg, $status2nagios{$snmp_status{$condition}}, $part, $spare, $serial );
	}
    }

    # Collect performance data
    if (defined $opt{perfdata}) {
	push @perfdata, "'total_watt'=${total_wattage}W;0;0";
    }

    return;
}


# Check the IO modules
sub check_iom {
    my @output = ();

    my $index     = undef;  # index
    my $present   = undef;  # if device is present
    my $part      = undef;  # part number
    my $spare     = undef;  # spare part number
    my $serial    = undef;  # serial number
    my $model     = undef;  # The model name of the network connector
    my $location  = undef;  # The location of the network connector within the enclosure
    my $devtype   = undef;  # The type of interrconnect in the enclosure

    # OIDs we are interested in
    my %oid
      = (
	 '1.3.6.1.4.1.232.22.2.6.1.1.1.3'  => 'cpqRackNetConnectorIndex',
	 '1.3.6.1.4.1.232.22.2.6.1.1.1.6'  => 'cpqRackNetConnectorModel',
	 '1.3.6.1.4.1.232.22.2.6.1.1.1.7'  => 'cpqRackNetConnectorSerialNum',
	 '1.3.6.1.4.1.232.22.2.6.1.1.1.8'  => 'cpqRackNetConnectorPartNumber',
	 '1.3.6.1.4.1.232.22.2.6.1.1.1.9'  => 'cpqRackNetConnectorSparePartNumber',
	 '1.3.6.1.4.1.232.22.2.6.1.1.1.12' => 'cpqRackNetConnectorLocation',
	 '1.3.6.1.4.1.232.22.2.6.1.1.1.13' => 'cpqRackNetConnectorPresent',
	 '1.3.6.1.4.1.232.22.2.6.1.1.1.17' => 'cpqRackNetConnectorDeviceType',
	);

    my $result = $snmp_session->get_entries(-columns => [keys %oid]);

    # Error if we don't get anything
    if (!defined $result) {
	printf "SNMP ERROR: [fan table] %s\n", $snmp_session->error;
	exit $E_UNKNOWN;
    }

    @output = @{ get_snmp_output($result, \%oid) };

    my %device_type
      = (
	 1 => 'noconnect',
	 2 => 'network',
	 3 => 'fibrechannel',
	 4 => 'sas',
	 5 => 'inifiband',
	 6 => 'pciexpress',
	);

  IOM:
    foreach my $out (@output) {
	$index     = $out->{cpqRackNetConnectorIndex};
	$present   = $out->{cpqRackNetConnectorPresent};
	$part      = $out->{cpqRackNetConnectorPartNumber};
	$model     = $out->{cpqRackNetConnectorModel};
	$location  = $out->{cpqRackNetConnectorLocation};
	$devtype   = $out->{cpqRackNetConnectorDeviceType};

	next IOM if $present_map{$present} ne 'present';
	++$count_ioms;

	# report IOM
	report( (sprintf q{I/O module %d is type %s: %s},
		 $index, $device_type{$devtype}, $model),
		 $E_OK, $part, $spare, $serial );
    }

    return;
}


# Default plugin output
sub output_default {
    my $c = 0;  # counter to determine linebreaks

    # Run through each message, sorted by severity level
  ALERT:
    foreach (sort {$a->[1] < $b->[1]} @reports) {
	my ($msg, $level, $part, $spare, $serial) = @{ $_ };
	next ALERT if $level == $E_OK;

	# Prefix with service tag if specified with option '-i|--info'
	if ($opt{info}) {
	    $msg = "[$sysinfo{serial}] " . $msg;
	}

	# Prefix with nagios level if specified with option '--state'
	$msg = $reverse_exitcode{$level} . ": $msg" if $opt{state};

	# Prefix with one-letter nagios level if specified with option '--short-state'
	$msg = (substr $reverse_exitcode{$level}, 0, 1) . ": $msg" if $opt{shortstate};

	if ($opt{verbose} and $msg !~ m/overall health condition/) {
	    $msg .= sprintf q{ [part: %s, spare: %s, sn: %s]},
	      $part eq q{} ? 'n/a' : $part,
		$spare eq q{} ? 'n/a' : $spare,
		  $serial eq q{} ? 'n/a' : $serial;
	}

	($c++ == 0) ? print $msg : print $linebreak, $msg;

	$nagios_alert_count{$reverse_exitcode{$level}}++;
    }

    return;
}

# Debug plugin output
sub output_debug {
    print "   System:      $sysinfo{model}\n";
    print "   ServiceTag:  $sysinfo{serial}\n";
    print "   Firmware:    $sysinfo{firmware}";
    print q{ } x (25 - length "$sysinfo{firmware}"), "Plugin version:  $VERSION\n";
    if ($#reports >= 0) {
	print "-----------------------------------------------------------------------------\n";
	print "   System Component Status                                                   \n";
	print "=============================================================================\n";
	print "  STATE  |    PART NO.    | MESSAGE TEXT                                     \n";
	print "---------+----------------+--------------------------------------------------\n";
	foreach (@reports) {
	    my ($msg, $level, $part, $spare, $serial) = @{$_};
	    print q{ } x (8 - length $reverse_exitcode{$level}) . "$reverse_exitcode{$level} | "
	      . q{ } x (14 - length $part) . "$part | $msg\n";
	    $nagios_alert_count{$reverse_exitcode{$level}}++;
	}
    }

    # Print system power readings
    print "-----------------------------------------------------------------------------\n";
    print "   System Power Readings                                                     \n";
    print "=============================================================================\n";
    print "  Total power consumption: $total_wattage W\n";

    return;
}

# Performance data output
sub output_perfdata {
    my $lb = $opt{perfdata} eq 'multiline' ? "\n" : q{ };  # line break for perfdata
    print q{|};
    print join $lb, @perfdata;
    return;
}


#=====================================================================
# Main program
#=====================================================================

# Probe the blade chassis via SNMP
get_enclosure_status();

# Only check managers if global health is not Ok, or debug
if ($global ne 'Ok' or $opt{debug}) {
    check_managers();
}

# Always these
check_fans();
check_blades();
check_iom();
check_psu();

# Print output
if ($opt{debug}) {
    output_debug();
}
else {
    output_default();
}

# Determine our exit code
$exit_code = $E_OK;
if ($nagios_alert_count{UNKNOWN} > 0)  { $exit_code = $E_UNKNOWN;  }
if ($nagios_alert_count{WARNING} > 0)  { $exit_code = $E_WARNING;  }
if ($nagios_alert_count{CRITICAL} > 0) { $exit_code = $E_CRITICAL; }

# Print any perl warnings that have occured
if (@perl_warnings) {
    foreach (@perl_warnings) {
	chop @$_;
	print "${linebreak}INTERNAL ERROR: @$_";
    }
    $exit_code = $E_UNKNOWN;
}

# Reset the WARN signal
$SIG{__WARN__} = $original_sigwarn;

# OK message
if ($exit_code == $E_OK && !$opt{debug}) {
    printf q{OK - System: '%s', SN: '%s', Firmware: '%s', hardware working fine, %d blades, %d i/o modules},
      $sysinfo{model}, $sysinfo{serial}, $sysinfo{firmware}, $count_blades, $count_ioms;
}

# Extended info output
if ($opt{extinfo} && !$opt{debug} && $exit_code != $E_OK) {
    print $linebreak;
    printf '------ SYSTEM: %s, SN: %s, FW: %s',
      $sysinfo{model}, $sysinfo{serial}, $sysinfo{firmware};
}

# Print performance data
if (defined $opt{perfdata} && !$opt{debug} && @perfdata) {
    output_perfdata();
}

print "\n" if !$opt{debug};

# Exit with proper exit code
exit $exit_code;
