package Monitoring::GLPlugin::SNMP;
our @ISA = qw(Monitoring::GLPlugin);
# ABSTRACT: helper functions to build a snmp-based monitoring plugin

use strict;
use File::Basename;
use Digest::MD5 qw(md5_hex);
use JSON;
use File::Slurp qw(read_file);
use Module::Load;
use AutoLoader;
our $AUTOLOAD;

use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

{
  our $mode = undef;
  our $plugin = undef;
  our $blacklist = undef;
  our $session = undef;
  our $rawdata = {};
  our $tablecache = {};
  our $info = [];
  our $extendedinfo = [];
  our $summary = [];
  our $oidtrace = [];
  our $uptime = 0;
}

sub new {
  my ($class, %params) = @_;
  require Monitoring::GLPlugin
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::;
  require Monitoring::GLPlugin::SNMP::MibsAndOids
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::SNMP::MibsAndOids::;
  require Monitoring::GLPlugin::SNMP::CSF
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::SNMP::CSF::;
  require Monitoring::GLPlugin::SNMP::Item
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::SNMP::Item::;
  require Monitoring::GLPlugin::SNMP::TableItem
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::SNMP::TableItem::;
  my $self = Monitoring::GLPlugin->new(%params);
  bless $self, $class;
  return $self;
}

sub v2tov3 {
  my ($self) = @_;
  if ($self->opts->community && $self->opts->community =~ /^snmpv3(.)(.+)/) {
    my $separator = $1;
    my ($authprotocol, $authpassword, $privprotocol, $privpassword,
        $username, $contextengineid, $contextname) = split(/$separator/, $2);
    $self->override_opt('authprotocol', $authprotocol)
        if defined($authprotocol) && $authprotocol;
    $self->override_opt('authpassword', $authpassword)
        if defined($authpassword) && $authpassword;
    $self->override_opt('privprotocol', $privprotocol)
        if defined($privprotocol) && $privprotocol;
    $self->override_opt('privpassword', $privpassword)
        if defined($privpassword) && $privpassword;
    $self->override_opt('username', $username) 
        if defined($username) && $username;
    $self->override_opt('contextengineid', $contextengineid)
        if defined($contextengineid) && $contextengineid;
    $self->override_opt('contextname', $contextname)
        if defined($contextname) && $contextname;
    $self->override_opt('community', undef) ;
    $self->override_opt('protocol', '3') ;
  }
  if (($self->opts->authpassword || $self->opts->authprotocol ||
      $self->opts->privpassword || $self->opts->privprotocol) && 
      $self->opts->protocol ne '3') {
    $self->override_opt('protocol', '3') ;
  }
  if ($self->opts->community2 && $self->opts->community2 =~ /^snmpv3(.)(.+)/) {
    my $separator = $1;
    $self->create_opt('authprotocol2');
    $self->create_opt('authpassword2');
    $self->create_opt('privprotocol2');
    $self->create_opt('privpassword2');
    $self->create_opt('username2');
    $self->create_opt('contextengineid2');
    $self->create_opt('contextname2');
    my ($authprotocol, $authpassword, $privprotocol, $privpassword,
        $username, $contextengineid, $contextname) = split(/$separator/, $2);
    $self->override_opt('authprotocol2', $authprotocol)
        if defined($authprotocol) && $authprotocol;
    $self->override_opt('authpassword2', $authpassword)
        if defined($authpassword) && $authpassword;
    $self->override_opt('privprotocol2', $privprotocol)
        if defined($privprotocol) && $privprotocol;
    $self->override_opt('privpassword2', $privpassword)
        if defined($privpassword) && $privpassword;
    $self->override_opt('username2', $username)
        if defined($username) && $username;
    $self->override_opt('contextengineid2', $contextengineid)
        if defined($contextengineid) && $contextengineid;
    $self->override_opt('contextname2', $contextname)
        if defined($contextname) && $contextname;
    $self->override_opt('community2', undef);
  }
}

sub add_snmp_modes {
  my ($self) = @_;
  $self->add_mode(
      internal => 'device::uptime',
      spec => 'uptime',
      alias => undef,
      help => 'Check the uptime of the device',
  );
  $self->add_mode(
      internal => 'device::walk',
      spec => 'walk',
      alias => undef,
      help => 'Show snmpwalk command with the oids necessary for a simulation',
  );
  $self->add_mode(
      internal => 'device::walkbulk',
      spec => 'bulkwalk',
      alias => undef,
      help => 'Show snmpbulkwalk command with the oids necessary for a simulation',
      hidden => 1,
  );
  $self->add_mode(
      internal => 'device::supportedmibs',
      spec => 'supportedmibs',
      alias => undef,
      help => 'Shows the names of the mibs which this devices has implemented (only lausser may run this command)',
  );
  $self->add_mode(
      internal => 'device::supportedoids',
      spec => 'supportedoids',
      alias => undef,
      help => 'Shows the names of the oids which this devices has implemented (only lausser may run this command)',
  );
}

sub add_snmp_args {
  my ($self) = @_;
  $self->add_arg(
      spec => 'hostname|H=s',
      help => '--hostname
   Hostname or IP-address of the switch or router',
      required => 0,
      env => 'HOSTNAME',
  );
  $self->add_arg(
      spec => 'port=i',
      help => '--port
   The SNMP port to use (default: 161)',
      required => 0,
      default => 161,
  );
  $self->add_arg(
      spec => 'domain=s',
      help => '--domain
   The transport domain to use (default: udp/ipv4, other possible values: udp6, udp/ipv6, tcp, tcp4, tcp/ipv4, tcp6, tcp/ipv6)',
      required => 0,
      default => 'udp',
  );
  $self->add_arg(
      spec => 'protocol|P=s',
      help => '--protocol
   The SNMP protocol to use (default: 2c, other possibilities: 1,3)',
      required => 0,
      default => '2c',
  );
  $self->add_arg(
      spec => 'community|C=s',
      help => '--community
   SNMP community of the server (SNMP v1/2 only)',
      required => 0,
      default => 'public',
      decode => "rfc3986",
  );
  $self->add_arg(
      spec => 'username:s',
      help => '--username
   The securityName for the USM security model (SNMPv3 only)',
      required => 0,
  );
  $self->add_arg(
      spec => 'authpassword:s',
      help => '--authpassword
   The authentication password for SNMPv3',
      required => 0,
      decode => "rfc3986",
  );
  $self->add_arg(
      spec => 'authprotocol:s',
      help => '--authprotocol
   The authentication protocol for SNMPv3 (md5|sha)',
      required => 0,
  );
  $self->add_arg(
      spec => 'privpassword:s',
      help => '--privpassword
   The password for authPriv security level',
      required => 0,
      decode => "rfc3986",
  );
  $self->add_arg(
      spec => 'privprotocol=s',
      help => '--privprotocol
   The private protocol for SNMPv3 (des|aes|aes128|3des|3desde)',
      required => 0,
  );
  $self->add_arg(
      spec => 'contextengineid=s',
      help => '--contextengineid
   The context engine id for SNMPv3 (10 to 64 hex characters)',
      required => 0,
  );
  $self->add_arg(
      spec => 'contextname=s',
      help => '--contextname
   The context name for SNMPv3 (empty represents the "default" context)',
      required => 0,
  );
  $self->add_arg(
      spec => 'community2=s',
      help => '--community2
   SNMP community which can be used to switch the context during runtime',
      required => 0,
      decode => "rfc3986",
  );
  $self->add_arg(
      spec => '--join-communities',
      help => '--join-communities
   It --community2 is used, run the query with community, then community2
   and add up both results. The default is to use community for the initial
   handshake and community2 for querying (bgp and ospf)',
      required => 0,
      default => 0,
  );
  $self->add_arg(
      spec => 'snmpwalk=s',
      help => '--snmpwalk
   A file with the output of a snmpwalk (used for simulation)
   Use it instead of --hostname',
      required => 0,
      env => 'SNMPWALK',
  );
  $self->add_arg(
      spec => 'servertype=s',
      help => '--servertype
     The type of the network device: cisco (default). Use it if auto-detection
     is not possible',
      required => 0,
  );
  $self->add_arg(
      spec => 'oids=s',
      help => '--oids
   A list of oids which are downloaded and written to a cache file.
   Use it together with --mode oidcache',
      required => 0,
  );
  $self->add_arg(
      spec => 'offline:i',
      help => '--offline
   The maximum number of seconds since the last update of cache file before
   it is considered too old',
      required => 0,
      env => 'OFFLINE',
  );
}

sub validate_args {
  my ($self) = @_;
  $self->SUPER::validate_args();
  if ($self->opts->mode =~ /^(bulk)*walk/) {
    if ($self->opts->snmpwalk && $self->opts->hostname) {
      if ($self->check_messages == CRITICAL) {
        # gemecker vom super-validierer, der sicherstellt, dass die datei
        # snmpwalk existiert. in diesem fall wird sie aber erst neu angelegt,
        # also schnauze.
        my ($code, $message) = $self->check_messages;
        if ($message eq sprintf("file %s not found", $self->opts->snmpwalk)) {
          $self->clear_critical;
        }
      }
      # snmp agent wird abgefragt, die ergebnisse landen in einem file
      # opts->snmpwalk ist der filename. da sich die ganzen get_snmp_table/object-aufrufe
      # an das walkfile statt an den agenten halten wuerden, muss opts->snmpwalk geloescht
      # werden. stattdessen wird opts->snmpdump als traeger des dateinamens mitgegeben.
      # nur sinnvoll mit mode=walk
      $self->create_opt('snmpdump');
      $self->override_opt('snmpdump', $self->opts->snmpwalk);
      $self->override_opt('snmpwalk', undef);
    } elsif (! $self->opts->snmpwalk && $self->opts->hostname) {
      # snmp agent wird abgefragt, die ergebnisse landen in einem file, dessen name
      # nicht vorgegeben ist
      $self->create_opt('snmpdump');
    }
  } else {    
    if ($self->opts->snmpwalk && ! $self->opts->hostname) {
      # normaler aufruf, mode != walk, oid-quelle ist eine datei
      $self->override_opt('hostname', 'snmpwalk.file'.md5_hex($self->opts->snmpwalk))
    } elsif ($self->opts->snmpwalk && $self->opts->hostname) {
      # snmpwalk hat vorrang
      $self->override_opt('hostname', undef);
    }
  }
}

sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::(bulk)*walk/) {
    my @trees = ();
    my $name = $Monitoring::GLPlugin::pluginname;
    $name =~ s/.*\///g;
    $name = sprintf "/tmp/snmpwalk_%s_%s", $name, $self->opts->hostname;
    if ($self->opts->oids) {
      # create pid filename
      # already running?;x
      @trees = split(",", $self->opts->oids);

    } elsif ($self->can("trees")) {
      @trees = $self->trees;
      push(@trees, "1.3.6.1.2.1.1");
    } else {
      @trees = ("1.3.6.1.2.1", "1.3.6.1.4.1");
    }
    if ($self->opts->snmpdump) {
      $name = $self->opts->snmpdump;
    }
    $self->opts->override_opt("protocol", $1) if $self->opts->protocol =~ /^v(.*)/;
    if (defined $self->opts->offline) {
      $self->{pidfile} = $name.".pid";
      if (! $self->check_pidfile()) {
        $self->debug("Exiting because another walk is already running");
        printf STDERR "Exiting because another walk is already running\n";
        exit 3;
      }
      $self->write_pidfile();
      my $timedout = 0;
      my $snmpwalkpid = 0;
      $SIG{'ALRM'} = sub {
        $timedout = 1;
        printf "UNKNOWN - %s timed out after %d seconds\n",
            $Monitoring::GLPlugin::plugin->{name}, $self->opts->timeout;
        kill 9, $snmpwalkpid;
      };
      alarm($self->opts->timeout);
      unlink $name.".partial";
      while (! $timedout && @trees) {
        my $tree = shift @trees;
        $SIG{CHLD} = 'IGNORE';
        my $cmd = sprintf "%s -ObentU -v%s -c %s %s %s >> %s",
            ($self->mode =~ /bulk/) ? "snmpbulkwalk" : "snmpwalk",
            $self->opts->protocol,
            $self->opts->community,
            $self->opts->hostname,
            $tree, $name.".partial";
        $self->debug($cmd);
        $snmpwalkpid = fork;
        if (not $snmpwalkpid) {
          exec($cmd);
        } else {
          wait();
        }
      }
      rename $name.".partial", $name if ! $timedout;
      -f $self->{pidfile} && unlink $self->{pidfile};
      if ($timedout) {
        printf "CRITICAL - timeout. There are still %d snmpwalks left\n", scalar(@trees);
        exit 3;
      } else {
        printf "OK - all requested oids are in %s\n", $name;
      }
    } else {
      my @credentials = ();
      my $credmapping = {
        "-community" => "-c",
        "-privpassword" => "-X",
        "-privprotocol" => "-x",
        "-authpassword" => "-A",
        "-authprotocol" => "-a",
        "-username" => "-u",
        "-context" => "-n",
        "-version" => "-v",
      };
      foreach (keys %{$Monitoring::GLPlugin::SNMP::session_params}) {
        if (exists $credmapping->{$_}) {
          push(@credentials, sprintf "%s '%s'",
              $credmapping->{$_},
              $Monitoring::GLPlugin::SNMP::session_params->{$_}
          );
        }
      }
      if (grep(/-X/, @credentials) and grep(/-A/, @credentials)) {
        push(@credentials, "-l authPriv");
      } elsif (grep(/-A/, @credentials)) {
        push(@credentials, "-l authNoPriv");
      } else {
        push(@credentials, "-l noAuthNoPriv");
      }
      my $credentials = join(" ", @credentials);
      $credentials =~ s/-v2 /-v2c /g;
      printf "rm -f %s\n", $name;
      foreach (@trees) {
        printf "%s -ObentU %s %s %s >> %s\n",
            ($self->mode =~ /bulk/) ? "snmpbulkwalk -t 15 -r 20" : "snmpwalk",
            $credentials,
            $self->opts->hostname,
            $_, $name;
      }
    }
    exit 0;
  } elsif ($self->mode =~ /device::uptime/) {
    $self->add_info(sprintf 'device is up since %s',
        $self->human_timeticks($self->{uptime}));
    $self->set_thresholds(warning => '15:', critical => '5:');
    $self->add_message($self->check_thresholds($self->{uptime} / 60));
    $self->add_perfdata(
        label => 'uptime',
        value => $self->{uptime} / 60,
        places => 0,
    );
    if ($self->opts->report ne 'short') {
      $self->add_ok($self->pretty_sysdesc($self->{productname}));
    }
    my ($code, $message) = $self->check_messages(join => ', ', join_all => ', ');
    $Monitoring::GLPlugin::plugin->nagios_exit($code, $message);
  } elsif ($self->mode =~ /device::supportedmibs/) {
    our $mibdepot = [];
    my $unknowns = {};
    my @outputlist = ();
    %{$unknowns} = %{$self->rawdata};
    if ($self->opts->name && -f $self->opts->name) {
      eval { require $self->opts->name };
      $self->add_critical($@) if $@;
    } elsif ($self->opts->name && ! -f $self->opts->name) {
      $self->add_unknown("where is --name mibdepotfile?");
    }
    push(@{$mibdepot}, ['1.3.6.1.2.1.60', 'ietf', 'v2', 'ACCOUNTING-CONTROL-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.238', 'ietf', 'v2', 'ADSL2-LINE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.238.2', 'ietf', 'v2', 'ADSL2-LINE-TC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.94.3', 'ietf', 'v2', 'ADSL-LINE-EXT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.94', 'ietf', 'v2', 'ADSL-LINE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.94.2', 'ietf', 'v2', 'ADSL-TC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.74', 'ietf', 'v2', 'AGENTX-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.3.123', 'ietf', 'v2', 'AGGREGATE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.118', 'ietf', 'v2', 'ALARM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.16.23', 'ietf', 'v2', 'APM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.34.3', 'ietf', 'v2', 'APPC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.13.1', 'ietf', 'v1', 'APPLETALK-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.27', 'ietf', 'v2', 'APPLICATION-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.62', 'ietf', 'v2', 'APPLICATION-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.34.5', 'ietf', 'v2', 'APPN-DLUR-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.34.4', 'ietf', 'v2', 'APPN-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.34.4', 'ietf', 'v2', 'APPN-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.34.4.0', 'ietf', 'v2', 'APPN-TRAP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.49', 'ietf', 'v2', 'APS-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.117', 'ietf', 'v2', 'ARC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.37.1.14', 'ietf', 'v2', 'ATM2-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.59', 'ietf', 'v2', 'ATM-ACCOUNTING-INFORMATION-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.37', 'ietf', 'v2', 'ATM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.37', 'ietf', 'v2', 'ATM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.37.3', 'ietf', 'v2', 'ATM-TC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.15', 'ietf', 'v2', 'BGP4-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.15', 'ietf', 'v2', 'BGP4-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.3.122', 'ietf', 'v2', 'BLDG-HVAC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.17.1', 'ietf', 'v1', 'BRIDGE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.17', 'ietf', 'v2', 'BRIDGE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.19', 'ietf', 'v2', 'CHARACTER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.94', 'ietf', 'v2', 'CIRCUIT-IF-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.3.1.1', 'ietf', 'v1', 'CLNS-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.3.1.1', 'ietf', 'v1', 'CLNS-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.132', 'ietf', 'v2', 'COFFEE-POT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.89', 'ietf', 'v2', 'COPS-CLIENT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.18.1', 'ietf', 'v1', 'DECNET-PHIV-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.21', 'ietf', 'v2', 'DIAL-CONTROL-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.108', 'ietf', 'v2', 'DIFFSERV-CONFIG-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.97', 'ietf', 'v2', 'DIFFSERV-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.66', 'ietf', 'v2', 'DIRECTORY-SERVER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.88', 'ietf', 'v2', 'DISMAN-EVENT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.90', 'ietf', 'v2', 'DISMAN-EXPRESSION-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.82', 'ietf', 'v2', 'DISMAN-NSLOOKUP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.82', 'ietf', 'v2', 'DISMAN-NSLOOKUP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.80', 'ietf', 'v2', 'DISMAN-PING-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.80', 'ietf', 'v2', 'DISMAN-PING-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.63', 'ietf', 'v2', 'DISMAN-SCHEDULE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.63', 'ietf', 'v2', 'DISMAN-SCHEDULE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.64', 'ietf', 'v2', 'DISMAN-SCRIPT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.64', 'ietf', 'v2', 'DISMAN-SCRIPT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.81', 'ietf', 'v2', 'DISMAN-TRACEROUTE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.81', 'ietf', 'v2', 'DISMAN-TRACEROUTE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.46', 'ietf', 'v2', 'DLSW-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.32.2', 'ietf', 'v2', 'DNS-RESOLVER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.32.1', 'ietf', 'v2', 'DNS-SERVER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.127.5', 'ietf', 'v2', 'DOCS-BPI-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.69', 'ietf', 'v2', 'DOCS-CABLE-DEVICE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.69', 'ietf', 'v2', 'DOCS-CABLE-DEVICE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.126', 'ietf', 'v2', 'DOCS-IETF-BPI2-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.132', 'ietf', 'v2', 'DOCS-IETF-CABLE-DEVICE-NOTIFICATION-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.127', 'ietf', 'v2', 'DOCS-IETF-QOS-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.125', 'ietf', 'v2', 'DOCS-IETF-SUBMGT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.127', 'ietf', 'v2', 'DOCS-IF-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.127', 'ietf', 'v2', 'DOCS-IF-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.45', 'ietf', 'v2', 'DOT12-IF-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.53', 'ietf', 'v2', 'DOT12-RPTR-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.155', 'ietf', 'v2', 'DOT3-EPON-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.158', 'ietf', 'v2', 'DOT3-OAM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.4.1.2.2.1.1', 'ietf', 'v1', 'DPI20-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.82', 'ietf', 'v2', 'DS0BUNDLE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.81', 'ietf', 'v2', 'DS0-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.18', 'ietf', 'v2', 'DS1-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.18', 'ietf', 'v2', 'DS1-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.18', 'ietf', 'v2', 'DS1-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.30', 'ietf', 'v2', 'DS3-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.30', 'ietf', 'v2', 'DS3-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.29', 'ietf', 'v2', 'DSA-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.16.26', 'ietf', 'v2', 'DSMON-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.34.7', 'ietf', 'v2', 'EBN-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.167', 'ietf', 'v2', 'EFM-CU-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.47', 'ietf', 'v2', 'ENTITY-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.47', 'ietf', 'v2', 'ENTITY-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.47', 'ietf', 'v2', 'ENTITY-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.99', 'ietf', 'v2', 'ENTITY-SENSOR-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.131', 'ietf', 'v2', 'ENTITY-STATE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.130', 'ietf', 'v2', 'ENTITY-STATE-TC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.70', 'ietf', 'v2', 'ETHER-CHIPSET-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.7', 'ietf', 'v1', 'EtherLike-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.7', 'ietf', 'v1', 'EtherLike-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.35', 'ietf', 'v2', 'EtherLike-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.35', 'ietf', 'v2', 'EtherLike-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.35', 'ietf', 'v2', 'EtherLike-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.35', 'ietf', 'v2', 'EtherLike-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.224', 'ietf', 'v2', 'FCIP-MGMT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.56', 'ietf', 'v2', 'FC-MGMT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.15.73.1', 'ietf', 'v1', 'FDDI-SMT73-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.75', 'ietf', 'v2', 'FIBRE-CHANNEL-FE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.111', 'ietf', 'v2', 'Finisher-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.40', 'ietf', 'v2', 'FLOW-METER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.40', 'ietf', 'v2', 'FLOW-METER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.32', 'ietf', 'v2', 'FRAME-RELAY-DTE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.86', 'ietf', 'v2', 'FR-ATM-PVC-SERVICE-IWF-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.47', 'ietf', 'v2', 'FR-MFR-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.44', 'ietf', 'v2', 'FRNETSERV-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.44', 'ietf', 'v2', 'FRNETSERV-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.44', 'ietf', 'v2', 'FRNETSERV-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.95', 'ietf', 'v2', 'FRSLD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.166.16', 'ietf', 'v2', 'GMPLS-LABEL-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.166.15', 'ietf', 'v2', 'GMPLS-LSR-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.166.12', 'ietf', 'v2', 'GMPLS-TC-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.166.13', 'ietf', 'v2', 'GMPLS-TE-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.98', 'ietf', 'v2', 'GSMP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.16.29', 'ietf', 'v2', 'HC-ALARM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.107', 'ietf', 'v2', 'HC-PerfHist-TC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.16.20.5', 'ietf', 'v2', 'HC-RMON-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.25.1', 'ietf', 'v1', 'HOST-RESOURCES-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.25.1', 'ietf', 'v2', 'HOST-RESOURCES-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.34.6.1.5', 'ietf', 'v2', 'HPR-IP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.34.6', 'ietf', 'v2', 'HPR-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.106', 'ietf', 'v2', 'IANA-CHARSET-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.110', 'ietf', 'v2', 'IANA-FINISHER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.152', 'ietf', 'v2', 'IANA-GMPLS-TC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.30', 'ietf', 'v2', 'IANAifType-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.128', 'ietf', 'v2', 'IANA-IPPM-METRICS-REGISTRY-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.119', 'ietf', 'v2', 'IANA-ITU-ALARM-TC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.154', 'ietf', 'v2', 'IANA-MAU-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.109', 'ietf', 'v2', 'IANA-PRINTER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.4.1.2.6.2.13.1.1', 'ietf', 'v1', 'IBM-6611-APPN-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.166', 'ietf', 'v2', 'IF-CAP-STACK-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.230', 'ietf', 'v2', 'IFCP-MGMT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.77', 'ietf', 'v2', 'IF-INVERTED-STACK-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.31', 'ietf', 'v2', 'IF-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.31', 'ietf', 'v2', 'IF-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.31', 'ietf', 'v2', 'IF-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.85', 'ietf', 'v2', 'IGMP-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.76', 'ietf', 'v2', 'INET-ADDRESS-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.76', 'ietf', 'v2', 'INET-ADDRESS-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.76', 'ietf', 'v2', 'INET-ADDRESS-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.52.5', 'ietf', 'v2', 'INTEGRATED-SERVICES-GUARANTEED-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.52', 'ietf', 'v2', 'INTEGRATED-SERVICES-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.16.27', 'ietf', 'v2', 'INTERFACETOPN-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.17', 'ietf', 'v2', 'IPATM-IPMC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.57', 'ietf', 'v2', 'IPATM-IPMC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.4.24', 'ietf', 'v2', 'IP-FORWARD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.4.24', 'ietf', 'v2', 'IP-FORWARD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.168', 'ietf', 'v2', 'IPMCAST-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.48', 'ietf', 'v2', 'IP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.48', 'ietf', 'v2', 'IP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.83', 'ietf', 'v2', 'IPMROUTE-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.46', 'ietf', 'v2', 'IPOA-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.141', 'ietf', 'v2', 'IPS-AUTH-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.153', 'ietf', 'v2', 'IPSEC-SPD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.103', 'ietf', 'v2', 'IPV6-FLOW-LABEL-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.56', 'ietf', 'v2', 'IPV6-ICMP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.55', 'ietf', 'v2', 'IPV6-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.91', 'ietf', 'v2', 'IPV6-MLD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.3.86', 'ietf', 'v2', 'IPV6-TCP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.3.87', 'ietf', 'v2', 'IPV6-UDP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.142', 'ietf', 'v2', 'ISCSI-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.20', 'ietf', 'v2', 'ISDN-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.138', 'ietf', 'v2', 'ISIS-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.163', 'ietf', 'v2', 'ISNS-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.121', 'ietf', 'v2', 'ITU-ALARM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.120', 'ietf', 'v2', 'ITU-ALARM-TC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.4.1.2699.1.1', 'ietf', 'v2', 'Job-Monitoring-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.95', 'ietf', 'v2', 'L2TP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.165', 'ietf', 'v2', 'LANGTAG-TC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.227', 'ietf', 'v2', 'LMP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.227', 'ietf', 'v2', 'LMP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.101', 'ietf', 'v2', 'MALLOC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.26.1', 'ietf', 'v1', 'MAU-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.26.6', 'ietf', 'v2', 'MAU-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.26.6', 'ietf', 'v2', 'MAU-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.26.6', 'ietf', 'v2', 'MAU-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.26.6', 'ietf', 'v2', 'MAU-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.171', 'ietf', 'v2', 'MIDCOM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.38.1', 'ietf', 'v1', 'MIOX25-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.44', 'ietf', 'v2', 'MIP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.133', 'ietf', 'v2', 'MOBILEIPV6-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.38', 'ietf', 'v2', 'Modem-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.166.8', 'ietf', 'v2', 'MPLS-FTN-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.166.11', 'ietf', 'v2', 'MPLS-L3VPN-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.166.9', 'ietf', 'v2', 'MPLS-LC-ATM-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.166.10', 'ietf', 'v2', 'MPLS-LC-FR-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.166.5', 'ietf', 'v2', 'MPLS-LDP-ATM-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.166.6', 'ietf', 'v2', 'MPLS-LDP-FRAME-RELAY-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.166.7', 'ietf', 'v2', 'MPLS-LDP-GENERIC-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.4.1.9.10.65', 'ietf', 'v2', 'MPLS-LDP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.166.4', 'ietf', 'v2', 'MPLS-LDP-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.166.2', 'ietf', 'v2', 'MPLS-LSR-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.166.1', 'ietf', 'v2', 'MPLS-TC-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.166.3', 'ietf', 'v2', 'MPLS-TE-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.3.92', 'ietf', 'v2', 'MSDP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.28', 'ietf', 'v2', 'MTA-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.28', 'ietf', 'v2', 'MTA-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.28', 'ietf', 'v2', 'MTA-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.123', 'ietf', 'v2', 'NAT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.27', 'ietf', 'v2', 'NETWORK-SERVICES-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.27', 'ietf', 'v2', 'NETWORK-SERVICES-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.71', 'ietf', 'v2', 'NHRP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.92', 'ietf', 'v2', 'NOTIFICATION-LOG-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.133', 'ietf', 'v2', 'OPT-IF-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.14', 'ietf', 'v2', 'OSPF-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.14', 'ietf', 'v2', 'OSPF-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.14.16', 'ietf', 'v2', 'OSPF-TRAP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.14.16', 'ietf', 'v2', 'OSPF-TRAP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.34', 'ietf', 'v2', 'PARALLEL-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.17.6', 'ietf', 'v2', 'P-BRIDGE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.58', 'ietf', 'v2', 'PerfHist-TC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.58', 'ietf', 'v2', 'PerfHist-TC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.172', 'ietf', 'v2', 'PIM-BSR-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.3.61', 'ietf', 'v2', 'PIM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.157', 'ietf', 'v2', 'PIM-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.93', 'ietf', 'v2', 'PINT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.140', 'ietf', 'v2', 'PKTC-IETF-MTA-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.169', 'ietf', 'v2', 'PKTC-IETF-SIG-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.124', 'ietf', 'v2', 'POLICY-BASED-MANAGEMENT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.105', 'ietf', 'v2', 'POWER-ETHERNET-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.23.4', 'ietf', 'v1', 'PPP-BRIDGE-NCP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.23.3', 'ietf', 'v1', 'PPP-IP-NCP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.23.1.1', 'ietf', 'v1', 'PPP-LCP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.23.2', 'ietf', 'v1', 'PPP-SEC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.43', 'ietf', 'v2', 'Printer-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.43', 'ietf', 'v2', 'Printer-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.79', 'ietf', 'v2', 'PTOPO-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.17.7', 'ietf', 'v2', 'Q-BRIDGE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.67.2.2', 'ietf', 'v2', 'RADIUS-ACC-CLIENT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.67.2.2', 'ietf', 'v2', 'RADIUS-ACC-CLIENT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.67.2.1', 'ietf', 'v2', 'RADIUS-ACC-SERVER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.67.2.1', 'ietf', 'v2', 'RADIUS-ACC-SERVER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.67.1.2', 'ietf', 'v2', 'RADIUS-AUTH-CLIENT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.67.1.2', 'ietf', 'v2', 'RADIUS-AUTH-CLIENT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.67.1.1', 'ietf', 'v2', 'RADIUS-AUTH-SERVER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.67.1.1', 'ietf', 'v2', 'RADIUS-AUTH-SERVER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.145', 'ietf', 'v2', 'RADIUS-DYNAUTH-CLIENT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.146', 'ietf', 'v2', 'RADIUS-DYNAUTH-SERVER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.16.31', 'ietf', 'v2', 'RAQMON-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.16.32', 'ietf', 'v2', 'RAQMON-RDS-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.39', 'ietf', 'v2', 'RDBMS-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.1', 'ietf', 'v1', 'RFC1066-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.1', 'ietf', 'v1', 'RFC1156-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.1', 'ietf', 'v1', 'RFC1158-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.1', 'ietf', 'v1', 'RFC1213-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.12', 'ietf', 'v1', 'RFC1229-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.3.7', 'ietf', 'v1', 'RFC1230-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.9', 'ietf', 'v1', 'RFC1231-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.3.2', 'ietf', 'v1', 'RFC1232-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.3.15', 'ietf', 'v1', 'RFC1233-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.13.1', 'ietf', 'v1', 'RFC1243-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.13.1', 'ietf', 'v1', 'RFC1248-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.13.1', 'ietf', 'v1', 'RFC1252-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.14.1', 'ietf', 'v1', 'RFC1253-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.15', 'ietf', 'v1', 'RFC1269-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.16.1', 'ietf', 'v1', 'RFC1271-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.7', 'ietf', 'v1', 'RFC1284-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.15.1', 'ietf', 'v1', 'RFC1285-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.17.1', 'ietf', 'v1', 'RFC1286-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.18.1', 'ietf', 'v1', 'RFC1289-phivMIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.31', 'ietf', 'v1', 'RFC1304-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.32', 'ietf', 'v1', 'RFC1315-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.19', 'ietf', 'v1', 'RFC1316-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.33', 'ietf', 'v1', 'RFC1317-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.34', 'ietf', 'v1', 'RFC1318-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.20.2', 'ietf', 'v1', 'RFC1353-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.4.24', 'ietf', 'v1', 'RFC1354-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.16', 'ietf', 'v1', 'RFC1381-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.5', 'ietf', 'v1', 'RFC1382-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.23.1', 'ietf', 'v1', 'RFC1389-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.7', 'ietf', 'v1', 'RFC1398-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.18', 'ietf', 'v1', 'RFC1406-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.30', 'ietf', 'v1', 'RFC1407-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.24.1', 'ietf', 'v1', 'RFC1414-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.23', 'ietf', 'v2', 'RIPv2-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.16', 'ietf', 'v2', 'RMON2-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.16', 'ietf', 'v2', 'RMON2-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.16.1', 'ietf', 'v1', 'RMON-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.16.20.8', 'ietf', 'v2', 'RMON-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.112', 'ietf', 'v2', 'ROHC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.114', 'ietf', 'v2', 'ROHC-RTP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.113', 'ietf', 'v2', 'ROHC-UNCOMPRESSED-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.33', 'ietf', 'v2', 'RS-232-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.134', 'ietf', 'v2', 'RSTP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.51', 'ietf', 'v2', 'RSVP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.87', 'ietf', 'v2', 'RTP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.139', 'ietf', 'v2', 'SCSI-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.104', 'ietf', 'v2', 'SCTP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.4.1.4300.1', 'ietf', 'v2', 'SFLOW-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.149', 'ietf', 'v2', 'SIP-COMMON-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.36', 'ietf', 'v2', 'SIP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.151', 'ietf', 'v2', 'SIP-SERVER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.148', 'ietf', 'v2', 'SIP-TC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.150', 'ietf', 'v2', 'SIP-UA-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.3.88', 'ietf', 'v2', 'SLAPM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.16.22', 'ietf', 'v2', 'SMON-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.4.1.4.4', 'ietf', 'v1', 'SMUX-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.34', 'ietf', 'v2', 'SNA-NAU-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.34', 'ietf', 'v2', 'SNA-NAU-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.41', 'ietf', 'v2', 'SNA-SDLC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.18', 'ietf', 'v2', 'SNMP-COMMUNITY-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.18', 'ietf', 'v2', 'SNMP-COMMUNITY-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.10', 'ietf', 'v2', 'SNMP-FRAMEWORK-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.10', 'ietf', 'v2', 'SNMP-FRAMEWORK-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.10', 'ietf', 'v2', 'SNMP-FRAMEWORK-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.21', 'ietf', 'v2', 'SNMP-IEEE802-TM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.11', 'ietf', 'v2', 'SNMP-MPD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.11', 'ietf', 'v2', 'SNMP-MPD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.11', 'ietf', 'v2', 'SNMP-MPD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.13', 'ietf', 'v2', 'SNMP-NOTIFICATION-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.13', 'ietf', 'v2', 'SNMP-NOTIFICATION-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.13', 'ietf', 'v2', 'SNMP-NOTIFICATION-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.14', 'ietf', 'v2', 'SNMP-PROXY-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.14', 'ietf', 'v2', 'SNMP-PROXY-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.14', 'ietf', 'v2', 'SNMP-PROXY-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.22.1.1', 'ietf', 'v1', 'SNMP-REPEATER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.22.1.1', 'ietf', 'v1', 'SNMP-REPEATER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.22.5', 'ietf', 'v2', 'SNMP-REPEATER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.12', 'ietf', 'v2', 'SNMP-TARGET-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.12', 'ietf', 'v2', 'SNMP-TARGET-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.12', 'ietf', 'v2', 'SNMP-TARGET-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.15', 'ietf', 'v2', 'SNMP-USER-BASED-SM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.15', 'ietf', 'v2', 'SNMP-USER-BASED-SM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.15', 'ietf', 'v2', 'SNMP-USER-BASED-SM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.20', 'ietf', 'v2', 'SNMP-USM-AES-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.3.101', 'ietf', 'v2', 'SNMP-USM-DH-OBJECTS-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.2', 'ietf', 'v2', 'SNMPv2-M2M-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.1', 'ietf', 'v2', 'SNMPv2-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.1', 'ietf', 'v2', 'SNMPv2-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.1', 'ietf', 'v2', 'SNMPv2-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.3', 'ietf', 'v2', 'SNMPv2-PARTY-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.6', 'ietf', 'v2', 'SNMPv2-USEC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.16', 'ietf', 'v2', 'SNMP-VIEW-BASED-ACM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.16', 'ietf', 'v2', 'SNMP-VIEW-BASED-ACM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.6.3.16', 'ietf', 'v2', 'SNMP-VIEW-BASED-ACM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.39', 'ietf', 'v2', 'SONET-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.39', 'ietf', 'v2', 'SONET-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.39', 'ietf', 'v2', 'SONET-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.17.3', 'ietf', 'v1', 'SOURCE-ROUTING-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.16.28', 'ietf', 'v2', 'SSPM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.54', 'ietf', 'v2', 'SYSAPPL-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.137', 'ietf', 'v2', 'T11-FC-FABRIC-ADDR-MGR-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.162', 'ietf', 'v2', 'T11-FC-FABRIC-CONFIG-SERVER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.159', 'ietf', 'v2', 'T11-FC-FABRIC-LOCK-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.143', 'ietf', 'v2', 'T11-FC-FSPF-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.135', 'ietf', 'v2', 'T11-FC-NAME-SERVER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.144', 'ietf', 'v2', 'T11-FC-ROUTE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.161', 'ietf', 'v2', 'T11-FC-RSCN-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.176', 'ietf', 'v2', 'T11-FC-SP-AUTHENTICATION-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.178', 'ietf', 'v2', 'T11-FC-SP-POLICY-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.179', 'ietf', 'v2', 'T11-FC-SP-SA-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.175', 'ietf', 'v2', 'T11-FC-SP-TC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.177', 'ietf', 'v2', 'T11-FC-SP-ZONING-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.147', 'ietf', 'v2', 'T11-FC-VIRTUAL-FABRIC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.160', 'ietf', 'v2', 'T11-FC-ZONE-SERVER-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.136', 'ietf', 'v2', 'T11-TC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.156', 'ietf', 'v2', 'TCP-ESTATS-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.4.1.23.2.29.1', 'ietf', 'v1', 'TCPIPX-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.49', 'ietf', 'v2', 'TCP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.49', 'ietf', 'v2', 'TCP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.200', 'ietf', 'v2', 'TE-LINK-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.122', 'ietf', 'v2', 'TE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.3.124', 'ietf', 'v2', 'TIME-AGGREGATE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.34.8', 'ietf', 'v2', 'TN3270E-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.34.9', 'ietf', 'v2', 'TN3270E-RT-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.9', 'ietf', 'v2', 'TOKENRING-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.9', 'ietf', 'v2', 'TOKENRING-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.16.1', 'ietf', 'v1', 'TOKEN-RING-RMON-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.42', 'ietf', 'v2', 'TOKENRING-STATION-SR-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.16.30', 'ietf', 'v2', 'TPM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.100', 'ietf', 'v2', 'TRANSPORT-ADDRESS-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.116', 'ietf', 'v2', 'TRIP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.115', 'ietf', 'v2', 'TRIP-TC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.131', 'ietf', 'v2', 'TUNNEL-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.131', 'ietf', 'v2', 'TUNNEL-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.170', 'ietf', 'v2', 'UDPLITE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.50', 'ietf', 'v2', 'UDP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.50', 'ietf', 'v2', 'UDP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.33', 'ietf', 'v2', 'UPS-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.164', 'ietf', 'v2', 'URI-TC-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.229', 'ietf', 'v2', 'VDSL-LINE-EXT-MCM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.228', 'ietf', 'v2', 'VDSL-LINE-EXT-SCM-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.10.97', 'ietf', 'v2', 'VDSL-LINE-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.129', 'ietf', 'v2', 'VPN-TC-STD-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.68', 'ietf', 'v2', 'VRRP-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.2.1.65', 'ietf', 'v2', 'WWW-MIB']);
    push(@{$mibdepot}, ['1.3.6.1.4.1.8072', 'net-snmp', 'v2', 'NET-SNMP-MIB']);
    my $oids = $self->get_entries_by_walk(-varbindlist => [
        '1.3.6.1.2.1', '1.3.6.1.4.1', '1',
    ]);
    foreach my $mibinfo (@{$mibdepot}) {
      next if $self->opts->protocol eq "1" && $mibinfo->[2] ne "v1";
      next if $self->opts->protocol ne "1" && $mibinfo->[2] eq "v1";
      $Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids->{$mibinfo->[3]} = $mibinfo->[0];
    }
    $Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids->{'MIB-2-MIB'} = "1.3.6.1.2.1";
    foreach my $mib (keys %{$Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids}) {
      if ($self->implements_mib($mib)) {
        push(@outputlist, [$mib, $Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids->{$mib}]);
        $unknowns = {@{[map {
            $_, $self->rawdata->{$_}
        } grep {
            substr($_, 0, length($Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids->{$mib})) ne
                $Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids->{$mib} || (
            substr($_, 0, length($Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids->{$mib})) eq
                $Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids->{$mib} &&
            substr($_, length($Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids->{$mib}), 1) ne ".")
        } keys %{$unknowns}]}};
      }
    }
    my $toplevels = {};
    map {
        /^(1\.\d+\.\d+\.\d+\.\d+\.\d+\.\d+\.\d+)\./ and $toplevels->{$1} = 1; 
        /^(1\.\d+\.\d+\.\d+\.\d+\.\d+\.\d+\.\d+\.\d+\.\d+\.\d+\.\d+)\./ and $toplevels->{$1} = 1; 
    } keys %{$unknowns};
    foreach (sort {$a cmp $b} keys %{$toplevels}) {
      push(@outputlist, ["<unknown>", $_]);
    }
    foreach (sort {$a->[0] cmp $b->[0]} @outputlist) {
      printf "implements %s %s\n", $_->[0], $_->[1];
    }
    $self->add_ok("have fun");
    my ($code, $message) = $self->check_messages(join => ', ', join_all => ', ');
    $Monitoring::GLPlugin::plugin->nagios_exit($code, $message);
  } elsif ($self->mode =~ /device::supportedoids/) {
    my $unknowns = {};
    %{$unknowns} = %{$self->rawdata};
    my $confirmed = {};
    foreach my $mib (keys %{$Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids}) {
      foreach my $sym (keys %{$Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}}) {
        my $obj = $self->get_snmp_object($mib, $sym);
        if (defined $obj) {
          my $oid = $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$sym};
          if (exists $unknowns->{$oid}) {
            $confirmed->{$oid} = sprintf '%s::%s = %s', $mib, $sym, $obj;
            delete $unknowns->{$oid};
          } elsif (exists $unknowns->{$oid.'.0'}) {
            $confirmed->{$oid.'.0'} = sprintf '%s::%s = %s', $mib, $sym, $obj;
            delete $unknowns->{$oid.'.0'};
          }
        }
        if ($sym =~ /Table$/) {
          if (my @table = $self->get_snmp_table_objects($mib, $sym)) {
            my $oid = $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$sym};
            $confirmed->{$oid} = sprintf '%s::%s', $mib, $sym;
            $self->add_rawdata($oid, '--------------------');
            foreach my $line (@table) {
              if ($line->{flat_indices}) {
                foreach my $column (grep !/(flat_indices)|(indices)/, keys %{$line}) {
                  my $oid = $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$column};
                  if (exists $unknowns->{$oid.'.'.$line->{flat_indices}}) {
                    $confirmed->{$oid.'.'.$line->{flat_indices}} = 
                        sprintf '%s::%s.%s = %s', $mib, $column, $line->{flat_indices}, $line->{$column};
                    delete $unknowns->{$oid.'.'.$line->{flat_indices}};
                  }
                }
              }
            }
          }
        }
      }
    }
    my @sortedoids = $self->sort_oids([keys %{$self->rawdata}]);
    foreach (@sortedoids) {
      if (exists $confirmed->{$_}) {
        printf "%s\n", $confirmed->{$_};
      } else {
        printf "%s = %s\n", $_, $unknowns->{$_};
      }
    }
  }
}

