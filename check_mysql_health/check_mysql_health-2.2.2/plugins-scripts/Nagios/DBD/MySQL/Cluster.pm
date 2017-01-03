package DBD::MySQL::Cluster;

use strict;
use Time::HiRes;
use IO::File;
use Data::Dumper;

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

{
  our $verbose = 0;
  our $scream = 0; # scream if something is not implemented
  our $access = "dbi"; # how do we access the database. 
  our $my_modules_dyn_dir = ""; # where we look for self-written extensions

  my @clusters = ();
  my $initerrors = undef;

  sub add_cluster {
    push(@clusters, shift);
  }

  sub return_clusters {
    return @clusters;
  }
  
  sub return_first_cluster() {
    return $clusters[0];
  }

}

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    hostname => $params{hostname},
    port => $params{port},
    username => $params{username},
    password => $params{password},
    timeout => $params{timeout},
    warningrange => $params{warningrange},
    criticalrange => $params{criticalrange},
    version => 'unknown',
    nodes => [],
    ndbd_nodes => 0,
    ndb_mgmd_nodes => 0,
    mysqld_nodes => 0,
  };
  bless $self, $class;
  $self->init_nagios();
  if ($self->connect(%params)) {
    DBD::MySQL::Cluster::add_cluster($self);
    $self->init(%params);
  }
  return $self;
}

sub init {
  my $self = shift;
  my %params = @_;
  if ($self->{show}) {
    my $type = undef;
    foreach (split /\n/, $self->{show}) {
      if (/\[(\w+)\((\w+)\)\]\s+(\d+) node/) {
        $type = uc $2;
      } elsif (/id=(\d+)(.*)/) {
        push(@{$self->{nodes}}, DBD::MySQL::Cluster::Node->new(
            type => $type,
            id => $1,
            status => $2,
        ));
      }
    }
  } else {
  }
  if ($params{mode} =~ /^cluster::ndbdrunning/) {
    foreach my $node (@{$self->{nodes}}) {
      $node->{type} eq "NDB" && $node->{status} eq "running" && $self->{ndbd_nodes}++;
      $node->{type} eq "MGM" && $node->{status} eq "running" && $self->{ndb_mgmd_nodes}++;
      $node->{type} eq "API" && $node->{status} eq "running" && $self->{mysqld_nodes}++;
    }
  } else {
    printf "broken mode %s\n", $params{mode};
  }
}

sub dump {
  my $self = shift;
  my $message = shift || "";
  printf "%s %s\n", $message, Data::Dumper::Dumper($self);
}

sub nagios {
  my $self = shift;
  my %params = @_;
  my $dead_ndb = 0;
  my $dead_api = 0;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ /^cluster::ndbdrunning/) {
      foreach my $node (grep { $_->{type} eq "NDB"} @{$self->{nodes}}) {
        next if $params{selectname} && $params{selectname} ne $_->{id};
        if (! $node->{connected}) {
          $self->add_nagios_critical(
              sprintf "ndb node %d is not connected", $node->{id});
          $dead_ndb++;
        }
      }
      foreach my $node (grep { $_->{type} eq "API"} @{$self->{nodes}}) {
        next if $params{selectname} && $params{selectname} ne $_->{id};
        if (! $node->{connected}) {
          $self->add_nagios_critical(
              sprintf "api node %d is not connected", $node->{id});
          $dead_api++;
        }
      }
      if (! $dead_ndb) {
        $self->add_nagios_ok("all ndb nodes are connected");
      }
      if (! $dead_api) {
        $self->add_nagios_ok("all api nodes are connected");
      }
    }
  }
  $self->add_perfdata(sprintf "ndbd_nodes=%d ndb_mgmd_nodes=%d mysqld_nodes=%d",
      $self->{ndbd_nodes}, $self->{ndb_mgmd_nodes}, $self->{mysqld_nodes});
}


