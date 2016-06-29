
package main;

use strict;
use Getopt::Long qw(:config no_ignore_case);
use File::Basename;
use lib dirname($0);
use Nagios::DBD::MySQL::Server;
use Nagios::DBD::MySQL::Cluster;


my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

use vars qw ($PROGNAME $REVISION $CONTACT $TIMEOUT $STATEFILESDIR $needs_restart %commandline);

$PROGNAME = "check_mysql_health";
$REVISION = '$Revision: #PACKAGE_VERSION# $';
$CONTACT = 'gerhard.lausser@consol.de';
$TIMEOUT = 60;
$STATEFILESDIR = '#STATEFILES_DIR#';
$needs_restart = 0;

my @modes = (
  ['server::connectiontime',
      'connection-time', undef,
      'Time to connect to the server' ],
  ['server::uptime',
      'uptime', undef,
      'Time the server is running' ],
  ['server::instance::connectedthreads',
      'threads-connected', undef,
      'Number of currently open connections' ],
  ['server::instance::threadcachehitrate',
      'threadcache-hitrate', undef,
      'Hit rate of the thread-cache' ],
  ['server::instance::createdthreads',
      'threads-created', undef,
      'Number of threads created per sec' ],
  ['server::instance::runningthreads',
      'threads-running', undef,
      'Number of currently running threads' ],
  ['server::instance::cachedthreads',
      'threads-cached', undef,
      'Number of currently cached threads' ],
  ['server::instance::abortedconnects',
      'connects-aborted', undef,
      'Number of aborted connections per sec' ],
  ['server::instance::abortedclients',
      'clients-aborted', undef,
      'Number of aborted connections (because the client died) per sec' ],
  ['server::instance::replication::slavelag',
      'slave-lag', ['replication-slave-lag'],
      'Seconds behind master' ],
  ['server::instance::replication::slaveiorunning',
      'slave-io-running', ['replication-slave-io-running'],
      'Slave io running: Yes' ],
  ['server::instance::replication::slavesqlrunning',
      'slave-sql-running', ['replication-slave-sql-running'],
      'Slave sql running: Yes' ],
  ['server::instance::querycachehitrate',
      'qcache-hitrate', ['querycache-hitrate'],
      'Query cache hitrate' ],
  ['server::instance::querycachelowmemprunes',
      'qcache-lowmem-prunes', ['querycache-lowmem-prunes'],
      'Query cache entries pruned because of low memory' ],
  ['server::instance::myisam::keycache::hitrate',
      'keycache-hitrate', ['myisam-keycache-hitrate'],
      'MyISAM key cache hitrate' ],
  ['server::instance::innodb::bufferpool::hitrate',
      'bufferpool-hitrate', ['innodb-bufferpool-hitrate'],
      'InnoDB buffer pool hitrate' ],
  ['server::instance::innodb::bufferpool::waitfree',
      'bufferpool-wait-free', ['innodb-bufferpool-wait-free'],
      'InnoDB buffer pool waits for clean page available' ],
  ['server::instance::innodb::logwaits',
      'log-waits', ['innodb-log-waits'],
      'InnoDB log waits because of a too small log buffer' ],
  ['server::instance::tablecachehitrate',
      'tablecache-hitrate', undef,
      'Table cache hitrate' ],
  ['server::instance::tablelockcontention',
      'table-lock-contention', undef,
      'Table lock contention' ],
  ['server::instance::tableindexusage',
      'index-usage', undef,
      'Usage of indices' ],
  ['server::instance::tabletmpondisk',
      'tmp-disk-tables', undef,
      'Percent of temp tables created on disk' ],
  ['server::instance::needoptimize',
      'table-fragmentation', undef,
      'Show tables which should be optimized' ],
  ['server::instance::openfiles',
      'open-files', undef,
      'Percent of opened files' ],
  ['server::instance::slowqueries',
      'slow-queries', undef,
      'Slow queries' ],
  ['server::instance::longprocs',
      'long-running-procs', undef,
      'long running processes' ],
  ['cluster::ndbdrunning',
      'cluster-ndbd-running', undef,
      'ndnd nodes are up and running' ],
  ['server::sql',
      'sql', undef,
      'any sql command returning a single number' ],
);