sub check_snmp_and_model {
  my ($self) = @_;
  if ($self->opts->snmpwalk) {
    my $response = {};
    if (! -f $self->opts->snmpwalk) {
      $self->add_message(CRITICAL, 
          sprintf 'file %s not found',
          $self->opts->snmpwalk);
    } elsif (-x $self->opts->snmpwalk) {
      my $cmd = sprintf "%s -ObentU -v%s -c%s %s 1.3.6.1.4.1 2>&1",
          $self->opts->snmpwalk,
          $self->opts->protocol,
          $self->opts->community,
          $self->opts->hostname;
      open(WALK, "$cmd |");
      while (<WALK>) {
        if (/^([\.\d]+) = .*?: (\-*\d+)/) {
          $response->{$1} = $2;
        } elsif (/^([\.\d]+) = .*?: "(.*?)"/) {
          $response->{$1} = $2;
          $response->{$1} =~ s/\s+$//;
        }
      }
      close WALK;
    } else {
      if (defined $self->opts->offline && $self->opts->mode ne 'walk') {
        if ((time - (stat($self->opts->snmpwalk))[9]) > $self->opts->offline) {
          $self->add_message(UNKNOWN,
              sprintf 'snmpwalk file %s is too old', $self->opts->snmpwalk);
        }
      }
      $self->opts->override_opt('hostname', 'walkhost') if $self->opts->mode ne 'walk';
      my $current_oid = undef;
      my @multiline_string = ();
      open(MESS, $self->opts->snmpwalk);
      while(<MESS>) {
        next if /No Such Object available on this agent at this OID/;
        # SNMPv2-SMI::enterprises.232.6.2.6.7.1.3.1.4 = INTEGER: 6
        if (/^([\d\.]+) = .*?INTEGER: .*\((\-*\d+)\)/) {
          # .1.3.6.1.2.1.2.2.1.8.1 = INTEGER: down(2)
          $response->{$1} = $2;
        } elsif (/^([\d\.]+) = .*?Opaque:.*?Float:.*?([\-\.\d]+)/) {
          # .1.3.6.1.4.1.2021.10.1.6.1 = Opaque: Float: 0.938965
          $response->{$1} = $2;
        } elsif (/^([\d\.]+) = STRING:\s*$/) {
          $response->{$1} = "";
        } elsif (/^([\.\d]+) = STRING: "([^"]*)$/) {
          $current_oid = $1;
          push(@multiline_string, $2);
        } elsif (/^([\d\.]+) = Network Address: (.*)/) {
          $response->{$1} = $2;
        } elsif (/^([\d\.]+) = Hex-STRING: (.*)/) {
          my $k = $1;
          my $h = $2;
          $h =~ s/\s+//g;
          $response->{$k} = pack('H*', $h);
        } elsif (/^([\d\.]+) = \w+: (\-*\d+)\s*$/) {
          $response->{$1} = $2;
        } elsif (/^([\d\.]+) = \w+: "(.*?)"/) {
          $response->{$1} = $2;
          $response->{$1} =~ s/\s+$//;
        } elsif (/^([\d\.]+) = \w+: (.*)/) {
          $response->{$1} = $2;
          $response->{$1} =~ s/\s+$//;
        } elsif (/^([\d\.]+) = (\-*\d+)/) {
          $response->{$1} = $2;
        } elsif (/^([\d\.]+) = "(.*?)"/) {
          $response->{$1} = $2;
          $response->{$1} =~ s/\s+$//;
        } elsif (/^([^"]*)"$/ && @multiline_string && $current_oid) {
          push(@multiline_string, $1);
          $response->{$current_oid} = join("\n", @multiline_string);
          $current_oid = undef;
          @multiline_string = ();
        } elsif (/^"$/ && @multiline_string && $current_oid) {
          $response->{$current_oid} = join("\n", @multiline_string);
          $current_oid = undef;
          @multiline_string = ();
        } elsif (/(.*)/ && @multiline_string && $current_oid) {
          push(@multiline_string, $1);
        }
      }
      close MESS;
    }
    foreach my $oid (keys %$response) {
      if ($oid =~ /^\./) {
        my $nodot = $oid;
        $nodot =~ s/^\.//g;
        $response->{$nodot} = $response->{$oid};
        delete $response->{$oid};
      }
    }
    # Achtung!! Der schnippelt von einem Hex-STRING, der mit 20 aufhoert,
    # das letzte Byte weg. Das muss beruecksichtigt werden, wenn man 
    # spaeter MAC-Adressen o.ae. zueueckrechnet.
    # } elsif ($self->{hwWlanRadioMac} && unpack("H12", $self->{hwWlanRadioMac}." ") =~ /(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})/) {
    # siehe Classes::Huawei::Component::WlanSubsystem::Radio
    map { $response->{$_} =~ s/^\s+//; $response->{$_} =~ s/\s+$//; }
        keys %$response;
    $self->set_rawdata($response);
  } else {
    $self->establish_snmp_session();
  }
  if (! $self->check_messages()) {
    my $tic = time;
    # Datatype TimeTicks = 1/100s
    my $sysUptime = $self->get_snmp_object('MIB-2-MIB', 'sysUpTime', 0);
    # Datatype Integer32 = 1s
    my $snmpEngineTime = $self->get_snmp_object('SNMP-FRAMEWORK-MIB', 'snmpEngineTime');
    # Datatype TimeTicks = 1/100s
    my $hrSystemUptime = $self->get_snmp_object_maybe('HOST-RESOURCES-MIB', 'hrSystemUptime');
    my $sysDescr = $self->get_snmp_object('MIB-2-MIB', 'sysDescr', 0);
    my $tac = time;
    if (defined $hrSystemUptime && $hrSystemUptime =~ /^\d+$/ && $hrSystemUptime > 0) {
      $hrSystemUptime = $self->timeticks($hrSystemUptime);
      $self->debug(sprintf 'hrSystemUptime says: up since: %s / %s',
          scalar localtime (time -  $hrSystemUptime),
          $self->human_timeticks($hrSystemUptime));
    } else {
      $hrSystemUptime = undef;
    }
    if (defined $snmpEngineTime && $snmpEngineTime =~ /^\d+$/ && $snmpEngineTime > 0) {
      $snmpEngineTime = $snmpEngineTime;
      $self->debug(sprintf 'snmpEngineTime says: up since: %s / %s',
          scalar localtime (time - $snmpEngineTime),
          $self->human_timeticks($snmpEngineTime));
    } else {
      # drecksschrott asa liefert negative werte
      # und drecksschrott socomec liefert: wrong type (should be INTEGER): NULL
      $snmpEngineTime = undef;
    }
    if (defined $sysUptime) {
      $sysUptime = $self->timeticks($sysUptime);
      $self->debug(sprintf 'sysUptime says:      up since: %s / %s',
          scalar localtime (time - $sysUptime),
          $self->human_timeticks($sysUptime));
    }
    my $best_uptime = undef;
    if ($hrSystemUptime) {
      # Bei Linux-basierten Geraeten wird snmpEngineTime viel zu haeufig
      # durchgestartet, also lieber das hier.
      $best_uptime = $hrSystemUptime;
      # Es sei denn, snmpEngineTime ist tatsaechlich groesser, dann gilt
      # wiederum dieses. Mag sein, dass der zahlenwert hier manchmal huepft
      # und ein Performancegraph Zacken bekommt, aber das ist mir egal.
      # es geht nicht um Graphen in Form einer ansteigenden Geraden, sondern
      # um das Erkennen von spontanen Reboots und das Vermeiden von
      # falschen Alarmen.
      if ($snmpEngineTime && $snmpEngineTime > $hrSystemUptime) {
        $best_uptime = $snmpEngineTime;
      }
    } elsif ($snmpEngineTime) {
      $best_uptime = $snmpEngineTime;
    } else {
      $best_uptime = $sysUptime;
    }
    if (defined $best_uptime && defined $sysDescr) {
      $self->{uptime} = $best_uptime;
      $self->{productname} = $sysDescr;
      $self->{sysobjectid} = $self->get_snmp_object('MIB-2-MIB', 'sysObjectID', 0);
      $self->debug(sprintf 'uptime: %s', $self->{uptime});
      $self->debug(sprintf 'up since: %s',
          scalar localtime (time - $self->{uptime}));
      $Monitoring::GLPlugin::SNMP::uptime = $self->{uptime};
      $self->debug('whoami: '.$self->{productname});
    } else {
      if ($tac - $tic >= ($Monitoring::GLPlugin::SNMP::session ?
          $Monitoring::GLPlugin::SNMP::session->timeout : $self->opts->timeout())) {
        $self->add_message(UNKNOWN,
            'could not contact snmp agent, timeout during snmp-get sysUptime');
      } elsif ($self->{broken_snmp_agent}) {
        # plugins may add an array of subroutines to their Classes::Device.
        # For example, check_tl_health has to deal with IBM libraries, which
        # do not show sysUptime nor sysDescr nor any other uptime oids.
        # In order to let the plugin continue with a fake uptime, one of
        # the broken_snmp_agent subroutines must return a true value after it
        # has set the uptime to 1 hour and filled out $self->{productname}
        my $mein_lieber_freund_und_kupferstecher = 0;
        foreach my $kriegst_du_die_kurve (@{$self->{broken_snmp_agent}}) {
          if (&$kriegst_du_die_kurve()) {
            $mein_lieber_freund_und_kupferstecher = 1;
            $self->debug(sprintf 'uptime: %s', $self->{uptime});
            $self->debug(sprintf 'up since: %s',
                scalar localtime (time - $self->{uptime}));
            $Monitoring::GLPlugin::SNMP::uptime = $self->{uptime};
            $self->debug('whoami: '.$self->{productname});
            return;
          }
        }
        if (! $mein_lieber_freund_und_kupferstecher) {
          $self->add_message(UNKNOWN,
              'got neither sysUptime and sysDescr nor any other useful information, is this snmp agent working correctly?');
        }
      } else {
        $self->add_message(UNKNOWN,
            'Did not receive both sysUptime and sysDescr, is this snmp agent working correctly?');
      }
      $Monitoring::GLPlugin::SNMP::session->close if $Monitoring::GLPlugin::SNMP::session;
    }
  }
}

sub pretty_sysdesc {
  my ($self, $sysDesc) = @_;
  my $prettySysDescription = undef;
  if (exists $self->{classified_as}) {
    my $now_class = ref($self);
    my $now_pretty_sysdesc = $self->can("pretty_sysdesc");
    bless $self, $self->{classified_as};
    my $classified_pretty_sysdesc = $self->can("pretty_sysdesc");
    if ($now_pretty_sysdesc && $classified_pretty_sysdesc && $now_pretty_sysdesc ne $classified_pretty_sysdesc) {
      $prettySysDescription = $self->pretty_sysdesc($sysDesc);
    } elsif (! $now_pretty_sysdesc && $classified_pretty_sysdesc) {
      $prettySysDescription = $self->pretty_sysdesc($sysDesc);
    }
    bless $self, $now_class;
  }
  return $prettySysDescription ? $prettySysDescription : $sysDesc;
}

sub establish_snmp_session {
  my ($self) = @_;
  $self->set_timeout_alarm();
  if (eval "require Net::SNMP") {
    my %params = ();
    my $net_snmp_version = Net::SNMP->VERSION(); # 5.002000 or 6.000000
    $params{'-translate'} = [ # because we see "NULL" coming from socomec devices
      -all => 0x0,
      -nosuchobject => 1,
      -nosuchinstance => 1,
      -endofmibview => 1,
      -unsigned => 1,
    ];
    $params{'-hostname'} = $self->opts->hostname;
    $params{'-version'} = $self->opts->protocol;
    if ($self->opts->port) {
      $params{'-port'} = $self->opts->port;
    }
    if ($self->opts->domain) {
      $params{'-domain'} = $self->opts->domain;
    }
    $self->v2tov3;
    if ($self->opts->protocol eq '3') {
      $params{'-version'} = $self->opts->protocol;
      $params{'-username'} = $self->opts->username;
      if ($self->opts->authpassword) {
        $params{'-authpassword'} = $self->opts->authpassword;
      }
      if ($self->opts->authprotocol) {
        $params{'-authprotocol'} = $self->opts->authprotocol;
      }
      if ($self->opts->privpassword) {
        $params{'-privpassword'} = $self->opts->privpassword;
      }
      if ($self->opts->privprotocol) {
        $params{'-privprotocol'} = $self->opts->privprotocol;
      }
      # context hat in der session nix verloren, sondern wird
      # als zusatzinfo bei den requests mitgeschickt
      #if ($self->opts->contextengineid) {
      #  $params{'-contextengineid'} = $self->opts->contextengineid;
      #}
      #if ($self->opts->contextname) {
      #  $params{'-contextname'} = $self->opts->contextname;
      #}
    } else {
      $params{'-community'} = $self->opts->community;
    }
    # breaks cisco wlc. at least with 15, wlc did not work.
    # removing this at all may cause strange epn errors. As if only
    # certain oids were returned as undef, others not.
    # next try: 50
    $params{'-timeout'} = $self->opts->timeout() >= 60 ?
        50 : $self->opts->timeout() - 2;
    my $stderrvar = "";
    *SAVEERR = *STDERR;
    open ERR ,'>',\$stderrvar;
    *STDERR = *ERR;
    my ($session, $error) = Net::SNMP->session(%params);
    *STDERR = *SAVEERR;
    if ($stderrvar && $error && $error =~ /Time synchronization failed/) {
      # This is what you get when you have
      # - an APC ups with a buggy firmware.
      # - no chance to update it.
      # - a support contract.
      no strict 'refs';
      no warnings 'redefine';
      *{'Net::SNMP::_discovery_synchronization_cb'} = sub {
        my ($this) = @_;
        if ($this->{_security}->discovered())
        {
          $this->_error_clear();
          return $this->_discovery_complete();
        }
        return $this->_discovery_failed();
      };
      ($session, $error) = Net::SNMP->session(%params);
    }
    if (! defined $session) {
      $self->add_message(CRITICAL, 
          sprintf 'cannot create session object: %s', $error);
      $self->debug(Data::Dumper::Dumper(\%params));
    } else {
      my $max_msg_size = $session->max_msg_size();
      #$session->max_msg_size(4 * $max_msg_size);
      if ($self->opts->protocol eq "1") {
        $Monitoring::GLPlugin::SNMP::maxrepetitions = 0;
      } else {
        $Monitoring::GLPlugin::SNMP::maxrepetitions = 20;
      }
      $Monitoring::GLPlugin::SNMP::max_msg_size = $max_msg_size;
      $Monitoring::GLPlugin::SNMP::session = $session;
      $Monitoring::GLPlugin::SNMP::session_params = \%params;
    }
  } else {
    $self->add_message(CRITICAL,
        'could not find Net::SNMP module');
  }
}

sub session_translate {
  my ($self, $translation) = @_;
  $Monitoring::GLPlugin::SNMP::session->translate($translation) if
      $Monitoring::GLPlugin::SNMP::session;
}

sub establish_snmp_secondary_session {
  my ($self) = @_;
  if ($self->opts->protocol eq '3' &&
      $self->opts->can('authprotocol2') && (
      defined $self->opts->authprotocol2 ||
      defined $self->opts->authpassword2 ||
      defined $self->opts->privprotocol2 ||
      defined $self->opts->privpassword2 ||
      defined $self->opts->username2 ||
      defined $self->opts->contextengineid2 ||
      defined $self->opts->contextname2
  )) {
    my $relogin = 0;
    # bei --community2="snmpv3,..." wurde alles in xyz2 per override gesteckt
    $relogin = 1 if ! $self->strequal($self->opts->authprotocol,
        $self->opts->authprotocol2);
    $relogin = 1 if ! $self->strequal($self->opts->authpassword,
        $self->opts->authpassword2);
    $relogin = 1 if ! $self->strequal($self->opts->privprotocol,
        $self->opts->privprotocol2);
    $relogin = 1 if ! $self->strequal($self->opts->privpassword,
        $self->opts->privpassword2);
    $relogin = 1 if ! $self->strequal($self->opts->username,
        $self->opts->username2);
    if ($relogin) {
      $Monitoring::GLPlugin::SNMP::session = undef;
      $self->opts->override_opt('authprotocol',
          $self->opts->authprotocol2);
      $self->opts->override_opt('authpassword',
          $self->opts->authpassword2);
      $self->opts->override_opt('privprotocol',
          $self->opts->privprotocol2);
      $self->opts->override_opt('privpassword',
          $self->opts->privpassword2);
      $self->opts->override_opt('username',
          $self->opts->username2);
      $self->establish_snmp_session;
    }
    $self->opts->override_opt('contextengineid',
        $self->opts->contextengineid2);
    $self->opts->override_opt('contextname',
        $self->opts->contextname2);
    return 1;
  } else {
    if (defined $self->opts->community2 &&
        $self->opts->community2 ne
        $self->opts->community) {
      $Monitoring::GLPlugin::SNMP::session = undef;
      $self->opts->override_opt('community',
          $self->opts->community2) ;
      $self->establish_snmp_session;
      return 1;
    }
  }
  return 0;
}

sub reset_snmp_max_msg_size {
  my ($self) = @_;
  $self->debug(sprintf "reset snmp_max_msg_size to %s",
      $Monitoring::GLPlugin::SNMP::max_msg_size) if $Monitoring::GLPlugin::SNMP::session;
  $Monitoring::GLPlugin::SNMP::session->max_msg_size($Monitoring::GLPlugin::SNMP::max_msg_size) if $Monitoring::GLPlugin::SNMP::session;
}

sub mult_snmp_max_msg_size {
  my ($self, $factor) = @_;
  $factor ||= 10;
  $self->debug(sprintf "raise snmp_max_msg_size %d * %d", 
      $factor, $Monitoring::GLPlugin::SNMP::session->max_msg_size()) if $Monitoring::GLPlugin::SNMP::session;
  $Monitoring::GLPlugin::SNMP::session->max_msg_size($factor * $Monitoring::GLPlugin::SNMP::session->max_msg_size()) if $Monitoring::GLPlugin::SNMP::session;
}

sub bulk_baeh_reset {
  my ($self, $maxrepetitions) = @_;
  $self->reset_snmp_max_msg_size();
  $Monitoring::GLPlugin::SNMP::maxrepetitions =
      int($Monitoring::GLPlugin::SNMP::session->max_msg_size() * 0.017) if $Monitoring::GLPlugin::SNMP::session;
}

sub bulk_is_baeh {
  my ($self, $maxrepetitions) = @_;
  $maxrepetitions ||= 1;
  $Monitoring::GLPlugin::SNMP::maxrepetitions = int($maxrepetitions);
}

sub get_max_repetitions {
  my ($self) = @_;
  return $Monitoring::GLPlugin::SNMP::maxrepetitions;
}

sub no_such_model {
  my ($self) = @_;
  printf "Model %s is not implemented\n", $self->{productname};
  exit 3;
}

sub no_such_mode {
  my ($self) = @_;
  if (ref($self) eq "Classes::Generic") {
    $self->init();
  } elsif (ref($self) eq "Classes::Device") {
    $self->add_message(UNKNOWN, 'the device did not implement the mibs this plugin is asking for');
    $self->add_message(UNKNOWN,
        sprintf('unknown device%s', $self->{productname} eq 'unknown' ?
            '' : '('.$self->{productname}.')'));
  } elsif (ref($self) eq "Monitoring::GLPlugin::SNMP") {
    # uptime, offline
    $self->init();
  } else {
    eval {
      bless $self, "Classes::Generic";
      $self->init();
    };
    if ($@) {
      bless $self, "Monitoring::GLPlugin::SNMP";
      $self->init();
    }
  }
  if (ref($self) eq "Monitoring::GLPlugin::SNMP") {
    $self->nagios_exit(3,
        sprintf "Mode %s is not implemented for this type of device",
        $self->opts->mode
    );
    exit 3;
  }
}

sub uptime {
  my ($self) = @_;
  return $Monitoring::GLPlugin::SNMP::uptime;
}

sub ago_sysuptime {
  my ($self, $eventtime) = @_;
  # if there is an oid containing the value of sysUptime at the time of
  # a certain event (e.g. cipSecFailTime), this method returns the
  # time in seconds that has passed since the event.
  # sysUptime overflows at 2**32, so it is possible that the eventtime is
  # bigger than sysUptime
  # the eventtime value must come as 1/100s, do not normalize it before.
  #
  # 0-----------------|---------------X
  #                   event=2Mio      sysUptime=5.5Mio
  # event happened (5.5Mio - 2Mio) seconds ago
  #
  # 0-----------------|---------------2**32/0-----------X
  #                   event=2Mio                        sysUptime=100k
  #
  # event happened (100k + (2**32 - 2Mio)) seconds ago
  #
  my $sysUptime = $self->get_snmp_object('MIB-2-MIB', 'sysUpTime', 0);
  if ($eventtime > $sysUptime) {
    return ($sysUptime + (2**32 - $eventtime)) / 100;
  } else {
    return ($sysUptime - $eventtime) / 100;
  }
}

sub map_oid_to_class {
  my ($self, $oid, $class) = @_;
  $Monitoring::GLPlugin::SNMP::MibsAndOids::discover_ids->{$oid} = $class;
}

sub discover_suitable_class {
  my ($self) = @_;
  my $sysobj = $self->get_snmp_object('MIB-2-MIB', 'sysObjectID', 0);
  $sysobj =~ s/^\.//g;
  foreach my $oid (keys %{$Monitoring::GLPlugin::SNMP::MibsAndOids::discover_ids}) {
    if ($sysobj && $oid eq $sysobj) {
      return $Monitoring::GLPlugin::SNMP::MibsAndOids::discover_ids->{$sysobj};
    }
  }
}

sub require_mib {
  my ($self, $mib) = @_;
  my $package = uc $mib;
  $package =~ s/-//g;
  if (exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib} ||
      exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids->{$mib}) {
    $self->debug("i know package "."Monitoring::GLPlugin::SNMP::MibsAndOids::".$package);
    return;
  } else {
    eval {
      my @oldkeys = ();
      $self->set_variable("verbosity", 2);
      if ($self->get_variable("verbose")) {
        my @oldkeys = exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib} ?
            keys %{$Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids} : 0;
      }
      $self->debug("load mib "."Monitoring::GLPlugin::SNMP::MibsAndOids::".$package);
      load "Monitoring::GLPlugin::SNMP::MibsAndOids::".$package;
      if ($self->get_variable("verbose")) {
        my @newkeys = exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib} ?
            keys %{$Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids} : 0;
        $self->debug(sprintf "now i know: %s", join(" ", sort @newkeys));
        $self->debug(sprintf "now i know %d keys.", scalar(@newkeys));
        if (scalar(@newkeys) <= scalar(@oldkeys)) {
          $self->debug(sprintf "from %d to %d keys. why did we load?",
              scalar(@oldkeys), scalar(@newkeys));
        }
      }
    };
    if ($@) {
      $self->debug("failed to load "."Monitoring::GLPlugin::SNMP::MibsAndOids::".$package);
    } else {
      if (exists $Monitoring::GLPlugin::SNMP::MibsAndOids::requirements->{$mib}) {
        foreach my $submib (@{$Monitoring::GLPlugin::SNMP::MibsAndOids::requirements->{$mib}}) {
          $self->require_mib($submib);
        }
      }
    }
  }
}