sub init_nagios {
  my $self = shift;
  no strict 'refs';
  if (! ref($self)) {
    my $nagiosvar = $self."::nagios";
    my $nagioslevelvar = $self."::nagios_level";
    $$nagiosvar = {
      messages => {
        0 => [],
        1 => [],
        2 => [],
        3 => [],
      },
      perfdata => [],
    };
    $$nagioslevelvar = $ERRORS{OK},
  } else {
    $self->{nagios} = {
      messages => {
        0 => [],
        1 => [],
        2 => [],
        3 => [],
      },
      perfdata => [],
    };
    $self->{nagios_level} = $ERRORS{OK},
  }
}

sub check_thresholds {
  my $self = shift;
  my $value = shift;
  my $defaultwarningrange = shift;
  my $defaultcriticalrange = shift;
  my $level = $ERRORS{OK};
  $self->{warningrange} = $self->{warningrange} ?
      $self->{warningrange} : $defaultwarningrange;
  $self->{criticalrange} = $self->{criticalrange} ?
      $self->{criticalrange} : $defaultcriticalrange;
  if ($self->{warningrange} !~ /:/ && $self->{criticalrange} !~ /:/) {
    # warning = 10, critical = 20, warn if > 10, crit if > 20
    $level = $ERRORS{WARNING} if $value > $self->{warningrange};
    $level = $ERRORS{CRITICAL} if $value > $self->{criticalrange};
  } elsif ($self->{warningrange} =~ /([\d\.]+):/ && 
      $self->{criticalrange} =~ /([\d\.]+):/) {
    # warning = 98:, critical = 95:, warn if < 98, crit if < 95
    $self->{warningrange} =~ /([\d\.]+):/;
    $level = $ERRORS{WARNING} if $value < $1;
    $self->{criticalrange} =~ /([\d\.]+):/;
    $level = $ERRORS{CRITICAL} if $value < $1;
  }
  return $level;
  #
  # syntax error must be reported with returncode -1
  #
}

sub add_nagios {
  my $self = shift;
  my $level = shift;
  my $message = shift;
  push(@{$self->{nagios}->{messages}->{$level}}, $message);
  # recalc current level
  foreach my $llevel (qw(CRITICAL WARNING UNKNOWN OK)) {
    if (scalar(@{$self->{nagios}->{messages}->{$ERRORS{$llevel}}})) {
      $self->{nagios_level} = $ERRORS{$llevel};
    }
  }
}

sub add_nagios_ok {
  my $self = shift;
  my $message = shift;
  $self->add_nagios($ERRORS{OK}, $message);
}

sub add_nagios_warning {
  my $self = shift;
  my $message = shift;
  $self->add_nagios($ERRORS{WARNING}, $message);
}

sub add_nagios_critical {
  my $self = shift;
  my $message = shift;
  $self->add_nagios($ERRORS{CRITICAL}, $message);
}

sub add_nagios_unknown {
  my $self = shift;
  my $message = shift;
  $self->add_nagios($ERRORS{UNKNOWN}, $message);
}

sub add_perfdata {
  my $self = shift;
  my $data = shift;
  push(@{$self->{nagios}->{perfdata}}, $data);
}

sub merge_nagios {
  my $self = shift;
  my $child = shift;
  foreach my $level (0..3) {
    foreach (@{$child->{nagios}->{messages}->{$level}}) {
      $self->add_nagios($level, $_);
    }
    #push(@{$self->{nagios}->{messages}->{$level}},
    #    @{$child->{nagios}->{messages}->{$level}});
  }
  push(@{$self->{nagios}->{perfdata}}, @{$child->{nagios}->{perfdata}});
}