# rrd data store names are limited to 19 characters
my %labels = (
  bufferpool_hitrate => {
    groundwork => 'bp_hitrate',
  },
  bufferpool_hitrate_now => {
    groundwork => 'bp_hitrate_now',
  },
  bufferpool_free_waits_rate => {
    groundwork => 'bp_freewaits',
  },
  innodb_log_waits_rate => {
    groundwork => 'inno_log_waits',
  },
  keycache_hitrate => {
    groundwork => 'kc_hitrate',
  },
  keycache_hitrate_now => {
    groundwork => 'kc_hitrate_now',
  },
  threads_created_per_sec => {
    groundwork => 'thrds_creat_per_s',
  },
  connects_aborted_per_sec => {
    groundwork => 'conn_abrt_per_s',
  },
  clients_aborted_per_sec => {
    groundwork => 'clnt_abrt_per_s',
  },
  thread_cache_hitrate => {
    groundwork => 'tc_hitrate',
  },
  thread_cache_hitrate_now => {
    groundwork => 'tc_hitrate_now',
  },
  qcache_lowmem_prunes_rate => {
    groundwork => 'qc_lowm_prnsrate',
  },
  slow_queries_rate => {
    groundwork => 'slow_q_rate',
  },
  tablecache_hitrate => {
    groundwork => 'tac_hitrate',
  },
  tablecache_fillrate => {
    groundwork => 'tac_fillrate',
  },
  tablelock_contention => {
    groundwork => 'tl_contention',
  },
  tablelock_contention_now => {
    groundwork => 'tl_contention_now',
  },
  pct_tmp_table_on_disk => {
    groundwork => 'tmptab_on_disk',
  },
  pct_tmp_table_on_disk_now => {
    groundwork => 'tmptab_on_disk_now',
  },
);

sub print_usage () {
  print <<EOUS;
  Usage:
    $PROGNAME [-v] [-t <timeout>] [[--hostname <hostname>] 
        [--port <port> | --socket <socket>]
        --username <username> --password <password>] --mode <mode>
        [--method mysql]
    $PROGNAME [-h | --help]
    $PROGNAME [-V | --version]

  Options:
    --hostname
       the database server's hostname
    --port
       the database's port. (default: 3306)
    --socket
       the database's unix socket.
    --username
       the mysql db user
    --password
       the mysql db user's password
    --database
       the database's name. (default: information_schema)
    --replication-user
       the database's replication user name (default: replication)
    --warning
       the warning range
    --critical
       the critical range
    --mode
       the mode of the plugin. select one of the following keywords:
EOUS
  my $longest = length ((reverse sort {length $a <=> length $b} map { $_->[1] } @modes)[0]);
  my $format = "       %-".
  (length ((reverse sort {length $a <=> length $b} map { $_->[1] } @modes)[0])).
  "s\t(%s)\n";
  foreach (@modes) {
    printf $format, $_->[1], $_->[3];
  }
  printf "\n";
  print <<EOUS;
    --name
       the name of something that needs to be further specified,
       currently only used for sql statements
    --name2
       if name is a sql statement, this statement would appear in
       the output and the performance data. This can be ugly, so 
       name2 can be used to appear instead.
    --regexp
       if this parameter is used, name will be interpreted as a 
       regular expression.
    --units
       one of %, KB, MB, GB. This is used for a better output of mode=sql
       and for specifying thresholds for mode=tablespace-free
    --labelformat
       one of pnp4nagios (which is the default) or groundwork.
       It is used to shorten performance data labels to 19 characters.

  In mode sql you can url-encode the statement so you will not have to mess
  around with special characters in your Nagios service definitions.
  Instead of 
  --name="select count(*) from v\$session where status = 'ACTIVE'"
  you can say 
  --name=select%20count%28%2A%29%20from%20v%24session%20where%20status%20%3D%20%27ACTIVE%27
  For your convenience you can call check_mysql_health with the --mode encode
  option and it will encode the standard input.

  You can find the full documentation at 
  https://labs.consol.de/nagios/check_mysql_health/

EOUS
  
}

sub print_help () {
  print "Copyright (c) 2009 Gerhard Lausser\n\n";
  print "\n";
  print "  Check various parameters of MySQL databases \n";
  print "\n";
  print_usage();
  support();
}


sub print_revision ($$) {
  my $commandName = shift;
  my $pluginRevision = shift;
  $pluginRevision =~ s/^\$Revision: //;
  $pluginRevision =~ s/ \$\s*$//;
  print "$commandName ($pluginRevision)\n";
  print "This nagios plugin comes with ABSOLUTELY NO WARRANTY. You may redistribute\ncopies of this plugin under the terms of the GNU General Public License.\n";
}