sub implements_mib {
  my ($self, $mib, $table) = @_;
  $self->require_mib($mib);
  if (! exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids->{$mib}) {
    return 0;
  }
  if (! $table) {
    my $sysobj = $self->get_snmp_object('MIB-2-MIB', 'sysObjectID', 0);
    $sysobj =~ s/^\.// if $sysobj;
    if ($sysobj && $sysobj eq $Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids->{$mib}) {
      $self->debug(sprintf "implements %s (sysobj exact)", $mib);
      return 1;
    }
    if ($sysobj && $Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids->{$mib} eq
        substr $sysobj, 0, length $Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids->{$mib}) {
      $self->debug(sprintf "implements %s (sysobj)", $mib);
      return 1;
    }
  }

  my $check_oid = $table ?
      $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$table} :
      $Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids->{$mib};

  # some mibs are only composed of tables
  my $traces;
  if ($self->opts->snmpwalk) {
    my @matches;
    # exact match  
    push(@matches, @{[map {
        $_, $self->rawdata->{$_}
    } grep {
        $_ eq $check_oid
    } keys %{$self->rawdata}]});

    # partial match (add trailing dot)  
    $check_oid =~ s/\.?$/./;
    push(@matches, @{[map {
        $_, $self->rawdata->{$_}
    } grep {
        substr($_, 0, length($check_oid)) eq $check_oid
    } keys %{$self->rawdata}]});
    $traces = {@matches};
  } else {
    my %params = (
        -varbindlist => [
            $check_oid
        ]
    );
    if ($Monitoring::GLPlugin::SNMP::session->version() == 3) {
      $params{-contextengineid} = $self->opts->contextengineid if $self->opts->contextengineid;
      $params{-contextname} = $self->opts->contextname if $self->opts->contextname;
    }
    my $timeout = $Monitoring::GLPlugin::SNMP::session->timeout();
    $Monitoring::GLPlugin::SNMP::session->timeout(10);
    $traces = $Monitoring::GLPlugin::SNMP::session->get_next_request(%params);
    $Monitoring::GLPlugin::SNMP::session->timeout($timeout);
  }
  if ($traces && # must find oids following to the ident-oid
      ! exists $traces->{$Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids->{$mib}} && # must not be the ident-oid
      grep { # following oid is inside this tree
          substr($_, 0, length($check_oid)) eq $check_oid
      } keys %{$traces}) {
    if (exists $traces->{$check_oid} &&
        $traces->{$check_oid} eq "endOfMibView") {
      return 0;
    }
    $self->debug(sprintf "implements %s (found traces)", $mib);
    return 1;
  }
}

