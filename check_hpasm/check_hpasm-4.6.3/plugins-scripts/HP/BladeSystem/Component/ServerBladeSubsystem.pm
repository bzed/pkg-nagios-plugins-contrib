package HP::BladeSystem::Component::ServerBladeSubsystem;
our @ISA = qw(HP::BladeSystem::Component);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    method => $params{method},
    server_blades => [],
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  $self->init();
  return $self;
}

sub init {
  my $self = shift;
  my $oids = {
      cpqRackServerBladeEntry => '1.3.6.1.4.1.232.22.2.4.1.1.1',
      cpqRackServerBladeRack => '1.3.6.1.4.1.232.22.2.4.1.1.1.1',
      cpqRackServerBladeChassis => '1.3.6.1.4.1.232.22.2.4.1.1.1.2',
      cpqRackServerBladeIndex => '1.3.6.1.4.1.232.22.2.4.1.1.1.3',
      cpqRackServerBladeName => '1.3.6.1.4.1.232.22.2.4.1.1.1.4',
      cpqRackServerBladeEnclosureName => '1.3.6.1.4.1.232.22.2.4.1.1.1.5',
      cpqRackServerBladePartNumber => '1.3.6.1.4.1.232.22.2.4.1.1.1.6',
      cpqRackServerBladeSparePartNumber => '1.3.6.1.4.1.232.22.2.4.1.1.1.7',
      cpqRackServerBladePosition => '1.3.6.1.4.1.232.22.2.4.1.1.1.8',
      cpqRackServerBladeHeight => '1.3.6.1.4.1.232.22.2.4.1.1.1.9',
      cpqRackServerBladeWidth => '1.3.6.1.4.1.232.22.2.4.1.1.1.10',
      cpqRackServerBladeDepth => '1.3.6.1.4.1.232.22.2.4.1.1.1.11',
      cpqRackServerBladePresent => '1.3.6.1.4.1.232.22.2.4.1.1.1.12',
      cpqRackServerBladeHasFuses => '1.3.6.1.4.1.232.22.2.4.1.1.1.13',
      cpqRackServerBladeEnclosureSerialNum => '1.3.6.1.4.1.232.22.2.4.1.1.1.14',
      cpqRackServerBladeSlotsUsed => '1.3.6.1.4.1.232.22.2.4.1.1.1.15',
      cpqRackServerBladeStatus => '1.3.6.1.4.1.232.22.2.4.1.1.1.21',
      cpqRackServerBladeDiagnosticString => '1.3.6.1.4.1.232.22.2.4.1.1.1.24',
      cpqRackServerBladePowered => '1.3.6.1.4.1.232.22.2.4.1.1.1.25',
      cpqRackServerBladePOSTStatus => '1.3.6.1.4.1.232.22.2.4.1.1.1.35',
      cpqRackServerBladePresentValue => {
          1 => 'other',
          2 => 'absent',
          3 => 'present',
      },
      cpqRackServerBladeStatusValue => {
          1 => 'other',
          2 => 'ok',
          3 => 'degraded',
          4 => 'failed',
      },
      cpqRackServerBladePoweredValue => {
          0 => 'aechz',
          1 => 'other',
          2 => 'on',
          3 => 'off',
          4 => 'powerStagedOff',
          5 => 'reboot',
      },
      cpqRackServerBladePOSTStatusValue => {
          1 => 'other',
          2 => 'started',
          3 => 'completed',
          4 => 'failed',
      },
  };
 
 
  # INDEX { cpqRackServerBladeRack, cpqRackServerBladeChassis, cpqRackServerBladeIndex }
  # dreckada dreck, dreckada
  foreach ($self->get_entries($oids, 'cpqRackServerBladeEntry')) {
    push(@{$self->{server_blades}},
        HP::BladeSystem::Component::ServerBladeSubsystem::ServerBlade->new(%{$_}));
  }
}

sub check {
  my $self = shift;
  foreach (@{$self->{server_blades}}) {
    $_->check() if $_->{cpqRackServerBladePresent} eq 'present' ||
        $self->{runtime}->{options}->{verbose} >= 3; # absent blades nur bei -vvv
  }
}

sub dump {
  my $self = shift;
  foreach (@{$self->{server_blades}}) {
    $_->dump() if $_->{cpqRackServerBladePresent} eq 'present' ||
        $self->{runtime}->{options}->{verbose} >= 3; # absent blades nur bei -vvv
  }
}


package HP::BladeSystem::Component::ServerBladeSubsystem::ServerBlade;
our @ISA = qw(HP::BladeSystem::Component::ServerBladeSubsystem);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    method => $params{method},
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  map { $self->{$_} = $params{$_} } grep /cpqRackServerBlade/, keys %params;
  $self->{cpqRackServerBladeDiagnosticString} ||= '';
  $self->{name} = $self->{cpqRackServerBladeRack}.
      ':'.$self->{cpqRackServerBladeChassis}.
      ':'.$self->{cpqRackServerBladeIndex};
  bless $self, $class;
  $self->init();
#printf "%s\n", Data::Dumper::Dumper(\%params);
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('sb', $self->{name});
  my $info = sprintf 'server blade %s \'%s\' is %s, status is %s, powered is %s',
      $self->{name}, $self->{cpqRackServerBladeName}, $self->{cpqRackServerBladePresent},
      $self->{cpqRackServerBladeStatus}, $self->{cpqRackServerBladePowered};
  $self->add_info($info);
  if ($self->{cpqRackServerBladePowered} eq 'on') {
    if ($self->{cpqRackServerBladeStatus} eq 'degraded') {
      $self->add_message(WARNING, sprintf 'server blade %s diag is \'%s\', post status is %s',
          $self->{cpqRackServerBladeName}, $self->{cpqRackServerBladeDiagnosticString},
          $self->{cpqRackServerBladePOSTStatus});
    } elsif ($self->{cpqRackServerBladeStatus} eq 'failed') {
      $self->add_message(CRITICAL, sprintf 'server blade %s diag is \'%s\', post status is %s',
          $self->{cpqRackServerBladeName}, $self->{cpqRackServerBladeDiagnosticString},
          $self->{cpqRackServerBladePOSTStatus});
    } 
  }
} 
  
sub dump {
  my $self = shift;
    printf "[SERVER_BLADE_%s]\n", $self->{cpqRackServerBladeName};
  foreach (qw(cpqRackServerBladeRack cpqRackServerBladeChassis cpqRackServerBladeIndex cpqRackServerBladeName cpqRackServerBladeEnclosureName cpqRackServerBladePartNumber cpqRackServerBladeSparePartNumber cpqRackServerBladePosition cpqRackServerBladeHeight cpqRackServerBladeWidth cpqRackServerBladeDepth cpqRackServerBladePresent cpqRackServerBladeHasFuses cpqRackServerBladeEnclosureSerialNum cpqRackServerBladeSlotsUsed cpqRackServerBladeStatus cpqRackServerBladeDiagnosticString cpqRackServerBladePowered cpqRackServerBladePOSTStatus)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


1;