sub support () {
  my $support='Send email to gerhard.lausser@consol.de if you have questions\nregarding use of this software. \nPlease include version information with all correspondence (when possible,\nuse output from the --version option of the plugin itself).\n';
  $support =~ s/@/\@/g;
  $support =~ s/\\n/\n/g;
  print $support;
}

sub contact_author ($$) {
  my $item = shift;
  my $strangepattern = shift;
  if ($commandline{verbose}) {
    printf STDERR
        "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n".
        "You found a line which is not recognized by %s\n".
        "This means, certain components of your system cannot be checked.\n".
        "Please contact the author %s and\nsend him the following output:\n\n".
        "%s /%s/\n\nThank you!\n".
        "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n",
            $PROGNAME, $CONTACT, $item, $strangepattern;
  }
}

%commandline = ();
my @params = (
    "timeout|t=i",
    "version|V",
    "help|h",
    "verbose|v",
    "debug|d",
    "hostname|H=s",
    "database=s",
    "port|P=s",
    "socket|S=s",
    "username|u=s",
    "password|p=s",
    "replication-user=s",
    "mycnf=s",
    "mycnfgroup=s",
    "mode|m=s",
    "name=s",
    "name2=s",
    "regexp",
    "perfdata",
    "warning=s",
    "critical=s",
    "dbthresholds:s",
    "absolute|a",
    "environment|e=s%",
    "negate=s%",
    "method=s",
    "runas|r=s",
    "scream",
    "shell",
    "eyecandy",
    "encode",
    "units=s",
    "lookback=i",
    "3",
    "statefilesdir=s",
    "with-mymodules-dyn-dir=s",
    "report=s",
    "labelformat=s",
    "extra-opts:s");

if (! GetOptions(\%commandline, @params)) {
  print_help();
  exit $ERRORS{UNKNOWN};
}

if (exists $commandline{'extra-opts'}) {
  # read the extra file and overwrite other parameters
  my $extras = Extraopts->new(file => $commandline{'extra-opts'}, commandline =>
 \%commandline);
  if (! $extras->is_valid()) {
    printf "extra-opts are not valid: %s\n", $extras->{errors};
    exit $ERRORS{UNKNOWN};
  } else {
    $extras->overwrite();
  }
}

if (exists $commandline{version}) {
  print_revision($PROGNAME, $REVISION);
  exit $ERRORS{OK};
}

if (exists $commandline{help}) {
  print_help();
  exit $ERRORS{OK};
} elsif (! exists $commandline{mode}) {
  printf "Please select a mode\n";
  print_help();
  exit $ERRORS{OK};
}

if ($commandline{mode} eq "encode") {
  my $input = <>;
  chomp $input;
  $input =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
  printf "%s\n", $input;
  exit $ERRORS{OK};
}

if (exists $commandline{3}) {
  $ENV{NRPE_MULTILINESUPPORT} = 1;
}

if (exists $commandline{timeout}) {
  $TIMEOUT = $commandline{timeout};
}

if (exists $commandline{verbose}) {
  $DBD::MySQL::Server::verbose = exists $commandline{verbose};
}

if (exists $commandline{scream}) {
#  $DBD::MySQL::Server::hysterical = exists $commandline{scream};
}

if (exists $commandline{method}) {
  # snmp or mysql cmdline
} else {
  $commandline{method} = "dbi";
}

if (exists $commandline{report}) {
  # short, long, html
} else {
  $commandline{report} = "long";
}

if (exists $commandline{labelformat}) {
  # groundwork
} else {
  $commandline{labelformat} = "pnp4nagios";
}

if (exists $commandline{'with-mymodules-dyn-dir'}) {
  $DBD::MySQL::Server::my_modules_dyn_dir = $commandline{'with-mymodules-dyn-dir'};
} else {
  $DBD::MySQL::Server::my_modules_dyn_dir = '#MYMODULES_DYN_DIR#';
}

