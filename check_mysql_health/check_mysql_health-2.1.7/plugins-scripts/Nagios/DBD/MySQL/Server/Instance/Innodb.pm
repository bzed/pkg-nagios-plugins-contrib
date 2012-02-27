package DBD::MySQL::Server::Instance::Innodb;

use strict;

our @ISA = qw(DBD::MySQL::Server::Instance);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    handle => $params{handle},
    internals => undef,
    warningrange => $params{warningrange},
    criticalrange => $params{criticalrange},
  };
  bless $self, $class;
  $self->init(%params);
  return $self;
}

sub init {
  my $self = shift;
  my %params = @_;
  $self->init_nagios();
  if ($params{mode} =~ /server::instance::innodb/) {
    $self->{internals} =
        DBD::MySQL::Server::Instance::Innodb::Internals->new(%params);
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if ($params{mode} =~ /server::instance::innodb/) {
    $self->{internals}->nagios(%params);
    $self->merge_nagios($self->{internals});
  }
}


package DBD::MySQL::Server::Instance::Innodb::Internals;

use strict;

our @ISA = qw(DBD::MySQL::Server::Instance::Innodb);

our $internals; # singleton, nur ein einziges mal instantiierbar

sub new {
  my $class = shift;
  my %params = @_;
  unless ($internals) {
    $internals = {
      handle => $params{handle},
      bufferpool_hitrate => undef,
      wait_free => undef,
      log_waits => undef,
      have_innodb => undef,
      warningrange => $params{warningrange},
      criticalrange => $params{criticalrange},
    };
    bless($internals, $class);
    $internals->init(%params);
  }
  return($internals);
}

sub init {
  my $self = shift;
  my %params = @_;
  my $dummy;
  $self->debug("enter init");
  $self->init_nagios();
  ($dummy, $self->{have_innodb}) 
      = $self->{handle}->fetchrow_array(q{
      SHOW VARIABLES LIKE 'have_innodb'
  });
  if ($self->{have_innodb} eq "NO") {
    $self->add_nagios_critical("the innodb engine has a problem (have_innodb=no)");
  } elsif ($self->{have_innodb} eq "DISABLED") {
    # add_nagios_ok later
  } elsif ($params{mode} =~ /server::instance::innodb::bufferpool::hitrate/) {
    ($dummy, $self->{bufferpool_reads}) 
        = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Innodb_buffer_pool_reads'
    });
    ($dummy, $self->{bufferpool_read_requests}) 
        = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Innodb_buffer_pool_read_requests'
    });
    if (! defined $self->{bufferpool_reads}) {
      $self->add_nagios_critical("no innodb buffer pool info available");
    } else {
      $self->valdiff(\%params, qw(bufferpool_reads
          bufferpool_read_requests));
      $self->{bufferpool_hitrate_now} =
          $self->{delta_bufferpool_read_requests} > 0 ?
          100 - (100 * $self->{delta_bufferpool_reads} / 
              $self->{delta_bufferpool_read_requests}) : 100;
      $self->{bufferpool_hitrate} =
          $self->{bufferpool_read_requests} > 0 ?
          100 - (100 * $self->{bufferpool_reads} /
              $self->{bufferpool_read_requests}) : 100;
    }
  } elsif ($params{mode} =~ /server::instance::innodb::bufferpool::waitfree/) {
    ($dummy, $self->{bufferpool_wait_free})
        = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Innodb_buffer_pool_wait_free'
    });
    if (! defined $self->{bufferpool_wait_free}) {
      $self->add_nagios_critical("no innodb buffer pool info available");
    } else {
      $self->valdiff(\%params, qw(bufferpool_wait_free));
      $self->{bufferpool_wait_free_rate} =
          $self->{delta_bufferpool_wait_free} / $self->{delta_timestamp};
    }
  } elsif ($params{mode} =~ /server::instance::innodb::logwaits/) {
    ($dummy, $self->{log_waits})
        = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Innodb_log_waits'
    });
    if (! defined $self->{log_waits}) {
      $self->add_nagios_critical("no innodb log info available");
    } else {
      $self->valdiff(\%params, qw(log_waits));
      $self->{log_waits_rate} =
          $self->{delta_log_waits} / $self->{delta_timestamp};
    }
  } elsif ($params{mode} =~ /server::instance::innodb::needoptimize/) {
#fragmentation=$(($datafree * 100 / $datalength))

#http://www.electrictoolbox.com/optimize-tables-mysql-php/
    my  @result = $self->{handle}->fetchall_array(q{
SHOW TABLE STATUS WHERE Data_free / Data_length > 0.1 AND Data_free > 102400
});
printf "%s\n", Data::Dumper::Dumper(\@result);

  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  my $now = $params{lookback} ? '_now' : '';
  if ($self->{have_innodb} eq "DISABLED") {
    $self->add_nagios_ok("the innodb engine has been disabled");
  } elsif (! $self->{nagios_level}) {
    if ($params{mode} =~ /server::instance::innodb::bufferpool::hitrate/) {
      my $refkey = 'bufferpool_hitrate'.($params{lookback} ? '_now' : '');
      $self->add_nagios(
          $self->check_thresholds($self->{$refkey}, "99:", "95:"),
              sprintf "innodb buffer pool hitrate at %.2f%%", $self->{$refkey});
      $self->add_perfdata(sprintf "bufferpool_hitrate=%.2f%%;%s;%s;0;100",
          $self->{bufferpool_hitrate},
          $self->{warningrange}, $self->{criticalrange});
      $self->add_perfdata(sprintf "bufferpool_hitrate_now=%.2f%%",
          $self->{bufferpool_hitrate_now});
    } elsif ($params{mode} =~ /server::instance::innodb::bufferpool::waitfree/) {
      $self->add_nagios(
          $self->check_thresholds($self->{bufferpool_wait_free_rate}, "1", "10"),
          sprintf "%ld innodb buffer pool waits in %ld seconds (%.4f/sec)",
          $self->{delta_bufferpool_wait_free}, $self->{delta_timestamp},
          $self->{bufferpool_wait_free_rate});
      $self->add_perfdata(sprintf "bufferpool_free_waits_rate=%.4f;%s;%s;0;100",
          $self->{bufferpool_wait_free_rate},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::instance::innodb::logwaits/) {
      $self->add_nagios(
          $self->check_thresholds($self->{log_waits_rate}, "1", "10"),
          sprintf "%ld innodb log waits in %ld seconds (%.4f/sec)",
          $self->{delta_log_waits}, $self->{delta_timestamp},
          $self->{log_waits_rate});
      $self->add_perfdata(sprintf "innodb_log_waits_rate=%.4f;%s;%s;0;100",
          $self->{log_waits_rate},
          $self->{warningrange}, $self->{criticalrange});
    }
  }
}


1;