sub calculate_result {
  my $self = shift;
  if ($ENV{NRPE_MULTILINESUPPORT} && 
      length join(" ", @{$self->{nagios}->{perfdata}}) > 200) {
    foreach my $level ("CRITICAL", "WARNING", "UNKNOWN", "OK") {
      # first the bad news
      if (scalar(@{$self->{nagios}->{messages}->{$ERRORS{$level}}})) {
        $self->{nagios_message} .=
            "\n".join("\n", @{$self->{nagios}->{messages}->{$ERRORS{$level}}});
      }
    }
    $self->{nagios_message} =~ s/^\n//g;
    $self->{perfdata} = join("\n", @{$self->{nagios}->{perfdata}});
  } else {
    foreach my $level ("CRITICAL", "WARNING", "UNKNOWN", "OK") {
      # first the bad news
      if (scalar(@{$self->{nagios}->{messages}->{$ERRORS{$level}}})) {
        $self->{nagios_message} .= 
            join(", ", @{$self->{nagios}->{messages}->{$ERRORS{$level}}}).", ";
      }
    }
    $self->{nagios_message} =~ s/, $//g;
    $self->{perfdata} = join(" ", @{$self->{nagios}->{perfdata}});
  }
  foreach my $level ("OK", "UNKNOWN", "WARNING", "CRITICAL") {
    if (scalar(@{$self->{nagios}->{messages}->{$ERRORS{$level}}})) {
      $self->{nagios_level} = $ERRORS{$level};
    }
  }
}

sub debug {
  my $self = shift;
  my $msg = shift;
  if ($DBD::MySQL::Cluster::verbose) {
    printf "%s %s\n", $msg, ref($self);
  }
}

sub connect {
  my $self = shift;
  my %params = @_;
  my $retval = undef;
  $self->{tic} = Time::HiRes::time();
  eval {
    use POSIX ':signal_h';
    local $SIG{'ALRM'} = sub {
      die "alarm\n";
    };
    my $mask = POSIX::SigSet->new( SIGALRM );
    my $action = POSIX::SigAction->new(
        sub { die "connection timeout\n" ; }, $mask);
    my $oldaction = POSIX::SigAction->new();
    sigaction(SIGALRM ,$action ,$oldaction );
    alarm($self->{timeout} - 1); # 1 second before the global unknown timeout
    my $ndb_mgm = "ndb_mgm";
    $params{hostname} = "127.0.0.1" if ! $params{hostname};
    $ndb_mgm .= sprintf " --ndb-connectstring=%s", $params{hostname}
        if $params{hostname};
    $ndb_mgm .= sprintf ":%d", $params{port}
        if $params{port};
    $self->{show} = `$ndb_mgm -e show 2>&1`;
    if ($? == -1) {
      $self->add_nagios_critical("ndb_mgm failed to execute $!");
    } elsif ($? & 127) {
      $self->add_nagios_critical("ndb_mgm failed to execute $!");
    } elsif ($? >> 8 != 0) {
      $self->add_nagios_critical("ndb_mgm unable to connect");
    } else {
      if ($self->{show} !~ /Cluster Configuration/) {
        $self->add_nagios_critical("got no cluster configuration");
      } else {
        $retval = 1;
      }
    }
  };
  if ($@) {
    $self->{errstr} = $@;
    $self->{errstr} =~ s/at $0 .*//g;
    chomp $self->{errstr};
    $self->add_nagios_critical($self->{errstr});
    $retval = undef;
  }
  $self->{tac} = Time::HiRes::time();
  return $retval;
}

sub trace {
  my $self = shift;
  my $format = shift;
  $self->{trace} = -f "/tmp/check_mysql_health.trace" ? 1 : 0;
  if ($self->{verbose}) {
    printf("%s: ", scalar localtime);
    printf($format, @_);
  }
  if ($self->{trace}) {
    my $logfh = new IO::File;
    $logfh->autoflush(1);
    if ($logfh->open("/tmp/check_mysql_health.trace", "a")) {
      $logfh->printf("%s: ", scalar localtime);
      $logfh->printf($format, @_);
      $logfh->printf("\n");
      $logfh->close();
    }
  }
}

sub DESTROY {
  my $self = shift;
  my $handle1 = "null";
  my $handle2 = "null";
  if (defined $self->{handle}) {
    $handle1 = ref($self->{handle});
    if (defined $self->{handle}->{handle}) {
      $handle2 = ref($self->{handle}->{handle});
    }
  }
  $self->trace(sprintf "DESTROY %s with handle %s %s", ref($self), $handle1, $handle2);
  if (ref($self) eq "DBD::MySQL::Cluster") {
  }
  $self->trace(sprintf "DESTROY %s exit with handle %s %s", ref($self), $handle1, $handle2);
  if (ref($self) eq "DBD::MySQL::Cluster") {
    #printf "humpftata\n";
  }
}