if (exists $commandline{environment}) {
  # if the desired environment variable values are different from
  # the environment of this running script, then a restart is necessary.
  # because setting $ENV does _not_ change the environment of the running script.
  foreach (keys %{$commandline{environment}}) {
    if ((! $ENV{$_}) || ($ENV{$_} ne $commandline{environment}->{$_})) {
      $needs_restart = 1;
      $ENV{$_} = $commandline{environment}->{$_};
      printf STDERR "new %s=%s forces restart\n", $_, $ENV{$_} 
          if $DBD::MySQL::Server::verbose;
    }
  }
  # e.g. called with --runas dbnagio. shlib_path environment variable is stripped
  # during the sudo.
  # so the perl interpreter starts without a shlib_path. but --runas cares for
  # a --environment shlib_path=...
  # so setting the environment variable in the code above and restarting the 
  # perl interpreter will help it find shared libs
}

if (exists $commandline{runas}) {
  # remove the runas parameter
  # exec sudo $0 ... the remaining parameters
  $needs_restart = 1;
  # if the calling script has a path for shared libs and there is no --environment
  # parameter then the called script surely needs the variable too.
  foreach my $important_env (qw(LD_LIBRARY_PATH SHLIB_PATH 
      ORACLE_HOME TNS_ADMIN ORA_NLS ORA_NLS33 ORA_NLS10)) {
    if ($ENV{$important_env} && ! scalar(grep { /^$important_env=/ } 
        keys %{$commandline{environment}})) {
      $commandline{environment}->{$important_env} = $ENV{$important_env};
      printf STDERR "add important --environment %s=%s\n", 
          $important_env, $ENV{$important_env} if $DBD::MySQL::Server::verbose;
    }
  }
}

if ($needs_restart) {
  my @newargv = ();
  my $runas = undef;
  if (exists $commandline{runas}) {
    $runas = $commandline{runas};
    delete $commandline{runas};
  }
  foreach my $option (keys %commandline) {
    if (grep { /^$option/ && /=/ } @params) {
      if (ref ($commandline{$option}) eq "HASH") {
        foreach (keys %{$commandline{$option}}) {
          push(@newargv, sprintf "--%s", $option);
          push(@newargv, sprintf "%s=%s", $_, $commandline{$option}->{$_});
        }
      } else {
        push(@newargv, sprintf "--%s", $option);
        push(@newargv, sprintf "%s", $commandline{$option});
      }
    } else {
      push(@newargv, sprintf "--%s", $option);
    }
  }
  if ($runas) {
    exec "sudo", "-S", "-u", $runas, $0, @newargv;
  } else {
    exec $0, @newargv;  
    # this makes sure that even a SHLIB or LD_LIBRARY_PATH are set correctly
    # when the perl interpreter starts. Setting them during runtime does not
    # help loading e.g. libclntsh.so
  }
  exit;
}

if (exists $commandline{shell}) {
  # forget what you see here.
  system("/bin/sh");
}

if (! exists $commandline{statefilesdir}) {
  if (exists $ENV{OMD_ROOT}) {
    $commandline{statefilesdir} = $ENV{OMD_ROOT}."/var/tmp/check_mysql_health";
  } else {
    $commandline{statefilesdir} = $STATEFILESDIR;
  }
}

if (exists $commandline{name}) {
  if ($^O =~ /MSWin/ && $commandline{name} =~ /^'(.*)'$/) {
    # putting arguments in single ticks under Windows CMD leaves the ' intact
    # we remove them
    $commandline{name} = $1;
  }
  # objects can be encoded like an url
  # with s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
  if (($commandline{mode} ne "sql") || 
      (($commandline{mode} eq "sql") &&
       ($commandline{name} =~ /select%20/i))) { # protect ... like '%cac%' ... from decoding
    $commandline{name} =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
  }
  if ($commandline{name} =~ /^0$/) {
    # without this, $params{selectname} would be treated like undef
    $commandline{name} = "00";
  } 
}

$SIG{'ALRM'} = sub {
  printf "UNKNOWN - %s timed out after %d seconds\n", $PROGNAME, $TIMEOUT;
  exit $ERRORS{UNKNOWN};
};
alarm($TIMEOUT);