sub timeticks {
  my ($self, $timestr) = @_;
  if ($timestr =~ /\((\d+)\)/) {
    # Timeticks: (20718727) 2 days, 9:33:07.27
    $timestr = $1 / 100;
  } elsif ($timestr =~ /(\d+)\s*day[s]*.*?(\d+):(\d+):(\d+)\.(\d+)/) {
    # Timeticks: 2 days, 9:33:07.27
    $timestr = $1 * 24 * 3600 + $2 * 3600 + $3 * 60 + $4;
  } elsif ($timestr =~ /(\d+):(\d+):(\d+):(\d+)\.(\d+)/) {
    # Timeticks: 0001:03:18:42.77
    $timestr = $1 * 3600 * 24 + $2 * 3600 + $3 * 60 + $4;
  } elsif ($timestr =~ /(\d+):(\d+):(\d+)\.(\d+)/) {
    # Timeticks: 9:33:07.27
    $timestr = $1 * 3600 + $2 * 60 + $3;
  } elsif ($timestr =~ /(\d+)\s*hour[s]*.*?(\d+):(\d+)\.(\d+)/) {
    # Timeticks: 3 hours, 42:17.98
    $timestr = $1 * 3600 + $2 * 60 + $3;
  } elsif ($timestr =~ /(\d+)\s*minute[s]*.*?(\d+)\.(\d+)/) {
    # Timeticks: 36 minutes, 01.96
    $timestr = $1 * 60 + $2;
  } elsif ($timestr =~ /(\d+)\.\d+\s*second[s]/) {
    # Timeticks: 01.02 seconds
    $timestr = $1;
  } elsif ($timestr =~ /^(\d+)$/) {
    $timestr = $1 / 100;
  }
  return $timestr;
}

sub human_timeticks {
  my ($self, $timeticks) = @_;
  my $days = int($timeticks / 86400);
  $timeticks -= ($days * 86400);
  my $hours = int($timeticks / 3600);
  $timeticks -= ($hours * 3600);
  my $minutes = int($timeticks / 60);
  my $seconds = $timeticks % 60;
  $days = $days < 1 ? '' : $days .'d ';
  return $days . sprintf "%dh %dm %ds", $hours, $minutes, $seconds;
}

sub internal_name {
  my ($self) = @_;
  my $class = ref($self);
  $class =~ s/^.*:://;
  if (exists $self->{flat_indices}) {
    return sprintf "%s_%s", uc $class, $self->{flat_indices};
  } else {
    return sprintf "%s", uc $class;
  }
}

################################################################
# file-related functions
#
sub create_interface_cache_file {
  my ($self) = @_;
  my $extension = "";
  if ($self->opts->snmpwalk && ! $self->opts->hostname) {
    $self->opts->override_opt('hostname',
        'snmpwalk.file'.md5_hex($self->opts->snmpwalk))
  }
  if ($self->opts->contextname) {
    $extension .= $self->opts->contextname . '_';
  }
  if ($self->opts->community) { 
    $extension .= md5_hex($self->opts->community);
  }
  $extension =~ s/\//_/g;
  $extension =~ s/\(/_/g;
  $extension =~ s/\)/_/g;
  $extension =~ s/\*/_/g;
  $extension =~ s/\s/_/g;
  return sprintf "%s/%s_interface_cache_%s", $self->statefilesdir(),
      $self->opts->hostname, lc $extension;
}

sub create_entry_cache_file {
  my ($self, $mib, $table, $key_attr_id) = @_;
  return lc sprintf "%s_%s_%s_%s_cache",
      $self->create_interface_cache_file(),
      $mib, $table, $key_attr_id;
}

sub update_entry_cache {
  my ($self, $force, $mib, $table, $key_attrs, $last_change) = @_;
  $self->debug(sprintf "last change of %s::%s was %s",
      $mib, $table, scalar localtime $last_change) if $last_change;
  my $update_deadline = time - 3600;
  if ($last_change) {
    # epoch timestamp, which is a hint when some table was last updated
    $update_deadline = ($last_change + 60)
        if $last_change > $update_deadline;
  }
  my $must_update = 0;
  if (ref($key_attrs) ne "ARRAY") {
    if ($key_attrs eq 'flat_indices') {
      # wird nur 1x verwendet bisher, bei OLD-CISCO-INTERFACES-MIB etherstats
      #my $entry = $table =~ s/Table/Entry/gr; # zu neu fuer centos6
      my $entry = $table;
      $entry =~ s/Table/Entry/g;
      my @sortednames = map {
          $_->[0]
      } sort {
          $a->[1] cmp $b->[1]
      } map {
          [$_, join '', map {
              sprintf("%30d", $_)
          } split( /\./, $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$_})];
      } grep {
          $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$_} =~ /^$Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$entry}\./;
      } keys %{$Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}};
      $key_attrs = $sortednames[0];
    }
    $key_attrs = [$key_attrs];
  }
  my $key_attr_id = join('#', @{$key_attrs});
  my $cache = sprintf "%s_%s_%s_cache", $mib, $table, $key_attr_id;
  my $statefile = $self->create_entry_cache_file($mib, $table, $key_attr_id);
  if ($force == -1 && -f $statefile) {
    $must_update = 1;
    # brauchts unter keinen umstaenden.
    # z.b. wenn ein vorhergehender update_interfaces_cache keine aenderungen
    # angezeigt hat, dann spart man sich hier den etherlike-update o.ae.
    $self->debug(sprintf 'skip update of %s %s %s %s cache',
        $self->opts->hostname, $self->opts->mode, $mib, $table);
  } elsif ($force != 0 || ! -f $statefile || ((stat $statefile)[9]) < ($update_deadline)) {
    $must_update = 1;
    $self->debug(sprintf 'force update of %s %s %s %s cache',
        $self->opts->hostname, $self->opts->mode, $mib, $table);
    $self->{$cache} = {};
    foreach my $entry ($self->get_snmp_table_objects($mib, $table, undef, $key_attrs)) {
      my $key = join('#', map { $entry->{$_} } @{$key_attrs});
      my $hash = $key . '-//-' . join('.', @{$entry->{indices}});
      $self->{$cache}->{$hash} = $entry->{indices};
    }
    $self->save_cache($mib, $table, $key_attrs);
  }
  $self->load_cache($mib, $table, $key_attrs);
  return $must_update;
}

sub save_cache {
  my ($self, $mib, $table, $key_attrs) = @_;
  my $cache = sprintf "%s_%s_%s_cache", $mib, $table, join('#', @{$key_attrs});
  $self->create_statefilesdir();
  my $statefile = $self->create_entry_cache_file($mib, $table, join('#', @{$key_attrs}));
  my $tmpfile = $statefile.$$.rand();
  my $fh = IO::File->new();
  if ($fh->open($tmpfile, "w")) {
    my $coder = JSON::XS->new->ascii->pretty->allow_nonref;
    my $jsonscalar = $coder->encode($self->{$cache});
    $fh->print($jsonscalar);
    $fh->flush();
    $fh->close();
  }
  rename $tmpfile, $statefile;
  $self->debug(sprintf "saved %s to %s",
      Data::Dumper::Dumper($self->{$cache}), $statefile);
}

sub load_cache {
  my ($self, $mib, $table, $key_attrs) = @_;
  my $cache = sprintf "%s_%s_%s_cache", $mib, $table, join('#', @{$key_attrs});
  my $statefile = $self->create_entry_cache_file($mib, $table, join('#', @{$key_attrs}));
  $self->{$cache} = {};
  if ( -f $statefile) {
    my $jsonscalar = read_file($statefile);
    our $VAR1;
    eval {
      my $coder = JSON::XS->new->ascii->pretty->allow_nonref;
      $VAR1 = $coder->decode($jsonscalar);
    };
    if($@) {
      $self->debug(sprintf "json load from %s failed. fallback", $statefile);
      delete $INC{$statefile} if exists $INC{$statefile}; # else unit tests fail
      eval "$jsonscalar";
      if($@) {
        printf "FATAL: Could not load cache in perl format!\n";
        $self->debug(sprintf "fallback perl load from %s failed", $statefile);
      }
    }
    $self->debug(sprintf "load %s", Data::Dumper::Dumper($VAR1));
    $self->{$cache} = $VAR1;
  }
}

################################################################
# top-level convenience functions
#
sub get_snmp_objects {
  my ($self, $mib, @mos) = @_;
  foreach (@mos) {
    my $value = $self->get_snmp_object($mib, $_);
    if (defined $value) {
      $self->{$_} = $value;
    }
  }
}

sub get_snmp_tables {
  my ($self, $mib, $infos) = @_;
  foreach my $info (@{$infos}) {
    my $arrayname = $info->[0];
    my $table = $info->[1];
    my $class = $info->[2];
    my $filter = $info->[3];
    my $rows = $info->[4];
    my $key_attr = $info->[5];
    $self->{$arrayname} = [] if ! exists $self->{$arrayname};
    if (! exists $Monitoring::GLPlugin::SNMP::tablecache->{$mib} || ! exists $Monitoring::GLPlugin::SNMP::tablecache->{$mib}->{$table}) {
      $Monitoring::GLPlugin::SNMP::tablecache->{$mib}->{$table} = [];
      foreach ($key_attr ?
          $self->get_snmp_table_objects_with_cache($mib, $table, $key_attr, $rows) :
          $self->get_snmp_table_objects($mib, $table, undef, $rows)) {
        push(@{$Monitoring::GLPlugin::SNMP::tablecache->{$mib}->{$table}}, $_);
        my $new_object = $class->new(%{$_});
        next if (defined $filter && ! &$filter($new_object));
        push(@{$self->{$arrayname}}, $new_object);
      }
    } else {
      $self->debug(sprintf "get_snmp_tables %s %s cache hit", $mib, $table);
      foreach (@{$Monitoring::GLPlugin::SNMP::tablecache->{$mib}->{$table}}) {
        my $new_object = $class->new(%{$_});
        next if (defined $filter && ! &$filter($new_object));
        push(@{$self->{$arrayname}}, $new_object);
      }
    }
  }
}

sub merge_tables {
  my ($self, $into, @from) = @_;
  my $into_indices = {};
  map { $into_indices->{$_->{flat_indices}} = $_ } @{$self->{$into}};
  foreach (@from) {
    foreach my $element (@{$self->{$_}}) {
      if (exists $into_indices->{$element->{flat_indices}}) {
        foreach my $key (keys %{$element}) {
          $into_indices->{$element->{flat_indices}}->{$key} = $element->{$key};
        }
      }
    }
    delete $self->{$_};
  }
}

sub merge_tables_with_code {
  my ($self, $into, @from) = @_;
  my $into_indices = {};
  my @to_del = ();
  foreach my $into_elem (@{$self->{$into}}) {
    for (my $i = 0; $i < @from; $i += 2) {
      my ($from_elems, $func) = @from[$i, $i+1];
      foreach my $from_elem (@{$self->{$from_elems}}) {
        if (&$func($into_elem, $from_elem)) {
          foreach my $key (grep !/^(info|trace|warning|critical|blacklisted|extendedinfo|flat_indices|indices)/, sort keys %{$from_elem}) {
            $into_elem->{$key} = $from_elem->{$key};
          }
        }
      }
    }
  }
  for (my $i = 0; $i < @from; $i += 2) {
    my ($from_elems, $func) = @from[$i, $i+1];
    delete $self->{$from_elems};
  }
}

sub mibs_and_oids_definition {
  my ($self, $mib, $definition, @values) = @_;
  if (exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib} &&
      exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}) {
    if (ref($Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}) eq "CODE") {
      return $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}->(@values);
    } elsif (ref($Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}) eq "HASH") {
      return $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}->{$values[0]};
    }
  } else {
    return "unknown_".$definition;
  }
}

sub clear_table_cache {
  my ($self, $mib, $table) = @_;
  if ($table && exists $Monitoring::GLPlugin::SNMP::tablecache->{$mib}) {
    delete $Monitoring::GLPlugin::SNMP::tablecache->{$mib}->{$table};
  } elsif ($mib) {
    delete $Monitoring::GLPlugin::SNMP::tablecache->{$mib};
  } else {
    $Monitoring::GLPlugin::SNMP::tablecache = {};
  }
}

################################################################
# 2nd level 
#
sub get_snmp_object {
  my ($self, $mib, $mo, $index) = @_;
  $self->require_mib($mib);
  my $oid = $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$mo};
  if (defined $oid) {
    my $qoid = $oid.(defined $index ? '.'.$index : '');
    my $response = $self->get_request(-varbindlist => [$qoid]);
    if (defined $response->{$qoid}) {
      if ($response->{$qoid} eq 'noSuchInstance' || $response->{$qoid} eq 'noSuchObject') {
        $response->{$qoid} = undef;
      } elsif (my @symbols = $self->make_symbolic($mib, $response, [[$index]], { $oid => $mo })) {
        $response->{$oid} = $symbols[0]->{$mo};
      }
    }
    $self->debug(sprintf "GET: %s::%s (%s) : %s", $mib, $mo, $oid, defined $response->{$oid} ? $response->{$oid} : "<undef>");
    if (! defined $response->{$oid} && ! defined $index) {
      return $self->get_snmp_object($mib, $mo, 0);
    }
    return $response->{$oid};
  }
  return undef;
}