sub save_state {
  my $self = shift;
  my %params = @_;
  my $extension = "";
  mkdir $params{statefilesdir} unless -d $params{statefilesdir};
  my $statefile = sprintf "%s/%s_%s", 
      $params{statefilesdir}, $params{hostname}, $params{mode};
  $extension .= $params{differenciator} ? "_".$params{differenciator} : "";
  $extension .= $params{socket} ? "_".$params{socket} : "";
  $extension .= $params{port} ? "_".$params{port} : "";
  $extension .= $params{database} ? "_".$params{database} : "";
  $extension .= $params{tablespace} ? "_".$params{tablespace} : "";
  $extension .= $params{datafile} ? "_".$params{datafile} : "";
  $extension .= $params{name} ? "_".$params{name} : "";
  $extension =~ s/\//_/g;
  $extension =~ s/\(/_/g;
  $extension =~ s/\)/_/g;
  $extension =~ s/\*/_/g;
  $extension =~ s/\s/_/g;
  $statefile .= $extension;
  $statefile = lc $statefile;
  open(STATE, ">$statefile");
  if ((ref($params{save}) eq "HASH") && exists $params{save}->{timestamp}) {
    $params{save}->{localtime} = scalar localtime $params{save}->{timestamp};
  }
  printf STATE Data::Dumper::Dumper($params{save});
  close STATE;
  $self->debug(sprintf "saved %s to %s",
      Data::Dumper::Dumper($params{save}), $statefile);
}

sub load_state {
  my $self = shift;
  my %params = @_;
  my $extension = "";
  my $statefile = sprintf "%s/%s_%s", 
      $params{statefilesdir}, $params{hostname}, $params{mode};
  $extension .= $params{differenciator} ? "_".$params{differenciator} : "";
  $extension .= $params{socket} ? "_".$params{socket} : "";
  $extension .= $params{port} ? "_".$params{port} : "";
  $extension .= $params{database} ? "_".$params{database} : "";
  $extension .= $params{tablespace} ? "_".$params{tablespace} : "";
  $extension .= $params{datafile} ? "_".$params{datafile} : "";
  $extension .= $params{name} ? "_".$params{name} : "";
  $extension =~ s/\//_/g;
  $extension =~ s/\(/_/g;
  $extension =~ s/\)/_/g;
  $extension =~ s/\*/_/g;
  $extension =~ s/\s/_/g;
  $statefile .= $extension;
  $statefile = lc $statefile;
  if ( -f $statefile) {
    our $VAR1;
    eval {
      require $statefile;
    };
    if($@) {
printf "rumms\n";
    }
    $self->debug(sprintf "load %s", Data::Dumper::Dumper($VAR1));
    return $VAR1;
  } else {
    return undef;
  }
}

sub valdiff {
  my $self = shift;
  my $pparams = shift;
  my %params = %{$pparams};
  my @keys = @_;
  my $last_values = $self->load_state(%params) || eval {
    my $empty_events = {};
    foreach (@keys) {
      $empty_events->{$_} = 0;
    }
    $empty_events->{timestamp} = 0;
    $empty_events;
  };
  foreach (@keys) {
    $self->{'delta_'.$_} = $self->{$_} - $last_values->{$_};
    $self->debug(sprintf "delta_%s %f", $_, $self->{'delta_'.$_});
  }
  $self->{'delta_timestamp'} = time - $last_values->{timestamp};
  $params{save} = eval {
    my $empty_events = {};
    foreach (@keys) {
      $empty_events->{$_} = $self->{$_};
    }
    $empty_events->{timestamp} = time;
    $empty_events;
  };
  $self->save_state(%params);
}

sub requires_version {
  my $self = shift;
  my $version = shift;
  my @instances = DBD::MySQL::Cluster::return_clusters();
  my $instversion = $instances[0]->{version};
  if (! $self->version_is_minimum($version)) {
    $self->add_nagios($ERRORS{UNKNOWN}, 
        sprintf "not implemented/possible for MySQL release %s", $instversion);
  }
}

