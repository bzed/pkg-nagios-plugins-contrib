package DBD::MySQL::Server::Instance;

use strict;

our @ISA = qw(DBD::MySQL::Server);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    handle => $params{handle},
    uptime => $params{uptime},
    warningrange => $params{warningrange},
    criticalrange => $params{criticalrange},
    threads_connected => undef,
    threads_created => undef,
    connections => undef,
    threadcache_hitrate => undef,
    querycache_hitrate => undef,
    lowmem_prunes_per_sec => undef,
    slow_queries_per_sec => undef,
    longrunners => undef,
    tablecache_hitrate => undef,
    index_usage => undef,
    engine_innodb => undef,
    engine_myisam => undef,
    replication => undef,
  };
  bless $self, $class;
  $self->init(%params);
  return $self;
}

sub init {
  my $self = shift;
  my %params = @_;
  my $dummy;
  $self->init_nagios();
  if ($params{mode} =~ /server::instance::connectedthreads/) {
    ($dummy, $self->{threads_connected}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Threads_connected'
    });
  } elsif ($params{mode} =~ /server::instance::createdthreads/) {
    ($dummy, $self->{threads_created}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Threads_created'
    });
    $self->valdiff(\%params, qw(threads_created));
    $self->{threads_created_per_sec} = $self->{delta_threads_created} /
        $self->{delta_timestamp};
  } elsif ($params{mode} =~ /server::instance::runningthreads/) {
    ($dummy, $self->{threads_running}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Threads_running'
    });
  } elsif ($params{mode} =~ /server::instance::cachedthreads/) {
    ($dummy, $self->{threads_cached}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Threads_cached'
    });
  } elsif ($params{mode} =~ /server::instance::abortedconnects/) {
    ($dummy, $self->{connects_aborted}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Aborted_connects'
    });
    $self->valdiff(\%params, qw(connects_aborted));
    $self->{connects_aborted_per_sec} = $self->{delta_connects_aborted} /
        $self->{delta_timestamp};
  } elsif ($params{mode} =~ /server::instance::abortedclients/) {
    ($dummy, $self->{clients_aborted}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Aborted_clients'
    });
    $self->valdiff(\%params, qw(clients_aborted));
    $self->{clients_aborted_per_sec} = $self->{delta_clients_aborted} /
        $self->{delta_timestamp};
  } elsif ($params{mode} =~ /server::instance::threadcachehitrate/) {
    ($dummy, $self->{threads_created}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Threads_created'
    });
    ($dummy, $self->{connections}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Connections'
    });
    $self->valdiff(\%params, qw(threads_created connections));
    if ($self->{delta_connections} > 0) {
      $self->{threadcache_hitrate_now} = 
          100 - ($self->{delta_threads_created} * 100.0 /
          $self->{delta_connections});
    } else {
      $self->{threadcache_hitrate_now} = 100;
    }
    $self->{threadcache_hitrate} = 100 - 
        ($self->{threads_created} * 100.0 / $self->{connections});
    $self->{connections_per_sec} = $self->{delta_connections} /
        $self->{delta_timestamp};
  } elsif ($params{mode} =~ /server::instance::querycachehitrate/) {
    ($dummy, $self->{com_select}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Com_select'
    });
    ($dummy, $self->{qcache_hits}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Qcache_hits'
    });
    #    SHOW VARIABLES WHERE Variable_name = 'have_query_cache' for 5.x, but LIKE is compatible
    ($dummy, $self->{have_query_cache}) = $self->{handle}->fetchrow_array(q{
        SHOW VARIABLES LIKE 'have_query_cache'
    });
    #    SHOW VARIABLES WHERE Variable_name = 'query_cache_size'
    ($dummy, $self->{query_cache_size}) = $self->{handle}->fetchrow_array(q{
        SHOW VARIABLES LIKE 'query_cache_size'
    });
    $self->valdiff(\%params, qw(com_select qcache_hits));
    $self->{querycache_hitrate_now} = 
        ($self->{delta_com_select} + $self->{delta_qcache_hits}) > 0 ?
        100 * $self->{delta_qcache_hits} /
            ($self->{delta_com_select} + $self->{delta_qcache_hits}) :
        0;
    $self->{querycache_hitrate} = 
        ($self->{com_select} + $self->{qcache_hits}) > 0 ?
        100 * $self->{qcache_hits} /
            ($self->{com_select} + $self->{qcache_hits}) :
        0;
    $self->{selects_per_sec} =
        $self->{delta_com_select} / $self->{delta_timestamp};
  } elsif ($params{mode} =~ /server::instance::querycachelowmemprunes/) {
    ($dummy, $self->{lowmem_prunes}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Qcache_lowmem_prunes'
    });
    $self->valdiff(\%params, qw(lowmem_prunes));
    $self->{lowmem_prunes_per_sec} = $self->{delta_lowmem_prunes} / 
        $self->{delta_timestamp};
  } elsif ($params{mode} =~ /server::instance::slowqueries/) {
    ($dummy, $self->{slow_queries}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Slow_queries'
    });
    $self->valdiff(\%params, qw(slow_queries));
    $self->{slow_queries_per_sec} = $self->{delta_slow_queries} / 
        $self->{delta_timestamp};
  } elsif ($params{mode} =~ /server::instance::longprocs/) {
    if (DBD::MySQL::Server::return_first_server()->version_is_minimum("5.1")) {
      ($self->{longrunners}) = $self->{handle}->fetchrow_array(q{
          SELECT
              COUNT(*)
          FROM
              information_schema.processlist
          WHERE user <> 'replication' 
          AND id <> CONNECTION_ID() 
          AND time > 60 
          AND command <> 'Sleep'
      });
    } else {
      $self->{longrunners} = 0 if ! defined $self->{longrunners};
      foreach ($self->{handle}->fetchall_array(q{
          SHOW PROCESSLIST
      })) {
        my($id, $user, $host, $db, $command, $tme, $state, $info) = @{$_};
        if (($user ne 'replication') &&
            ($tme > 60) &&
            ($command ne 'Sleep')) {
          $self->{longrunners}++;
        }
      }
    }
  } elsif ($params{mode} =~ /server::instance::tablecachehitrate/) {
    ($dummy, $self->{open_tables}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Open_tables'
    });
    ($dummy, $self->{opened_tables}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Opened_tables'
    });
    if (DBD::MySQL::Server::return_first_server()->version_is_minimum("5.1.3")) {
      #      SHOW VARIABLES WHERE Variable_name = 'table_open_cache'
      ($dummy, $self->{table_cache}) = $self->{handle}->fetchrow_array(q{
          SHOW VARIABLES LIKE 'table_open_cache'
      });
    } else {
      #    SHOW VARIABLES WHERE Variable_name = 'table_cache'
      ($dummy, $self->{table_cache}) = $self->{handle}->fetchrow_array(q{
          SHOW VARIABLES LIKE 'table_cache'
      });
    }
    $self->{table_cache} ||= 0;
    #$self->valdiff(\%params, qw(open_tables opened_tables table_cache));
    # _now ist hier sinnlos, da opened_tables waechst, aber open_tables wieder 
    # schrumpfen kann weil tabellen geschlossen werden.
    if ($self->{opened_tables} != 0 && $self->{table_cache} != 0) {
      $self->{tablecache_hitrate} = 
          100 * $self->{open_tables} / $self->{opened_tables};
      $self->{tablecache_fillrate} = 
          100 * $self->{open_tables} / $self->{table_cache};
    } elsif ($self->{opened_tables} == 0 && $self->{table_cache} != 0) {
      $self->{tablecache_hitrate} = 100;
      $self->{tablecache_fillrate} = 
          100 * $self->{open_tables} / $self->{table_cache};
    } else {
      $self->{tablecache_hitrate} = 0;
      $self->{tablecache_fillrate} = 0;
      $self->add_nagios_critical("no table cache");
    }
  } elsif ($params{mode} =~ /server::instance::tablelockcontention/) {
    ($dummy, $self->{table_locks_waited}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Table_locks_waited'
    });
    ($dummy, $self->{table_locks_immediate}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Table_locks_immediate'
    });
    $self->valdiff(\%params, qw(table_locks_waited table_locks_immediate));
    $self->{table_lock_contention} = 
        ($self->{table_locks_waited} + $self->{table_locks_immediate}) > 0 ?
        100 * $self->{table_locks_waited} / 
        ($self->{table_locks_waited} + $self->{table_locks_immediate}) :
        100;
    $self->{table_lock_contention_now} = 
        ($self->{delta_table_locks_waited} + $self->{delta_table_locks_immediate}) > 0 ?
        100 * $self->{delta_table_locks_waited} / 
        ($self->{delta_table_locks_waited} + $self->{delta_table_locks_immediate}) :
        100;
  } elsif ($params{mode} =~ /server::instance::tableindexusage/) {
    # http://johnjacobm.wordpress.com/2007/06/
    # formula for calculating the percentage of full table scans
    ($dummy, $self->{handler_read_first}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Handler_read_first'
    });
    ($dummy, $self->{handler_read_key}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Handler_read_key'
    });
    ($dummy, $self->{handler_read_next}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Handler_read_next'
    });
    ($dummy, $self->{handler_read_prev}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Handler_read_prev'
    });
    ($dummy, $self->{handler_read_rnd}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Handler_read_rnd'
    });
    ($dummy, $self->{handler_read_rnd_next}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Handler_read_rnd_next'
    });
    $self->valdiff(\%params, qw(handler_read_first handler_read_key
        handler_read_next handler_read_prev handler_read_rnd
        handler_read_rnd_next));
    my $delta_reads = $self->{delta_handler_read_first} +
        $self->{delta_handler_read_key} +
        $self->{delta_handler_read_next} +
        $self->{delta_handler_read_prev} +
        $self->{delta_handler_read_rnd} +
        $self->{delta_handler_read_rnd_next};
    my $reads = $self->{handler_read_first} +
        $self->{handler_read_key} +
        $self->{handler_read_next} +
        $self->{handler_read_prev} +
        $self->{handler_read_rnd} +
        $self->{handler_read_rnd_next};
    $self->{index_usage_now} = ($delta_reads == 0) ? 0 :
        100 - (100.0 * ($self->{delta_handler_read_rnd} +
        $self->{delta_handler_read_rnd_next}) /
        $delta_reads);
    $self->{index_usage} = ($reads == 0) ? 0 :
        100 - (100.0 * ($self->{handler_read_rnd} +
        $self->{handler_read_rnd_next}) /
        $reads);
  } elsif ($params{mode} =~ /server::instance::tabletmpondisk/) {
    ($dummy, $self->{created_tmp_tables}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Created_tmp_tables'
    });
    ($dummy, $self->{created_tmp_disk_tables}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Created_tmp_disk_tables'
    });
    $self->valdiff(\%params, qw(created_tmp_tables created_tmp_disk_tables));
    $self->{pct_tmp_on_disk} = $self->{created_tmp_tables} > 0 ?
        100 * $self->{created_tmp_disk_tables} / $self->{created_tmp_tables} :
        100;
    $self->{pct_tmp_on_disk_now} = $self->{delta_created_tmp_tables} > 0 ?
        100 * $self->{delta_created_tmp_disk_tables} / $self->{delta_created_tmp_tables} :
        100;
  } elsif ($params{mode} =~ /server::instance::openfiles/) {
    ($dummy, $self->{open_files_limit}) = $self->{handle}->fetchrow_array(q{
        SHOW VARIABLES LIKE 'open_files_limit'
    });
    ($dummy, $self->{open_files}) = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Open_files'
    });
    $self->{pct_open_files} = 100 * $self->{open_files} / $self->{open_files_limit};
  } elsif ($params{mode} =~ /server::instance::needoptimize/) {
    $self->{fragmented} = [];
    #http://www.electrictoolbox.com/optimize-tables-mysql-php/
    my  @result = $self->{handle}->fetchall_array(q{
        SHOW TABLE STATUS
    });
    foreach (@result) {
      my ($name, $engine, $data_length, $data_free) =
          ($_->[0], $_->[1], $_->[6 ], $_->[9]);
      next if ($params{name} && $params{name} ne $name);
      my $fragmentation = $data_length ? $data_free * 100 / $data_length : 0;
      push(@{$self->{fragmented}},
          [$name, $fragmentation, $data_length, $data_free]);
    }
  } elsif ($params{mode} =~ /server::instance::myisam/) {
    $self->{engine_myisam} = DBD::MySQL::Server::Instance::MyISAM->new(
        %params
    );
  } elsif ($params{mode} =~ /server::instance::innodb/) {
    $self->{engine_innodb} = DBD::MySQL::Server::Instance::Innodb->new(
        %params
    );
  } elsif ($params{mode} =~ /server::instance::replication/) {
    $self->{replication} = DBD::MySQL::Server::Instance::Replication->new(
        %params
    );
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ /server::instance::connectedthreads/) {
      $self->add_nagios(
          $self->check_thresholds($self->{threads_connected}, 10, 20),
          sprintf "%d client connection threads", $self->{threads_connected});
      $self->add_perfdata(sprintf "threads_connected=%d;%d;%d",
          $self->{threads_connected},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::instance::createdthreads/) {
      $self->add_nagios(
          $self->check_thresholds($self->{threads_created_per_sec}, 10, 20),
          sprintf "%.2f threads created/sec", $self->{threads_created_per_sec});
      $self->add_perfdata(sprintf "threads_created_per_sec=%.2f;%.2f;%.2f",
          $self->{threads_created_per_sec},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::instance::runningthreads/) {
      $self->add_nagios(
          $self->check_thresholds($self->{threads_running}, 10, 20),
          sprintf "%d running threads", $self->{threads_running});
      $self->add_perfdata(sprintf "threads_running=%d;%d;%d",
          $self->{threads_running},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::instance::cachedthreads/) {
      $self->add_nagios(
          $self->check_thresholds($self->{threads_cached}, 10, 20),
          sprintf "%d cached threads", $self->{threads_cached});
      $self->add_perfdata(sprintf "threads_cached=%d;%d;%d",
          $self->{threads_cached},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::instance::abortedconnects/) {
      $self->add_nagios(
          $self->check_thresholds($self->{connects_aborted_per_sec}, 1, 5),
          sprintf "%.2f aborted connections/sec", $self->{connects_aborted_per_sec});
      $self->add_perfdata(sprintf "connects_aborted_per_sec=%.2f;%.2f;%.2f",
          $self->{connects_aborted_per_sec},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::instance::abortedclients/) {
      $self->add_nagios(
          $self->check_thresholds($self->{clients_aborted_per_sec}, 1, 5),
          sprintf "%.2f aborted (client died) connections/sec", $self->{clients_aborted_per_sec});
      $self->add_perfdata(sprintf "clients_aborted_per_sec=%.2f;%.2f;%.2f",
          $self->{clients_aborted_per_sec},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::instance::threadcachehitrate/) {
      my $refkey = 'threadcache_hitrate'.($params{lookback} ? '_now' : '');
      $self->add_nagios(
          $self->check_thresholds($self->{$refkey}, "90:", "80:"),
          sprintf "thread cache hitrate %.2f%%", $self->{$refkey});
      $self->add_perfdata(sprintf "thread_cache_hitrate=%.2f%%;%s;%s",
          $self->{threadcache_hitrate},
          $self->{warningrange}, $self->{criticalrange});
      $self->add_perfdata(sprintf "thread_cache_hitrate_now=%.2f%%",
          $self->{threadcache_hitrate_now});
      $self->add_perfdata(sprintf "connections_per_sec=%.2f",
          $self->{connections_per_sec});
    } elsif ($params{mode} =~ /server::instance::querycachehitrate/) {
      my $refkey = 'querycache_hitrate'.($params{lookback} ? '_now' : '');
      if ((lc $self->{have_query_cache} eq 'yes') && ($self->{query_cache_size})) {
        $self->add_nagios(
            $self->check_thresholds($self->{$refkey}, "90:", "80:"),
            sprintf "query cache hitrate %.2f%%", $self->{$refkey});
      } else {
        $self->check_thresholds($self->{$refkey}, "90:", "80:");
        $self->add_nagios_ok(
            sprintf "query cache hitrate %.2f%% (because it's turned off)",
            $self->{querycache_hitrate});
      }
      $self->add_perfdata(sprintf "qcache_hitrate=%.2f%%;%s;%s",
          $self->{querycache_hitrate},
          $self->{warningrange}, $self->{criticalrange});
      $self->add_perfdata(sprintf "qcache_hitrate_now=%.2f%%",
          $self->{querycache_hitrate_now});
      $self->add_perfdata(sprintf "selects_per_sec=%.2f",
          $self->{selects_per_sec});
    } elsif ($params{mode} =~ /server::instance::querycachelowmemprunes/) {
      $self->add_nagios(
          $self->check_thresholds($self->{lowmem_prunes_per_sec}, "1", "10"),
          sprintf "%d query cache lowmem prunes in %d seconds (%.2f/sec)",
          $self->{delta_lowmem_prunes}, $self->{delta_timestamp},
          $self->{lowmem_prunes_per_sec});
      $self->add_perfdata(sprintf "qcache_lowmem_prunes_rate=%.2f;%s;%s",
          $self->{lowmem_prunes_per_sec},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::instance::slowqueries/) {
      $self->add_nagios(
          $self->check_thresholds($self->{slow_queries_per_sec}, "0.1", "1"),
          sprintf "%d slow queries in %d seconds (%.2f/sec)",
          $self->{delta_slow_queries}, $self->{delta_timestamp},
          $self->{slow_queries_per_sec});
      $self->add_perfdata(sprintf "slow_queries_rate=%.2f%%;%s;%s",
          $self->{slow_queries_per_sec},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::instance::longprocs/) {
      $self->add_nagios(
          $self->check_thresholds($self->{longrunners}, 10, 20),
          sprintf "%d long running processes", $self->{longrunners});
      $self->add_perfdata(sprintf "long_running_procs=%d;%d;%d",
          $self->{longrunners},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::instance::tablecachehitrate/) {
      if ($self->{tablecache_fillrate} < 95) {
        $self->add_nagios_ok(
            sprintf "table cache hitrate %.2f%%, %.2f%% filled",
                $self->{tablecache_hitrate},
                $self->{tablecache_fillrate});
        $self->check_thresholds($self->{tablecache_hitrate}, "99:", "95:");
      } else {
        $self->add_nagios(
            $self->check_thresholds($self->{tablecache_hitrate}, "99:", "95:"),
            sprintf "table cache hitrate %.2f%%", $self->{tablecache_hitrate});
      }
      $self->add_perfdata(sprintf "tablecache_hitrate=%.2f%%;%s;%s",
          $self->{tablecache_hitrate},
          $self->{warningrange}, $self->{criticalrange});
      $self->add_perfdata(sprintf "tablecache_fillrate=%.2f%%",
          $self->{tablecache_fillrate});
    } elsif ($params{mode} =~ /server::instance::tablelockcontention/) {
      my $refkey = 'table_lock_contention'.($params{lookback} ? '_now' : '');
      if ($self->{uptime} > 10800) { # MySQL Bug #30599
        $self->add_nagios(
            $self->check_thresholds($self->{$refkey}, "1", "2"),
                sprintf "table lock contention %.2f%%", $self->{$refkey});
      } else {
        $self->check_thresholds($self->{$refkey}, "1", "2");
        $self->add_nagios_ok(
            sprintf "table lock contention %.2f%% (uptime < 10800)",
            $self->{$refkey});
      }
      $self->add_perfdata(sprintf "tablelock_contention=%.2f%%;%s;%s",
          $self->{table_lock_contention},
          $self->{warningrange}, $self->{criticalrange});
      $self->add_perfdata(sprintf "tablelock_contention_now=%.2f%%",
          $self->{table_lock_contention_now});
    } elsif ($params{mode} =~ /server::instance::tableindexusage/) {
      my $refkey = 'index_usage'.($params{lookback} ? '_now' : '');
      $self->add_nagios(
          $self->check_thresholds($self->{$refkey}, "90:", "80:"),
              sprintf "index usage  %.2f%%", $self->{$refkey});
      $self->add_perfdata(sprintf "index_usage=%.2f%%;%s;%s",
          $self->{index_usage},
          $self->{warningrange}, $self->{criticalrange});
      $self->add_perfdata(sprintf "index_usage_now=%.2f%%",
          $self->{index_usage_now});
    } elsif ($params{mode} =~ /server::instance::tabletmpondisk/) {
      my $refkey = 'pct_tmp_on_disk'.($params{lookback} ? '_now' : '');
      $self->add_nagios(
          $self->check_thresholds($self->{$refkey}, "25", "50"),
              sprintf "%.2f%% of %d tables were created on disk",
              $self->{$refkey}, $self->{delta_created_tmp_tables});
      $self->add_perfdata(sprintf "pct_tmp_table_on_disk=%.2f%%;%s;%s",
          $self->{pct_tmp_on_disk},
          $self->{warningrange}, $self->{criticalrange});
      $self->add_perfdata(sprintf "pct_tmp_table_on_disk_now=%.2f%%",
          $self->{pct_tmp_on_disk_now});
    } elsif ($params{mode} =~ /server::instance::openfiles/) {
      $self->add_nagios(
          $self->check_thresholds($self->{pct_open_files}, 80, 95),
          sprintf "%.2f%% of the open files limit reached (%d of max. %d)",
              $self->{pct_open_files},
              $self->{open_files}, $self->{open_files_limit});
      $self->add_perfdata(sprintf "pct_open_files=%.3f%%;%.3f;%.3f",
          $self->{pct_open_files},
          $self->{warningrange},
          $self->{criticalrange});
      $self->add_perfdata(sprintf "open_files=%d;%d;%d",
          $self->{open_files},
          $self->{open_files_limit} * $self->{warningrange} / 100,
          $self->{open_files_limit} * $self->{criticalrange} / 100);
    } elsif ($params{mode} =~ /server::instance::needoptimize/) {
      foreach (@{$self->{fragmented}}) {
        $self->add_nagios(
            $self->check_thresholds($_->[1], 10, 25),
            sprintf "table %s is %.2f%% fragmented", $_->[0], $_->[1]);
        if ($params{name}) {
          $self->add_perfdata(sprintf "'%s_frag'=%.2f%%;%d;%d",
              $_->[0], $_->[1], $self->{warningrange}, $self->{criticalrange});
        }
      }
    } elsif ($params{mode} =~ /server::instance::myisam/) {
      $self->{engine_myisam}->nagios(%params);
      $self->merge_nagios($self->{engine_myisam});
    } elsif ($params{mode} =~ /server::instance::innodb/) {
      $self->{engine_innodb}->nagios(%params);
      $self->merge_nagios($self->{engine_innodb});
    } elsif ($params{mode} =~ /server::instance::replication/) {
      $self->{replication}->nagios(%params);
      $self->merge_nagios($self->{replication});
    }
  }
}


1;