sub get_snmp_object_maybe {
    my ($self, @args) = @_;
    my $ret;

    # Just do a regular fetch when simulating
    return $self->get_snmp_object(@args) unless defined $Monitoring::GLPlugin::SNMP::session;

    # There may be no response at all. Turn the SNMP timeout down so we can
    # catch that without triggering SIGALRM
    my $orig_timeout = $Monitoring::GLPlugin::SNMP::session->timeout;
    my $new_timeout = $orig_timeout / 10;
    $new_timeout = 5 if $new_timeout > 5;
    $Monitoring::GLPlugin::SNMP::session->timeout($new_timeout);

    # Get
    $ret = $self->get_snmp_object(@args);

    # Restore timeout
    $Monitoring::GLPlugin::SNMP::session->timeout($orig_timeout);

    return $ret;
}

sub get_snmp_table_objects_with_cache {
  my ($self, $mib, $table, $key_attr, $rows, $force) = @_;
  $force ||= 0;
  $self->update_entry_cache($force, $mib, $table, $key_attr);
  my @indices = $self->get_cache_indices($mib, $table, $key_attr);
  my @entries = ();
  foreach ($self->get_snmp_table_objects($mib, $table, \@indices, $rows)) {
    push(@entries, $_);
  }
  return @entries;
}

sub get_table_row_oids {
  my ($self, $mib, $entry, $rows, $sym_lookup) = @_;
  $self->require_mib($mib);
  my $eoid = $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$entry}.'.';
  my $eoidlen = length($eoid);
  my @columns = scalar(@{$rows}) ?
  map {
      $sym_lookup->{$_->[1]} = $_->[0];
      $_->[1];
  } grep {
      substr($_->[1], 0, $eoidlen) eq $eoid
  } map {
      [$_, $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$_}]
  } @{$rows}
  :
  map {
      $sym_lookup->{$_->[1]} = $_->[0];
      $_->[1];
  } grep {
      substr($_->[1], 0, $eoidlen) eq $eoid
  } map {
      [$_, $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$_}]
  } keys %{$Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}};
  return $self->sort_oids(\@columns);
}

# get_snmp_table_objects('MIB-Name', 'Table-Name', 'Table-Entry', [indices])
# returns array of hashrefs
sub get_snmp_table_objects {
  my ($self, $mib, $table, $indices, $rows) = @_;
  $indices ||= [];
  $rows ||= [];
  $self->require_mib($mib);
  my @entries = ();
  my @augmenting = ();
  my @augmenting_tables = ();
  my $sym_lookup = {};
  $self->debug(sprintf "get_snmp_table_objects %s %s", $mib, $table);
  if ($table =~ /^(.*?)\+(.*)/) {
    $table = $1;
    @augmenting_tables = split(/\+/, $2);
  }
  my $entry = $table;
  $entry =~ s/Table/Entry/g;
  if (! exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib} ||
      ! exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$table}) {
    return ();
  }
  if (! exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$entry}) {
    $self->debug(sprintf "table %s::%s has no entry oid", $mib, $table);
    $entry = $table;
    $entry =~ s/Table/TableEntry/g;
    if (! exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$entry}) {
      return ();
    }
  }
  my $tableoid = $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$table};
  my $entryoid = $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$entry};
  my $augmenting_tableoid = undef;
  my @columns = $self->get_table_row_oids($mib, $entry, $rows, $sym_lookup);
  my @augmenting_columns = ();
  foreach my $augmenting_table (@augmenting_tables) {
    my $augmenting_entry = $augmenting_table;
    $augmenting_entry =~ s/Table/Entry/g;
    if (! exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$augmenting_entry}) {
      $self->debug(sprintf "table %s::%s has no entry oid", $mib, $augmenting_table);
      $augmenting_entry = $augmenting_table;
      $augmenting_entry =~ s/Table/TableEntry/g;
      if (! exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$augmenting_entry}) {
        $augmenting_entry = undef;
      }
    }
    if ($augmenting_entry) {
      $self->debug(sprintf "get_snmp_table_objects augment %s %s with %s", $mib, $table, $augmenting_table);
      @augmenting_columns = $self->get_table_row_oids($mib, $augmenting_entry, $rows, $sym_lookup);
      $augmenting_tableoid = $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$augmenting_table};
      push(@augmenting, [$augmenting_tableoid, \@augmenting_columns]);
    }
  }
  if (scalar(@{$indices}) == 1 && $indices->[0] == -1) {
    # get mini-version of a table
    my $result = $self->get_entries(
        -columns => \@columns,
    );
    foreach (@augmenting) {
      my($augmenting_tableoid, @augmenting_columns) = ($_->[0], @{$_->[1]});
      my $augmenting_result = $self->get_entries(
          -columns => \@augmenting_columns,
      );
      while (my ($key, $value) = each %{$augmenting_result}) {
        $result->{$key} = $value;
      }
    }
    my @indices = 
        $self->get_indices(
            -baseoid => $entryoid,
            -oids => [keys %{$result}]);
    @entries = map {
        $_->{indices} = shift @indices; $_
    } @entries = $self->make_symbolic($mib, $result, \@indices, $sym_lookup);
    $self->debug(sprintf "get_snmp_table_objects mini returns %d entries",
        scalar(@entries));
  } elsif (scalar(@{$indices}) == 1) {
    my $index = join('.', @{$indices->[0]});
    my $result = $self->get_entries(
        -startindex => $index,
        -endindex => $index,
        -columns => \@columns,
    );
    foreach (@augmenting) {
      my($augmenting_tableoid, @augmenting_columns) = ($_->[0], @{$_->[1]});
      my $augmenting_result = $self->get_entries(
          -startindex => $index,
          -endindex => $index,
          -columns => \@augmenting_columns,
      );
      while (my ($key, $value) = each %{$augmenting_result}) {
        $result->{$key} = $value;
      }
    }
    @entries = map {
        $_->{indices} = shift @{$indices}; $_
    } $self->make_symbolic($mib, $result, $indices, $sym_lookup);
    $self->debug(sprintf "get_snmp_table_objects single returns %d entries",
        scalar(@entries));
  } elsif (scalar(@{$indices}) > 1) {
    my $result = {};
    my @sortedindices = $self->sort_indices($indices);
    my $startindex = $sortedindices[0];
    my $endindex = $sortedindices[$#sortedindices];
    if (0) {
      # holzweg. dicke ciscos liefern unvollstaendiges resultat, d.h.
      # bei 138,19,157 kommt nur 138..144, dann ist schluss.
      # maxrepetitions bringt nichts.
      #$result = $self->get_entries(
      #    -startindex => $startindex,
      #    -endindex => $endindex,
      #    -columns => \@columns,
      #);
      # anderer ansatz. zusammenhaengende sequenzen suchen und dann
      # mehrere bulkwalks absetzen. bringt aber nichts, wenn die indices
      # wild verstreut sind
      my @sequences = ();
      my $sequence;
      foreach my $idx (0..scalar(@sortedindices)-1) {
        if ($idx != 0 && $sortedindices[$idx] == $sortedindices[$idx-1]+1) {
          push(@{$sequence}, $sortedindices[$idx]);
        } else {
          $sequence = [$sortedindices[$idx]];
          push(@sequences, $sequence);
        }
      }
      foreach my $sequence (@sequences) {
        my $startindex = $sequence->[0];
        my $endindex = $sequence->[-1];
        my $tmp_result = $self->get_entries(
            -startindex => $startindex,
            -endindex => $endindex,
            -columns => \@columns,
        );
        while (my ($key, $value) = each %{$tmp_result}) {
          $result->{$key} = $value;
        }
      }
    } else {
      foreach my $idx (@sortedindices) {
        my $tmp_result = $self->get_entries(
            -startindex => $idx,
            -endindex => $idx,
            -columns => \@columns,
        );
        while (my ($key, $value) = each %{$tmp_result}) {
          $result->{$key} = $value;
        }
      }
    }
    foreach (@augmenting) {
      my($augmenting_tableoid, @augmenting_columns) = ($_->[0], @{$_->[1]});
      foreach my $idx (@sortedindices) {
        my $tmp_result = $self->get_entries(
            -startindex => $idx,
            -endindex => $idx,
            -columns => \@augmenting_columns,
        );
        while (my ($key, $value) = each %{$tmp_result}) {
          $result->{$key} = $value;
        }
      }
    }
    # now we have numerical_oid+index => value
    # needs to become symboic_oid => value
    @entries = map {
        $_->{indices} = shift @{$indices}; $_
    } $self->make_symbolic($mib, $result, $indices, $sym_lookup);
    $self->debug(sprintf "get_snmp_table_objects single returns %d entries",
        scalar(@entries));
  } elsif (scalar(@{$rows})) {
    my $result = $self->get_entries(
        -columns => \@columns,
    );
    foreach (@augmenting) {
      my($augmenting_tableoid, @augmenting_columns) = ($_->[0], @{$_->[1]});
      my $augmenting_result = $self->get_entries(
          -columns => \@augmenting_columns,
      );
      while (my ($key, $value) = each %{$augmenting_result}) {
        $result->{$key} = $value;
      }
    }
    my @indices =
        $self->get_indices(
            -baseoid => $entryoid,
            -oids => [keys %{$result}]);
    @entries = map {
        $_->{indices} = shift @indices; $_
    } $self->make_symbolic($mib, $result, \@indices, $sym_lookup);
    $self->debug(sprintf "get_snmp_table_objects rows returns %d entries",
        scalar(@entries));
  } else {
    my $result = $self->get_table(
        -baseoid => $tableoid,
    );
    foreach (@augmenting) {
      my($augmenting_tableoid, @augmenting_columns) = ($_->[0], @{$_->[1]});
      my $augmenting_result = $self->get_table(
          -baseoid => $augmenting_tableoid,
      );
      while (my ($key, $value) = each %{$augmenting_result}) {
        $result->{$key} = $value;
      }
    }
    # now we have numerical_oid+index => value
    # needs to become symboic_oid => value
    my @indices = 
        $self->get_indices(
            -baseoid => $entryoid,
            -oids => [keys %{$result}]);
    @entries = map {
        $_->{indices} = shift @indices; $_
    } $self->make_symbolic($mib, $result, \@indices, $sym_lookup);
    $self->debug(sprintf "get_snmp_table_objects default returns %d entries",
        scalar(@entries));
  }
  @entries = map { $_->{flat_indices} = join(".", @{$_->{indices}}); $_ } @entries;
  return @entries;
}

################################################################
# 3rd level functions. calling net::snmp-functions
# 
sub get_request {
  my ($self, %params) = @_;
  my @notcached = ();
  foreach my $oid (@{$params{'-varbindlist'}}) {
    $self->add_oidtrace($oid);
    if (! exists $Monitoring::GLPlugin::SNMP::rawdata->{$oid}) {
      push(@notcached, $oid);
    }
  }
  if (! $self->opts->snmpwalk && (scalar(@notcached) > 0)) {
    my %params = ();
    if ($Monitoring::GLPlugin::SNMP::session->version() == 0) {
      $params{-varbindlist} = \@notcached;
    } elsif ($Monitoring::GLPlugin::SNMP::session->version() == 1) {
      $params{-varbindlist} = \@notcached;
      #$params{-nonrepeaters} = scalar(@notcached);
    } elsif ($Monitoring::GLPlugin::SNMP::session->version() == 3) {
      $params{-varbindlist} = \@notcached;
      $params{-contextengineid} = $self->opts->contextengineid if $self->opts->contextengineid;
      $params{-contextname} = $self->opts->contextname if $self->opts->contextname;
    }
    my $result = $Monitoring::GLPlugin::SNMP::session->get_request(%params);
    # so, und jetzt gibts stinkstiefel, die kriegen
    # params{-varbindlist => [1.3.6.1.4.1.318.1.1.1.1.1.1]
    # und result ist
    # { 1.3.6.1.4.1.318.1.1.1.1.1.1.0 => "Smart-UPS RT 10000 XL" }
    # letzteres kommt in raw_data
    # und beim abschliessenden map wirds natuerlich nicht mehr gefunden 
    # also leeres return. <<kraftausdruck>>
    while (my ($key, $value) = each %{$result}) {
      # so, und zwei jahre spaeter kommt man drauf, dass es viele sorten 
      # von stinkstiefeln gibt. die fragt man nach 1.3.6.1.4.1.13885.120.1.3.1
      # und kriegt als antwort 1.3.6.1.4.1.13885.120.1.3.1.0=[noSuchInstance]
      # bis zum 11.10.16 wurde das in den cache geschrieben. eine etage hoeher
      # wird aber dann nach 1.3.6.1.4.1.13885.120.1.3.1.0 gefallbacked, was
      # dann prompt aus dem cache gefischt wird, anstatt den agenten zu fragen,
      # der in diesem fall eine saubere antwort liefern wuerde.
      # ergo: keine fehlermeldungen in den chache
      $self->add_rawdata($key, $value) if defined $value && $value ne 'noSuchInstance';
    }
  }
  my $result = {};
  map {
      $result->{$_} = exists $Monitoring::GLPlugin::SNMP::rawdata->{$_} ?
          $Monitoring::GLPlugin::SNMP::rawdata->{$_} :
      exists $Monitoring::GLPlugin::SNMP::rawdata->{$_.'.0'} ?
          $Monitoring::GLPlugin::SNMP::rawdata->{$_.'.0'} : undef;
  } @{$params{'-varbindlist'}};
  return $result;
}

sub get_entries_get_bulk {
  my ($self, %params) = @_;
  my $result = {};
  my %newparams = ();
  $newparams{'-startindex'} = $params{'-startindex'}
      if defined $params{'-startindex'};
  $newparams{'-endindex'} = $params{'-endindex'}
      if defined $params{'-endindex'};
  $newparams{'-columns'} = $params{'-columns'};
  if ($Monitoring::GLPlugin::SNMP::maxrepetitions) {
    $newparams{'-maxrepetitions'} = $Monitoring::GLPlugin::SNMP::maxrepetitions;
  } else {
    $newparams{'-maxrepetitions'} = 3;
  }
  $self->debug(sprintf "get_entries_get_bulk %s", Data::Dumper::Dumper(\%newparams));
  if ($Monitoring::GLPlugin::SNMP::session->version() == 3) {
    $newparams{-contextengineid} = $self->opts->contextengineid if $self->opts->contextengineid;
    $newparams{-contextname} = $self->opts->contextname if $self->opts->contextname;
  }
  delete $newparams{'-maxrepetitions'}; # bulk howe gsagt!!
  $result = $Monitoring::GLPlugin::SNMP::session->get_entries(%newparams);
  return $result;
}

sub get_entries_get_next {
  my ($self, %params) = @_;
  my $result = {};
  my %newparams = ();
  $newparams{'-maxrepetitions'} = 0;
  $newparams{'-startindex'} = $params{'-startindex'}
      if defined $params{'-startindex'};
  $newparams{'-endindex'} = $params{'-endindex'}
      if defined $params{'-endindex'};
  $newparams{'-columns'} = $params{'-columns'};
  $self->debug(sprintf "get_entries_get_next %s", Data::Dumper::Dumper(\%newparams));
  if ($Monitoring::GLPlugin::SNMP::session->version() == 3) {
    $newparams{-contextengineid} = $self->opts->contextengineid if $self->opts->contextengineid;
    $newparams{-contextname} = $self->opts->contextname if $self->opts->contextname;
  }
  $result = $Monitoring::GLPlugin::SNMP::session->get_entries(%newparams);
  return $result;
}

