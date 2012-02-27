package DBD::MySQL::Server::Instance::Replication;

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
  if ($params{mode} =~ /server::instance::replication/) {
    $self->{internals} =
        DBD::MySQL::Server::Instance::Replication::Internals->new(%params);
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if ($params{mode} =~ /server::instance::replication/) {
    $self->{internals}->nagios(%params);
    $self->merge_nagios($self->{internals});
  }
}


package DBD::MySQL::Server::Instance::Replication::Internals;

use strict;

our @ISA = qw(DBD::MySQL::Server::Instance::Replication);

our $internals; # singleton, nur ein einziges mal instantiierbar

sub new {
  my $class = shift;
  my %params = @_;
  unless ($internals) {
    $internals = {
      handle => $params{handle},
      seconds_behind_master => undef,
      slave_io_running => undef,
      slave_sql_running => undef,
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
  $self->debug("enter init");
  $self->init_nagios();
  if ($params{mode} =~ /server::instance::replication::slavelag/) {
    # "show slave status", "Seconds_Behind_Master"
    my $slavehash = $self->{handle}->selectrow_hashref(q{
            SHOW SLAVE STATUS
        });
    if ((! defined $slavehash->{Seconds_Behind_Master}) && 
        (lc $slavehash->{Slave_IO_Running} eq 'no')) {
      $self->add_nagios_critical(
          "unable to get slave lag, because io thread is not running");
    } elsif (! defined $slavehash->{Seconds_Behind_Master}) {
      $self->add_nagios_critical(sprintf "unable to get replication info%s",
          $self->{handle}->{errstr} ? $self->{handle}->{errstr} : "");
    } else {
      $self->{seconds_behind_master} = $slavehash->{Seconds_Behind_Master};
    }
  } elsif ($params{mode} =~ /server::instance::replication::slaveiorunning/) {
    # "show slave status", "Slave_IO_Running"
    my $slavehash = $self->{handle}->selectrow_hashref(q{
            SHOW SLAVE STATUS
        });
    if (! defined $slavehash->{Slave_IO_Running}) {
      $self->add_nagios_critical(sprintf "unable to get replication info%s",
          $self->{handle}->{errstr} ? $self->{handle}->{errstr} : "");
    } else {
      $self->{slave_io_running} = $slavehash->{Slave_IO_Running};
    }
  } elsif ($params{mode} =~ /server::instance::replication::slavesqlrunning/) {
    # "show slave status", "Slave_SQL_Running"
    my $slavehash = $self->{handle}->selectrow_hashref(q{
            SHOW SLAVE STATUS
        });
    if (! defined $slavehash->{Slave_SQL_Running}) {
      $self->add_nagios_critical(sprintf "unable to get replication info%s",
          $self->{handle}->{errstr} ? $self->{handle}->{errstr} : "");
    } else {
      $self->{slave_sql_running} = $slavehash->{Slave_SQL_Running};
    }
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ /server::instance::replication::slavelag/) {
      $self->add_nagios(
          $self->check_thresholds($self->{seconds_behind_master}, "10", "20"),
          sprintf "Slave is %d seconds behind master",
          $self->{seconds_behind_master});
      $self->add_perfdata(sprintf "slave_lag=%d;%s;%s",
          $self->{seconds_behind_master},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::instance::replication::slaveiorunning/) {
      if (lc $self->{slave_io_running} eq "yes") {
        $self->add_nagios_ok("Slave io is running");
      } else {
        $self->add_nagios_critical("Slave io is not running");
      }
    } elsif ($params{mode} =~ /server::instance::replication::slavesqlrunning/) {
      if (lc $self->{slave_sql_running} eq "yes") {
        $self->add_nagios_ok("Slave sql is running");
      } else {
        $self->add_nagios_critical("Slave sql is not running");
      }
    }
  }
}


1;
