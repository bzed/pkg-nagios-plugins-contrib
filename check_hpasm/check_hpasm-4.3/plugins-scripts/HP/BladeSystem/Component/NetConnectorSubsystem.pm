package HP::BladeSystem::Component::NetConnectorSubsystem;
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
    net_connectors => [],
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
      cpqRackNetConnectorEntry => '1.3.6.1.4.1.232.22.2.6.1.1.1',
      cpqRackNetConnectorRack => '1.3.6.1.4.1.232.22.2.6.1.1.1.1',
      cpqRackNetConnectorChassis => '1.3.6.1.4.1.232.22.2.6.1.1.1.2',
      cpqRackNetConnectorIndex => '1.3.6.1.4.1.232.22.2.6.1.1.1.3',
      cpqRackNetConnectorEnclosureName => '1.3.6.1.4.1.232.22.2.6.1.1.1.4',
      cpqRackNetConnectorName => '1.3.6.1.4.1.232.22.2.6.1.1.1.5',
      cpqRackNetConnectorModel => '1.3.6.1.4.1.232.22.2.6.1.1.1.6',
      cpqRackNetConnectorSerialNum => '1.3.6.1.4.1.232.22.2.6.1.1.1.7',
      cpqRackNetConnectorPartNumber => '1.3.6.1.4.1.232.22.2.6.1.1.1.8',
      cpqRackNetConnectorSparePartNumber => '1.3.6.1.4.1.232.22.2.6.1.1.1.9',
      cpqRackNetConnectorFWRev => '1.3.6.1.4.1.232.22.2.6.1.1.1.10',
      cpqRackNetConnectorType => '1.3.6.1.4.1.232.22.2.6.1.1.1.11',
      cpqRackNetConnectorLocation => '1.3.6.1.4.1.232.22.2.6.1.1.1.12',
      cpqRackNetConnectorPresent => '1.3.6.1.4.1.232.22.2.6.1.1.1.13',
      cpqRackNetConnectorHasFuses => '1.3.6.1.4.1.232.22.2.6.1.1.1.14',
      cpqRackNetConnectorEnclosureSerialNum => '1.3.6.1.4.1.232.22.2.6.1.1.1.15',
      cpqRackNetConnectorTypeValue => {
          0 => 'other', # undefined
          1 => 'other',
          2 => 'active',
          3 => 'passive',
      },
      cpqRackNetConnectorPresentValue => {
          1 => 'other',
          2 => 'absent',
          3 => 'present',
      },
      cpqRackNetConnectorHasFusesValue => {
          -1 => 'false', # wird geliefert, also vermute ich false
          1 => 'false',
          2 => 'true',
      },
  };
 
 
  # INDEX { cpqRackNetConnectorRack, cpqRackNetConnectorChassis, cpqRackNetConnectorIndex }
  # dreckada dreck, dreckada
  foreach ($self->get_entries($oids, 'cpqRackNetConnectorEntry')) {
    push(@{$self->{net_connectors}},
        HP::BladeSystem::Component::NetConnectorSubsystem::NetConnector->new(%{$_}));
  }
}

sub check {
  my $self = shift;
  foreach (@{$self->{net_connectors}}) {
    $_->check() if $_->{cpqRackNetConnectorPresent} eq 'present' ||
        $self->{runtime}->{options}->{verbose} >= 3; # absent nur bei -vvv
  }
}

sub dump {
  my $self = shift;
  foreach (@{$self->{net_connectors}}) {
    $_->dump() if $_->{cpqRackNetConnectorPresent} eq 'present' ||
        $self->{runtime}->{options}->{verbose} >= 3; # absent nur bei -vvv
  }
}


package HP::BladeSystem::Component::NetConnectorSubsystem::NetConnector;
our @ISA = qw(HP::BladeSystem::Component::NetConnectorSubsystem);

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
  map { $self->{$_} = $params{$_} } grep /cpqRackNetConnector/, keys %params;
  $self->{name} = $params{cpqRackNetConnectorRack}.
      ':'.$params{cpqRackNetConnectorChassis}.
      ':'.$params{cpqRackNetConnectorIndex};
  $self->{serfw} = sprintf "Ser: %s, FW: %s", $self->{cpqRackNetConnectorSerialNum}, $self->{cpqRackNetConnectorFWRev};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('nc', $self->{name});
  my $info = sprintf 'net connector %s is %s, model is %s (%s)', 
      $self->{name}.($self->{cpqRackNetConnectorName} ? ' \''.$self->{cpqRackNetConnectorName}.'\'' : ''),
      $self->{cpqRackNetConnectorPresent}, $self->{cpqRackNetConnectorModel}, $self->{serfw};
  $self->add_info($info);
  # hat weder status noch condition, vielleicht spaeter mal
  $info .= sprintf " (SparePartNum %s)", $self->{cpqRackNetConnectorSparePartNumber};
} 
  
sub dump {
  my $self = shift;
    printf "[NET_CONNECTOR_%s]\n", $self->{cpqRackNetConnectorName};
  foreach (qw(cpqRackNetConnectorRack cpqRackNetConnectorChassis cpqRackNetConnectorIndex cpqRackNetConnectorEnclosureName cpqRackNetConnectorName cpqRackNetConnectorModel cpqRackNetConnectorSerialNum cpqRackNetConnectorPartNumber cpqRackNetConnectorSparePartNumber cpqRackNetConnectorFWRev cpqRackNetConnectorType cpqRackNetConnectorLocation cpqRackNetConnectorPresent cpqRackNetConnectorHasFuses cpqRackNetConnectorEnclosureSerialNum)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


1;