sub get_entries_get_next_1index {
  my ($self, %params) = @_;
  my $result = {};
  my %newparams = ();
  $newparams{'-startindex'} = $params{'-startindex'}
      if defined $params{'-startindex'};
  $newparams{'-endindex'} = $params{'-endindex'}
      if defined $params{'-endindex'};
  $newparams{'-columns'} = $params{'-columns'};
  $self->debug(sprintf "get_entries_get_next_1index %s", Data::Dumper::Dumper(\%newparams));
  my %singleparams = ();
  $singleparams{'-maxrepetitions'} = 0;
  if ($Monitoring::GLPlugin::SNMP::session->version() == 3) {
    $singleparams{-contextengineid} = $self->opts->contextengineid if $self->opts->contextengineid;
    $singleparams{-contextname} = $self->opts->contextname if $self->opts->contextname;
  }
  foreach my $index ($newparams{'-startindex'}..$newparams{'-endindex'}) {
    foreach my $oid (@{$newparams{'-columns'}}) {
      $singleparams{'-columns'} = [$oid];
      $singleparams{'-startindex'} = $index;
      $singleparams{'-endindex'} =$index;
      my $singleresult = $Monitoring::GLPlugin::SNMP::session->get_entries(%singleparams);
      while (my ($key, $value) = each %{$singleresult}) {
        $result->{$key} = $value;
      }
    }
  }
  return $result;
}

sub get_entries_get_simple {
  my ($self, %params) = @_;
  my $result = {};
  my %newparams = ();
  $newparams{'-startindex'} = $params{'-startindex'}
      if defined $params{'-startindex'};
  $newparams{'-endindex'} = $params{'-endindex'}
      if defined $params{'-endindex'};
  $newparams{'-columns'} = $params{'-columns'};
  $self->debug(sprintf "get_entries_get_simple %s", Data::Dumper::Dumper(\%newparams));
  my %singleparams = ();
  if ($Monitoring::GLPlugin::SNMP::session->version() == 3) {
    $singleparams{-contextengineid} = $self->opts->contextengineid if $self->opts->contextengineid;
    $singleparams{-contextname} = $self->opts->contextname if $self->opts->contextname;
  }
  foreach my $index ($newparams{'-startindex'}..$newparams{'-endindex'}) {
    foreach my $oid (@{$newparams{'-columns'}}) {
      $singleparams{'-varbindlist'} = [$oid.".".$index];
      my $singleresult = $Monitoring::GLPlugin::SNMP::session->get_request(%singleparams);
      while (my ($key, $value) = each %{$singleresult}) {
        if ($value eq "noSuchObject" ||
            $value eq "noSuchInstance" ||
            $value eq "endOfMibView") {
          $result->{$key} = undef;
        } else {
          $result->{$key} = $value;
        }
      }
    }
  }
  return $result;
}

sub get_entries {
  my ($self, %params) = @_;
  # [-startindex]
  # [-endindex]
  # -columns
  $params{'-columns'} = [$self->sort_oids($params{'-columns'})];
  my $result = {};
  $self->debug(sprintf "get_entries %s", Data::Dumper::Dumper(\%params));
  if (! $self->opts->snmpwalk) {
    if (scalar (@{$params{'-columns'}}) < 5 && $params{'-endindex'} && $params{'-startindex'} eq $params{'-endindex'}) {
      $result = $self->get_entries_get_simple(%params);
    } else {
      $result = $self->get_entries_get_bulk(%params);
      if (! $result) {
        $self->debug("bulk failed, retry simple");
        # The message size exceeded the buffer maxMsgSize of (\d+)
        # Message size exceeded buffer maxMsgSize
        if ($Monitoring::GLPlugin::SNMP::session->error() =~ /message size exceeded.*buffer maxMsgSize/i) {
          # old methos. might be no good idea for wan
          #$self->debug(sprintf "buffer exceeded. raise *5 for next try");
          #$self->mult_snmp_max_msg_size(5);
          $self->debug(sprintf "buffer exceeded. lower repetitions for next try");
          $self->bulk_is_baeh($self->get_max_repetitions() * 0.75);
        } elsif ($Monitoring::GLPlugin::SNMP::session->error() =~ /Authentication failure/ && $Monitoring::GLPlugin::SNMP::session->max_msg_size() > 10) {
          $self->debug("A so a Rimbfiech, so a saudumms. Aaf oamol kennda me nimmer");
          # australische Nexus. Bulkwalk mit hochgedrehten max_repetitions (*128)
          # fuehrt so so einem fake Authentication failure
          $self->mult_snmp_max_msg_size(5);
          $result = $self->get_entries(%params);
        } else {
          $self->debug($Monitoring::GLPlugin::SNMP::session->error());
        }
        if ($result) {
          # Rimbfiech fallback was successful
        } elsif (defined $params{'-endindex'} && defined $params{'-startindex'}) {
          $result = $self->get_entries_get_simple(%params);
        } else {
          $result = $self->get_entries_get_next(%params);
        }
      }
    }
    if (! $result) {
      $result = $self->get_entries_get_next(%params);
      if (! $result && defined $params{'-startindex'} && $params{'-startindex'} !~ /\./) {
        # compound indexes cannot continue, as these two methods iterate numerically
        if ($Monitoring::GLPlugin::SNMP::session->error() =~ /tooBig/i) {
          $self->debug(sprintf "answer too big");
          $result = $self->get_entries_get_next_1index(%params);
        }
        if (! $result) {
          $result = $self->get_entries_get_simple(%params);
        }
        if (! $result) {
          $self->debug(sprintf "nutzt nix\n");
        }
      }
    }
    foreach my $key (keys %{$result}) {
      if (substr($key, -1) eq " ") {
        my $value = $result->{$key};
        delete $result->{$key};
        $key =~ s/\s+$//g;
        $result->{$key} = $value;
        #
        # warum?
        #
        # %newparams ist:
        #  '-columns' => [
        #                  '1.3.6.1.2.1.2.2.1.8',
        #                  '1.3.6.1.2.1.2.2.1.13',
        #                  ...
        #                  '1.3.6.1.2.1.2.2.1.16'
        #                ],
        #  '-startindex' => '2',
        #  '-endindex' => '2'
        #
        # und $result ist:
        #  ...
        #  '1.3.6.1.2.1.2.2.1.2.2' => 'Adaptive Security Appliance \'outside\' interface',
        #  '1.3.6.1.2.1.2.2.1.16.2 ' => 4281465004,
        #  '1.3.6.1.2.1.2.2.1.13.2' => 0,
        #  ...
        #
        # stinkstiefel!
        #
      }
      $self->add_rawdata($key, $result->{$key});
    }
  } else {
    my $preresult = $self->get_matching_oids(
        -columns => $params{'-columns'});
    while (my ($key, $value) = each %{$preresult}) {
      $result->{$key} = $value;
    }
    my @sortedkeys = $self->sort_oids([keys %{$result}]);
    my @to_del = ();
    if ($params{'-startindex'}) {
      foreach my $resoid (@sortedkeys) {
        foreach my $oid (@{$params{'-columns'}}) {
          my $poid = $oid.'.';
          my $lpoid = length($poid);
          if (substr($resoid, 0, $lpoid) eq $poid) {
            my $oidpattern = $poid;
            $oidpattern =~ s/\./\\./g;
            if ($resoid =~ /^$oidpattern(.+)$/) {
              if ($1 lt $params{'-startindex'}) {
                push(@to_del, $oid.'.'.$1);
              }
            }
          }
        }
      }
    }
    if ($params{'-endindex'}) {
      foreach my $resoid (@sortedkeys) {
        foreach my $oid (@{$params{'-columns'}}) {
          my $poid = $oid.'.';
          my $lpoid = length($poid);
          if (substr($resoid, 0, $lpoid) eq $poid) {
            my $oidpattern = $poid;
            $oidpattern =~ s/\./\\./g;
            if ($resoid =~ /^$oidpattern(.+)$/) {
              if ($1 gt $params{'-endindex'}) {
                push(@to_del, $oid.'.'.$1);
              }
            }
          }
        }
      }
    }
    foreach (@to_del) {
      delete $result->{$_};
    }
  }
  return $result;
}

sub get_entries_by_walk {
  my ($self, %params) = @_;
  if (! $self->opts->snmpwalk) {
    $self->add_ok("if you get this crap working correctly, let me know");
    if ($Monitoring::GLPlugin::SNMP::session->version() == 3) {
      $params{-contextengineid} = $self->opts->contextengineid if $self->opts->contextengineid;
      $params{-contextname} = $self->opts->contextname if $self->opts->contextname;
    }
    $self->debug(sprintf "get_tree %s", Data::Dumper::Dumper(\%params));
    my @baseoids = @{$params{-varbindlist}};
    delete $params{-varbindlist};
    if ($Monitoring::GLPlugin::SNMP::session->version() == 0) {
      foreach my $baseoid (@baseoids) {
        $params{-varbindlist} = [$baseoid];
        while (my $result = $Monitoring::GLPlugin::SNMP::session->get_next_request(%params)) {
          $params{-varbindlist} = [($Monitoring::GLPlugin::SNMP::session->var_bind_names)[0]];
        }
      }
    } else {
      $params{-maxrepetitions} = 200;
      foreach my $baseoid (@baseoids) {
        $params{-varbindlist} = [$baseoid];
        while (my $result = $Monitoring::GLPlugin::SNMP::session->get_bulk_request(%params)) {
          my @names = $Monitoring::GLPlugin::SNMP::session->var_bind_names();
          my @oids = $self->sort_oids(\@names);
          foreach (keys %{$result}) {
            $self->add_rawdata($_, $result->{$_});
          }
          $params{-varbindlist} = [pop @oids];
        }
      }
    }
  } else {
    return $self->get_matching_oids(
        -columns => $params{-varbindlist});
  }
}

sub get_table {
  my ($self, %params) = @_;
  my $tic;
  my $tac;
  $self->add_oidtrace($params{'-baseoid'});
  if (! $self->opts->snmpwalk) {
    my @notcached = ();
    if ($Monitoring::GLPlugin::SNMP::session->version() == 3) {
      $params{-contextengineid} = $self->opts->contextengineid if $self->opts->contextengineid;
      $params{-contextname} = $self->opts->contextname if $self->opts->contextname;
    }
    if ($Monitoring::GLPlugin::SNMP::maxrepetitions) {
      # some devices (Bintec) don't like bulk-requests. They call bulk_is_baeh(), so
      # we immediately send get-next
      $params{'-maxrepetitions'} = $Monitoring::GLPlugin::SNMP::maxrepetitions;
    }
    $self->debug(sprintf "get_table %s", Data::Dumper::Dumper(\%params));
    $tic = time;
    my $result = $Monitoring::GLPlugin::SNMP::session->get_table(%params);
    $tac = time;
    if (! defined $result || (defined $result && ! %{$result})) {
      $self->debug(sprintf "get_table error: %s", 
          $Monitoring::GLPlugin::SNMP::session->error());
      my $fallback = 0;
      if ($Monitoring::GLPlugin::SNMP::session->error() =~ /message size exceeded.*buffer maxMsgSize/i) {
        # bei irrsinnigen maxrepetitions
        $self->debug(sprintf "buffer exceeded");
        #$self->reset_snmp_max_msg_size();
        if ($params{'-maxrepetitions'}) {
          $params{'-maxrepetitions'} = int($params{'-maxrepetitions'} / 2);
          $self->debug(sprintf "reduce maxrepetitions to %d",
              $params{'-maxrepetitions'});
        } else {
          $self->mult_snmp_max_msg_size(2);
        }
        $fallback = 1;
      } elsif ($Monitoring::GLPlugin::SNMP::session->error() =~ /No response from remote host/i) {
        # some agents can not handle big loads
        if ($params{'-maxrepetitions'}) {
          $params{'-maxrepetitions'} = int($params{'-maxrepetitions'} / 2);
          $self->debug(sprintf "reduce maxrepetitions to %d",
              $params{'-maxrepetitions'});
          $fallback = 1;
        }
      }
      if ($fallback) {
        $self->debug("get_table error: try fallback");
        $self->debug(sprintf "get_table %s", Data::Dumper::Dumper(\%params));
        $tic = time;
        $result = $Monitoring::GLPlugin::SNMP::session->get_table(%params);
        $tac = time;
        $self->debug(sprintf "get_table returned %d oids in %ds", scalar(keys %{$result}), $tac - $tic);
      }
      if (! defined $result || ! %{$result}) {
        $self->debug(sprintf "get_table error: %s", 
            $Monitoring::GLPlugin::SNMP::session->error());
        if (exists $params{'-maxrepetitions'} && $params{'-maxrepetitions'} > 1) {
          $params{'-maxrepetitions'} = 1;
          $self->debug("get_table error: try getnext fallback");
          $self->debug(sprintf "get_table %s", Data::Dumper::Dumper(\%params));
          $tic = time;
          $result = $Monitoring::GLPlugin::SNMP::session->get_table(%params);
          $tac = time;
          $self->debug(sprintf "get_table returned %d oids in %ds", scalar(keys %{$result}), $tac - $tic);
        }
        if (! defined $result || ! %{$result}) {
          $self->debug("get_table error: no more fallbacks. Try --protocol 1");
        }
      }
    }
    $result = {} if ! defined $result;
    # Drecksstinkstiefel Net::SNMP
    # '1.3.6.1.2.1.2.2.1.22.4 ' => 'endOfMibView',
    # '1.3.6.1.2.1.2.2.1.22.4' => '0.0',
    my $num_rows = 0;
    my @blank_keys = ();
    while (my ($key, $value) = each %{$result}) {
      $num_rows++;
      if (substr($key, -1) eq " ") {
        push(@blank_keys, $key);
      } else {
        $self->add_rawdata($key, $value);
      }
    }
    $self->debug(sprintf "get_table returned %d oids in %ds", $num_rows, $tac - $tic);
    foreach my $key (@blank_keys) {
      my $value = $result->{$key};
      delete $result->{$key};
      (my $shortkey = $key) =~ s/\s+$//g;
      if (! exists $result->{shortkey}) {
        $self->add_rawdata($shortkey, $value);
      }
    }
  }
  return $self->get_matching_oids(
      -columns => [$params{'-baseoid'}]);
}

################################################################
# helper functions
# 
sub valid_response {
  my ($self, $mib, $mo, $index) = @_;
  $self->require_mib($mib);
  if (exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib} &&
      exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$mo}) {
    # make it numerical
    my $oid = $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$mo};
    if (defined $index) {
      $oid .= '.'.$index;
    }
    my $result = $self->get_request(
        -varbindlist => [$oid]
    );
    if (! defined($result) ||
        ! defined $result->{$oid} ||
        $result->{$oid} eq 'noSuchInstance' ||
        $result->{$oid} eq 'noSuchObject' ||
        $result->{$oid} eq 'endOfMibView') {
      $self->debug(sprintf "GET: %s::%s (%s) : %s", $mib, $mo, $oid, defined $result->{$oid} ? $result->{$oid} : "<undef>");
      return undef;
    } else {
      $self->debug(sprintf "GET: %s::%s (%s) : %s", $mib, $mo, $oid, defined $result->{$oid} ? $result->{$oid} : "<undef>");
      $self->add_rawdata($oid, $result->{$oid});
      return $result->{$oid};
    }
  } else {
    return undef;
  }
}

sub get_symbol {
  my ($self, $mib, $oid) = @_;
  # "LIEBERT-GP-ENVIRONMENTAL-MIB", "1.3.6.1.4.1.476.1.42.3.4.1.1.4"
  # dahinter steckt
  # lgpEnvSupplyAirTemperature => '1.3.6.1.4.1.476.1.42.3.4.1.1.3'
  # lgpAmbientTemperature => '1.3.6.1.4.1.476.1.42.3.4.1.1.4'
  # und als info vom geraet
  # LgpEnvTemperatureMeasurementDegC = '1.3.6.1.4.1.476.1.42.3.4.1.1.4'
  # der name des temp. sensor wird ueber die oid mitgeteilt
  $self->require_mib($mib);
  $oid =~ s/^\.//g;
  foreach my $symoid
      (keys %{$Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}}) {
    if ($oid eq $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid}) {
      return $symoid;
    }
  }
  return undef;
}

