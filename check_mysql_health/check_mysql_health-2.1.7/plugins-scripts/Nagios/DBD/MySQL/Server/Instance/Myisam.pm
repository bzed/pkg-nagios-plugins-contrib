package DBD::MySQL::Server::Instance::MyISAM;

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
  if ($params{mode} =~ /server::instance::myisam/) {
    $self->{internals} =
        DBD::MySQL::Server::Instance::MyISAM::Internals->new(%params);
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if ($params{mode} =~ /server::instance::myisam/) {
    $self->{internals}->nagios(%params);
    $self->merge_nagios($self->{internals});
  }
}


package DBD::MySQL::Server::Instance::MyISAM::Internals;

use strict;

our @ISA = qw(DBD::MySQL::Server::Instance::MyISAM);

our $internals; # singleton, nur ein einziges mal instantiierbar

sub new {
  my $class = shift;
  my %params = @_;
  unless ($internals) {
    $internals = {
      handle => $params{handle},
      keycache_hitrate => undef,
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
  if ($params{mode} =~ /server::instance::myisam::keycache::hitrate/) {
    ($dummy, $self->{key_reads})
        = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Key_reads'
    });
    ($dummy, $self->{key_read_requests})
        = $self->{handle}->fetchrow_array(q{
        SHOW /*!50000 global */ STATUS LIKE 'Key_read_requests'
    });
    if (! defined $self->{key_read_requests}) {
      $self->add_nagios_critical("no myisam keycache info available");
    } else {
      $self->valdiff(\%params, qw(key_reads key_read_requests));
      $self->{keycache_hitrate} =
          $self->{key_read_requests} > 0 ?
          100 - (100 * $self->{key_reads} /
              $self->{key_read_requests}) : 100;
      $self->{keycache_hitrate_now} =
          $self->{delta_key_read_requests} > 0 ?
          100 - (100 * $self->{delta_key_reads} /
              $self->{delta_key_read_requests}) : 100;
    }
  } elsif ($params{mode} =~ /server::instance::myisam::sonstnochwas/) {
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ /server::instance::myisam::keycache::hitrate/) {
      my $refkey = 'keycache_hitrate'.($params{lookback} ? '_now' : '');
      $self->add_nagios(
          $self->check_thresholds($self->{$refkey}, "99:", "95:"),
              sprintf "myisam keycache hitrate at %.2f%%", $self->{$refkey});
      $self->add_perfdata(sprintf "keycache_hitrate=%.2f%%;%s;%s",
          $self->{keycache_hitrate},
          $self->{warningrange}, $self->{criticalrange});
      $self->add_perfdata(sprintf "keycache_hitrate_now=%.2f%%;%s;%s",
          $self->{keycache_hitrate_now},
          $self->{warningrange}, $self->{criticalrange});
    }
  }
}

1;