my $nagios_level = $ERRORS{UNKNOWN};
my $nagios_message = "";
my $perfdata = "";
if ($commandline{mode} =~ /^my-([^\-.]+)/) {
  my $param = $commandline{mode};
  $param =~ s/\-/::/g;
  push(@modes, [$param, $commandline{mode}, undef, 'my extension']);
} elsif ((! grep { $commandline{mode} eq $_ } map { $_->[1] } @modes) &&
    (! grep { $commandline{mode} eq $_ } map { defined $_->[2] ? @{$_->[2]} : () } @modes)) {
  printf "UNKNOWN - mode %s\n", $commandline{mode};
  print_usage();
  exit 3;
}
my %params = (
    timeout => $TIMEOUT,
    mode => (
        map { $_->[0] }
        grep {
           ($commandline{mode} eq $_->[1]) ||
           ( defined $_->[2] && grep { $commandline{mode} eq $_ } @{$_->[2]})
        } @modes
    )[0],
    cmdlinemode => $commandline{mode},
    method => $commandline{method} ||
        $ENV{NAGIOS__SERVICEMYSQL_METH} ||
        $ENV{NAGIOS__HOSTMYSQL_METH} || 'dbi',
    hostname => $commandline{hostname} || 
        $ENV{NAGIOS__SERVICEMYSQL_HOST} ||
        $ENV{NAGIOS__HOSTMYSQL_HOST} || 'localhost',
    database => $commandline{database} || 
        $ENV{NAGIOS__SERVICEMYSQL_DATABASE} ||
        $ENV{NAGIOS__HOSTMYSQL_DATABASE} || 'information_schema',
    port => $commandline{port}  || (($commandline{mode} =~ /^cluster/) ?
        ($ENV{NAGIOS__SERVICENDBMGM_PORT} || $ENV{NAGIOS__HOSTNDBMGM_PORT} || 1186) :
        ($ENV{NAGIOS__SERVICEMYSQL_PORT} || $ENV{NAGIOS__HOSTMYSQL_PORT} || 3306)),
    socket => $commandline{socket}  || 
        $ENV{NAGIOS__SERVICEMYSQL_SOCKET} ||
        $ENV{NAGIOS__HOSTMYSQL_SOCKET},
    username => $commandline{username} || 
        $ENV{NAGIOS__SERVICEMYSQL_USER} ||
        $ENV{NAGIOS__HOSTMYSQL_USER},
    password => $commandline{password} || 
        $ENV{NAGIOS__SERVICEMYSQL_PASS} ||
        $ENV{NAGIOS__HOSTMYSQL_PASS},
    replication_user => $commandline{'replication-user'} || 'replication',
    mycnf => $commandline{mycnf} || 
        $ENV{NAGIOS__SERVICEMYSQL_MYCNF} ||
        $ENV{NAGIOS__HOSTMYSQL_MYCNF},
    mycnfgroup => $commandline{mycnfgroup} || 
        $ENV{NAGIOS__SERVICEMYSQL_MYCNFGROUP} ||
        $ENV{NAGIOS__HOSTMYSQL_MYCNFGROUP},
    warningrange => $commandline{warning},
    criticalrange => $commandline{critical},
    dbthresholds => $commandline{dbthresholds},
    absolute => $commandline{absolute},
    lookback => $commandline{lookback},
    selectname => $commandline{name} || $commandline{tablespace} || $commandline{datafile},
    regexp => $commandline{regexp},
    name => $commandline{name},
    name2 => $commandline{name2} || $commandline{name},
    units => $commandline{units},
    lookback => $commandline{lookback} || 0,
    eyecandy => $commandline{eyecandy},
    statefilesdir => $commandline{statefilesdir},
    verbose => $commandline{verbose},
    report => $commandline{report},
    labelformat => $commandline{labelformat},
    negate => $commandline{negate},
);

my $server = undef;
my $cluster = undef;

if ($params{mode} =~ /^(server|my)/) {
  $server = DBD::MySQL::Server->new(%params);
  $server->nagios(%params);
  $server->calculate_result(\%labels);
  $nagios_message = $server->{nagios_message};
  $nagios_level = $server->{nagios_level};
  $perfdata = $server->{perfdata};
} elsif ($params{mode} =~ /^cluster/) {
  $cluster = DBD::MySQL::Cluster->new(%params);
  $cluster->nagios(%params);
  $cluster->calculate_result(\%labels);
  $nagios_message = $cluster->{nagios_message};
  $nagios_level = $cluster->{nagios_level};
  $perfdata = $cluster->{perfdata};
}

printf "%s - %s", $ERRORCODES{$nagios_level}, $nagios_message;
printf " | %s", $perfdata if $perfdata;
printf "\n";
exit $nagios_level;


__END__