# make_symbolic
# mib is the name of a mib (must be in mibs_and_oids)
# result is a hash-key oid->value
# indices is a array ref of array refs. [[1],[2],...] or [[1,0],[1,1],[2,0]..
sub make_symbolic {
  my ($self, $mib, $result, $indices, $sym_lookup) = @_;
  $self->require_mib($mib);
  my @entries = ();
  if (! wantarray && ref(\$result) eq "SCALAR" && ref(\$indices) eq "SCALAR") {
    # $self->make_symbolic('CISCO-IETF-NAT-MIB', 'cnatProtocolStatsName', $self->{cnatProtocolStatsName});
    my $oid = $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$result};
    $result = { $oid => $self->{$result} };
    $indices = [[]];
  }
  foreach my $index (@{$indices}) {
    # skip [], [[]], [[undef]]
    if (ref($index) eq "ARRAY") {
      if (scalar(@{$index}) == 0) {
        next;
      } elsif (!defined $index->[0]) {
        next;
      }
    }
    my $mo = {};
    my $idx = join('.', @{$index}); # index can be multi-level
    if (! $sym_lookup) {
      foreach my $symoid
          (keys %{$Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}}) {
        my $oid = $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid};
        if (ref($oid) ne 'HASH') {
          my $fulloid = $oid . '.'.$idx;
          if (exists $result->{$fulloid}) {
            if (exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'}) {
              if (ref($Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'}) eq 'HASH') {
                if (exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'}->{$result->{$fulloid}}) {
                  $mo->{$symoid} = $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'}->{$result->{$fulloid}};
                } else {
                  $mo->{$symoid} = 'unknown_'.$result->{$fulloid};
                }
              } elsif ($Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'} =~ /^OID::(.*)/) {
                my $othermib = $1;
                if (! exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$othermib}) {
                  # may point to another mib's definitions, which hasn't
                  # been used yet.
                  $self->require_mib($othermib);
                }
                my $value_which_is_a_oid = $result->{$fulloid};
                $value_which_is_a_oid =~ s/^\.//g;
                my @result = grep { $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$othermib}->{$_} eq $value_which_is_a_oid } keys %{$Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$othermib}};
                if (scalar(@result)) {
                  $mo->{$symoid} = $result[0];
                } else {
                  $mo->{$symoid} = 'unknown_'.$result->{$fulloid};
                }
              } elsif ($Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'} =~ /^(.*?)::(.*)/) {
                my $mib = $1;
                my $definition = $2;
                my $parameters = undef;
                if ($definition =~ /(.*)\((.*)\)/) {
                  $definition = $1;
                  $parameters = $2;
                }
                if (! exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}) {
                  # may point to another mib's definitions, which hasn't
                  # been used yet.
                  $self->require_mib($mib);
                }
                if  (exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib} &&
                    exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition} &&
                    ref($Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}) eq 'CODE') {
                  if ($parameters) {
                    my @args = ($result->{$fulloid});
                    foreach my $parameter (split(",", $parameters)) {
                      if (! exists $mo->{$parameter}) {
                        # this happens if there are two isolated get_snmp_object calls, one for
                        # cLHaPeerIpAddressType and one for cLHaPeerIpAddress where the latter needs
                        # the symbolized value of the first. we are inside this index-loop because
                        # both have this usual extra .0 although this is not a table row.
                        # if this were a table row, $mo would know cLHaPeerIpAddressType.
                        # there's a chance that $self got cLHaPeerIpAddressType in a previous call
                        # to make_symbolic
                        if (@{$indices} and scalar(@{$indices}) == 1 and ! $indices->[0]->[0]) {
                          $mo->{$parameter} = $self->{$parameter};
                        }
                      }
                      push(@args, $mo->{$parameter});
                    }
                    $mo->{$symoid} = $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}->(@args);
                  } else {
                    $mo->{$symoid} = $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}->($result->{$fulloid});
                  }
                } elsif  (exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib} &&
                    exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition} &&
                    ref($Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}) eq 'HASH' &&
                    exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}->{$result->{$fulloid}}) {
                  $mo->{$symoid} = $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}->{$result->{$fulloid}};
                } else {
                  $mo->{$symoid} = 'unknown_'.$result->{$fulloid};
                }
              } else {
                $mo->{$symoid} = 'unknown_'.$result->{$fulloid};
                # oder $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'}?
              }
            } else {
              $mo->{$symoid} = $result->{$fulloid};
            }
          }
        }
      }
    } else {
      my @sym_lookup_keys = $self->sort_oids([keys %{$sym_lookup}]);
      foreach my $oid (@sym_lookup_keys) {
        if (ref($oid) ne 'HASH') {
          my $fulloid = $oid . '.'.$idx;
          my $symoid = $sym_lookup->{$oid};
          if (exists $result->{$fulloid}) {
            if (exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'}) {
              if (ref($Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'}) eq 'HASH') {
                if (exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'}->{$result->{$fulloid}}) {
                  $mo->{$symoid} = $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'}->{$result->{$fulloid}};
                } else {
                  $mo->{$symoid} = 'unknown_'.$result->{$fulloid};
                }
              } elsif ($Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'} =~ /^OID::(.*)/) {
                my $othermib = $1;
                if (! exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$othermib}) {
                  # may point to another mib's definitions, which hasn't
                  # been used yet.
                  $self->require_mib($othermib);
                }
                my $value_which_is_a_oid = $result->{$fulloid};
                $value_which_is_a_oid =~ s/^\.//g;
                my @result = grep { $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$othermib}->{$_} eq $value_which_is_a_oid } keys %{$Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$othermib}};
                if (scalar(@result)) {
                  $mo->{$symoid} = $result[0];
                } else {
                  $mo->{$symoid} = 'unknown_'.$result->{$fulloid};
                }
              } elsif ($Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'} =~ /^(.*?)::(.*)/) {
                my $mib = $1;
                my $definition = $2;
                my $parameters = undef;
                if ($definition =~ /(.*)\((.*)\)/) {
                  $definition = $1;
                  $parameters = $2;
                }
                if (! exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}) {
                  # may point to another mib's definitions, which hasn't
                  # been used yet.
                  $self->require_mib($mib);
                }
                if  (exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib} &&
                    exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition} &&
                    ref($Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}) eq 'CODE') {
                  if ($parameters) {
                    my @args = ($result->{$fulloid});
                    foreach my $parameter (split(",", $parameters)) {
                      if (! exists $mo->{$parameter}) {
                        if (@{$indices} and scalar(@{$indices}) == 1 and ! $indices->[0]->[0]) {
                          $mo->{$parameter} = $self->{$parameter};
                        }
                      }
                      push(@args, $mo->{$parameter});
                    }
                    $mo->{$symoid} = $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}->(@args);
                  } else {
                    $mo->{$symoid} = $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}->($result->{$fulloid});
                  }
                } elsif  (exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib} &&
                    exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition} &&
                    ref($Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}) eq 'HASH' &&
                    exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}->{$result->{$fulloid}}) {
                  $mo->{$symoid} = $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}->{$result->{$fulloid}};
                } else {
                  $mo->{$symoid} = 'unknown_'.$result->{$fulloid};
                }
              } else {
                $mo->{$symoid} = 'unknown_'.$result->{$fulloid};
                # oder $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'}?
              }
            } else {
              $mo->{$symoid} = $result->{$fulloid};
            }
          }
        }
      }
    }
    push(@entries, $mo);
  }
  if (@{$indices} and scalar(@{$indices}) == 1 and !defined $indices->[0]->[0]) {
    my $mo = {};
    my @lookup_keys = ();
    if (! $sym_lookup) {
      @lookup_keys = keys %{$Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}};
    } else {
      @lookup_keys = values %{$sym_lookup};
    }
    foreach my $symoid (@lookup_keys) {
      my $oid = $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid};
      if (ref($oid) ne 'HASH') {
        if (exists $result->{$oid}) {
          if (exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'}) {
            if (ref($Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'}) eq 'HASH') {
              if (exists $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'}->{$result->{$oid}}) {
                $mo->{$symoid} = $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'}->{$result->{$oid}};
                push(@entries, $mo);
              }
            } elsif ($Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'} =~ /^(.*?)::(.*)/) {
              my $mib = $1;
              my $definition = $2;
              my $parameters = undef;
              if ($definition =~ /(.*)\((.*)\)/) {
                $definition = $1;
                $parameters = $2;
              }
              if  (exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib} &&
                  exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition} &&
                  ref($Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}) eq 'CODE') {
                if ($parameters) {
                  # we come here fo resolve single oids, so $mo is always initialized new here.
                  # there's a chance that $self->{$parameters} was queried in a previous call
                  if (! exists $mo->{$parameters}) {
                    $mo->{$parameters} = $self->{$parameters};
                  }
                  $mo->{$symoid} = $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}->($result->{$oid}, $mo->{$parameters});
                } else {
                  $mo->{$symoid} = $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}->($result->{$oid});
                }
              } elsif  (exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib} &&
                  exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition} &&
                  ref($Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}) eq 'HASH' &&
                  exists $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}->{$result->{$oid}}) {
                $mo->{$symoid} = $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{$mib}->{$definition}->{$result->{$oid}};
              } else {
                $mo->{$symoid} = 'unknown_'.$result->{$oid};
              }
            } else {
              $mo->{$symoid} = 'unknown_'.$result->{$oid};
              # oder $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$symoid.'Definition'}?
            }
          } else {
            $mo->{$symoid} = $result->{$oid};
          }
        }
      }
    }
    push(@entries, $mo) if keys %{$mo};
  }
  if (wantarray) {
    return @entries;
  } else {
    foreach my $entry (@entries) {
      foreach my $key (keys %{$entry}) {
        $self->{$key} = $entry->{$key};
      }
    }
  }
}

sub sort_oids {
  my ($self, $oids) = @_;
  $oids ||= [];
  my @sortedkeys = map { $_->[0] }
      sort { $a->[1] cmp $b->[1] }
          map { [$_,
                  join '', map { sprintf("%30d",$_) } split( /\./, $_)
                ] } @{$oids};
  return @sortedkeys;
}

sub sort_indices {
  my ($self, $indices) = @_;
  my @sortedindices = map { $_->[0] } 
      sort { $a->[1] cmp $b->[1] } 
          map { [$_, 
              join '', map { sprintf("%30d",$_) } split( /\./, $_) 
          ] } map { join('.', @{$_})} @{$indices}; 
  return @sortedindices;
}


sub get_matching_oids {
  my ($self, %params) = @_;
  my $result = {};
  $self->debug(sprintf "get_matching_oids %s", Data::Dumper::Dumper(\%params));
  foreach my $oid (@{$params{'-columns'}}) {
    while (my ($key, $value) = each %{$Monitoring::GLPlugin::SNMP::rawdata}) {
      # oid 1.3.6.1.4.1.9999.12.3.4
      # raw 1.3.6.1.4.1.9999.12.3.4.2.3
      # raw 1.3.6.1.4.1.9999.12.3.41.10.2
      # raw 1.3.6.1.4.1.9999.12.3.4
      if (rindex($key, $oid, 0) == 0) {
        my $len = length($oid);
        if ($len == length($key)) {
          $result->{$key} = $value;
        } elsif (substr($key, $len, 1) eq ".") {
          $result->{$key} = $value;
        }
      }
    }
    #my $oidpattern = $oid;
    #$oidpattern =~ s/\./\\./g;
    #map { $result->{$_} = $Monitoring::GLPlugin::SNMP::rawdata->{$_} }
    #    grep /^$oidpattern(?=\.|$)/, keys %{$Monitoring::GLPlugin::SNMP::rawdata};
  }
  $self->debug(sprintf "get_matching_oids returns %d from %d oids", 
      scalar(keys %{$result}), scalar(keys %{$Monitoring::GLPlugin::SNMP::rawdata}));
  return $result;
}

sub get_indices {
  my ($self, %params) = @_;
  # -baseoid : entry
  # find all oids beginning with $entry
  # then skip one field for the sequence
  # then read the next numindices fields
  my $entry = $params{'-baseoid'};
  my $entrypat = $entry;
  my %seen = ();
  $entrypat =~ s/\./\\\./g;
  map {
      $seen{$1} = 1 if /^$entrypat\.\d+\.(.*)/;
  } grep {
      rindex($_, $entry) == 0;
  } keys %{$Monitoring::GLPlugin::SNMP::rawdata};
  my @o = map {[split /\./]} sort keys %seen;
  return @o;
}

# this flattens a n-dimensional array and returns the absolute position
# of the element at position idx1,idx2,...,idxn
# element 1,2 in table 0,0 0,1 0,2 1,0 1,1 1,2 2,0 2,1 2,2 is at pos 6
sub get_number {
  my ($self, $indexlists, @element) = @_;
  # $indexlists = zeiger auf array aus [1, 2]
  my $dimensions = scalar(@{$indexlists->[0]});
  my @sorted = ();
  my $number = 0;
  if ($dimensions == 1) {
    @sorted =
        sort { $a->[0] <=> $b->[0] } @{$indexlists};
  } elsif ($dimensions == 2) {
    @sorted =
        sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } @{$indexlists};
  } elsif ($dimensions == 3) {
    @sorted =
        sort { $a->[0] <=> $b->[0] ||
               $a->[1] <=> $b->[1] ||
               $a->[2] <=> $b->[2] } @{$indexlists};
  }
  foreach (@sorted) {
    if ($dimensions == 1) {
      if ($_->[0] == $element[0]) {
        last;
      }
    } elsif ($dimensions == 2) {
      if ($_->[0] == $element[0] && $_->[1] == $element[1]) {
        last;
      }
    } elsif ($dimensions == 3) {
      if ($_->[0] == $element[0] &&
          $_->[1] == $element[1] &&
          $_->[2] == $element[2]) {
        last;
      }
    }
    $number++;
  }
  return ++$number;
}

################################################################
# caching functions
# 
sub set_rawdata {
  my ($self, $rawdata) = @_;
  $Monitoring::GLPlugin::SNMP::rawdata = $rawdata;
}

sub add_rawdata {
  my ($self, $oid, $value) = @_;
  $Monitoring::GLPlugin::SNMP::rawdata->{$oid} = $value;
}

sub rawdata {
  my ($self) = @_;
  return $Monitoring::GLPlugin::SNMP::rawdata;
}

sub add_oidtrace {
  my ($self, $oid) = @_;
  $self->debug("cache: ".$oid);
  push(@{$Monitoring::GLPlugin::SNMP::oidtrace}, $oid);
}

#  $self->update_entry_cache(0, $mib, $table, $key_attr);
#  my @indices = $self->get_cache_indices();
sub get_cache_indices {
  my ($self, $mib, $table, $key_attr) = @_;
  # get_cache_indices is only used by get_snmp_table_objects_with_cache
  # so if we dont use --name returning all the indices would result
  # in a step-by-step get_table_objecs(index 1...n) which could take long
  # time when used with nexus or f5 pools
  # returning () forces get_snmp_table_objects to use get_tables
  return () if ! $self->opts->name;
  if (ref($key_attr) ne "ARRAY") {
    $key_attr = [$key_attr];
  }
  my $cache = sprintf "%s_%s_%s_cache", 
      $mib, $table, join('#', @{$key_attr});
  my @indices = ();
  foreach my $key (keys %{$self->{$cache}}) {
    my ($descr, $index) = split('-//-', $key, 2);
    if ($self->opts->name) {
      if ($self->opts->regexp) {
        my $pattern = $self->opts->name;
        if ($descr =~ /$pattern/i) {
          push(@indices, $self->{$cache}->{$key});
        }
      } else {
        if ($self->opts->name =~ /^\d+$/) {
          if ($index == 1 * $self->opts->name) {
            push(@indices, [1 * $self->opts->name]);
          }
        } else {
          if (lc $descr eq lc $self->opts->name) {
            push(@indices, $self->{$cache}->{$key});
          }
        }
      }
    } else {
      push(@indices, $self->{$cache}->{$key});
    }
  }
  return @indices;
  return map { join('.', ref($_) eq "ARRAY" ? @{$_} : $_) } @indices;
}

sub get_entities {
  my ($self, $class, $filter) = @_;
  foreach ($self->get_sub_table('ENTITY-MIB', [
    'entPhysicalDescr',
    'entPhysicalName',
    'entPhysicalClass',
  ])) {
    my $new_object = $class->new(%{$_});
    next if (defined $filter && ! &$filter($new_object));
    push @{$self->{entities}}, $new_object;
  }
}

sub get_sub_table {
  my ($self, $mib, $names) = @_;
  $self->require_mib($mib);
  my @oids = map {
    $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{$mib}->{$_}
  } @$names;
  my $result = $self->get_entries(
    -columns => \@oids
  );
  my $indices = ();
  map { if ($_ =~ /\.(\d+)$/) { $indices->{$1} = [ $1 ]; } } keys %$result;
  my @indices = values %$indices;
  my @entries = $self->make_symbolic($mib, $result, \@indices);
  @entries = map { $_->{indices} = shift @indices; $_ } @entries;
  @entries = map { $_->{flat_indices} = join(".", @{$_->{indices}}); $_ } @entries;
  return @entries;
}

sub join_table {
  my ($self, $to, $from) = @_;
  my $to_i = {};
  foreach (@$to) {
    my $i = $_->{flat_indices};
    $to_i->{$i} = $_;
  }
  foreach my $f (@$from) {
    my $i = $f->{flat_indices};
    if (exists $to_i->{$i}) {
      foreach (keys %$f) {
        next if $_ =~ /indices/;
        $to_i->{$i}->{$_} = $f->{$_};
      }
    }
  }
}


1;

__END__