sub version_is_minimum {
  # the current version is newer or equal
  my $self = shift;
  my $version = shift;
  my $newer = 1;
  my @instances = DBD::MySQL::Cluster::return_clusters();
  my @v1 = map { $_ eq "x" ? 0 : $_ } split(/\./, $version);
  my @v2 = split(/\./, $instances[0]->{version});
  if (scalar(@v1) > scalar(@v2)) {
    push(@v2, (0) x (scalar(@v1) - scalar(@v2)));
  } elsif (scalar(@v2) > scalar(@v1)) {
    push(@v1, (0) x (scalar(@v2) - scalar(@v1)));
  }
  foreach my $pos (0..$#v1) {
    if ($v2[$pos] > $v1[$pos]) {
      $newer = 1;
      last;
    } elsif ($v2[$pos] < $v1[$pos]) {
      $newer = 0;
      last;
    }
  }
  #printf STDERR "check if %s os minimum %s\n", join(".", @v2), join(".", @v1);
  return $newer;
}

sub instance_rac {
  my $self = shift;
  my @instances = DBD::MySQL::Cluster::return_clusters();
  return (lc $instances[0]->{parallel} eq "yes") ? 1 : 0;
}

sub instance_thread {
  my $self = shift;
  my @instances = DBD::MySQL::Cluster::return_clusters();
  return $instances[0]->{thread};
}

sub windows_cluster {
  my $self = shift;
  my @instances = DBD::MySQL::Cluster::return_clusters();
  if ($instances[0]->{os} =~ /Win/i) {
    return 1;
  } else {
    return 0;
  }
}

sub system_vartmpdir {
  my $self = shift;
  if ($^O =~ /MSWin/) {
    return $self->system_tmpdir();
  } else {
    return "/var/tmp/check_mysql_health";
  }
}

sub system_oldvartmpdir {
  my $self = shift;
  return "/tmp";
}

sub system_tmpdir {
  my $self = shift;
  if ($^O =~ /MSWin/) {
    return $ENV{TEMP} if defined $ENV{TEMP};
    return $ENV{TMP} if defined $ENV{TMP};
    return File::Spec->catfile($ENV{windir}, 'Temp')
        if defined $ENV{windir};
    return 'C:\Temp';
  } else {
    return "/tmp";
  }
}


package DBD::MySQL::Cluster::Node;

use strict;

our @ISA = qw(DBD::MySQL::Cluster);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    mode => $params{mode},
    timeout => $params{timeout},
    type => $params{type},
    id => $params{id},
    status => $params{status},
  };
  bless $self, $class;
  $self->init(%params);
  if ($params{type} eq "NDB") {
    bless $self, "DBD::MySQL::Cluster::Node::NDB";
    $self->init(%params);
  }
  return $self;
}

sub init {
  my $self = shift;
  my %params = @_;
  if ($self->{status} =~ /@(\d+\.\d+\.\d+\.\d+)\s/) {
    $self->{addr} = $1;
    $self->{connected} = 1;
  } elsif ($self->{status} =~ /accepting connect from (\d+\.\d+\.\d+\.\d+)/) {
    $self->{addr} = $1;
    $self->{connected} = 0;
  }
  if ($self->{status} =~ /starting,/) {
    $self->{status} = "starting";
  } elsif ($self->{status} =~ /shutting,/) {
    $self->{status} = "shutting";
  } else {
    $self->{status} = $self->{connected} ? "running" : "dead";
  }
}


package DBD::MySQL::Cluster::Node::NDB;

use strict;

our @ISA = qw(DBD::MySQL::Cluster::Node);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

sub init {
  my $self = shift;
  my %params = @_;
  if ($self->{status} =~ /Nodegroup:\s*(\d+)/) {
    $self->{nodegroup} = $1;
  }
  $self->{master} = ($self->{status} =~ /Master\)/) ? 1 : 0;
}


