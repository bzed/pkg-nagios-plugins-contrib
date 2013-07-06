package HP::BladeSystem::Component::PowerEnclosureSubsystem;
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
    power_enclosures => [],
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

# cpqRackPowerEnclosureTable
  my $oids = {
      cpqRackPowerEnclosureEntry => '1.3.6.1.4.1.232.22.2.3.3.1.1',
      cpqRackPowerEnclosureRack => '1.3.6.1.4.1.232.22.2.3.3.1.1.1',
      cpqRackPowerEnclosureIndex => '1.3.6.1.4.1.232.22.2.3.3.1.1.2',
      cpqRackPowerEnclosureName => '1.3.6.1.4.1.232.22.2.3.3.1.1.3',
      cpqRackPowerEnclosureMgmgtBoardSerialNum => '1.3.6.1.4.1.232.22.2.3.3.1.1.4',
      cpqRackPowerEnclosureRedundant => '1.3.6.1.4.1.232.22.2.3.3.1.1.5',
      cpqRackPowerEnclosureLoadBalanced => '1.3.6.1.4.1.232.22.2.3.3.1.1.6',
      cpqRackPowerEnclosureInputPwrType => '1.3.6.1.4.1.232.22.2.3.3.1.1.7',
      cpqRackPowerEnclosurePwrFeedMax => '1.3.6.1.4.1.232.22.2.3.3.1.1.8',
      cpqRackPowerEnclosureCondition => '1.3.6.1.4.1.232.22.2.3.3.1.1.9',
      cpqRackPowerEnclosureRedundantValue => {
          1 => 'other',
          2 => 'notRedundant',
          3 => 'redundant',
      },
      cpqRackPowerEnclosureLoadBalancedValue => {
          0 => 'aechz',
          1 => 'other',
          2 => 'notLoadBalanced',
          3 => 'loadBalanced',
      },
      cpqRackPowerEnclosureInputPwrTypeValue => {
          1 => 'other',
          2 => 'singlePhase',
          3 => 'threePhase',
          4 => 'directCurrent',
      },
      cpqRackPowerEnclosureConditionValue => {
          1 => 'other',
          2 => 'ok',
          3 => 'degraded',
      },
  };
 
 
  # INDEX { cpqRackPowerEnclosureRack, cpqRackPowerEnclosureIndex }
  # dreckada dreck, dreckada
  foreach ($self->get_entries($oids, 'cpqRackPowerEnclosureEntry')) {
    push(@{$self->{power_enclosures}},
        HP::BladeSystem::Component::PowerEnclosureSubsystem::PowerEnclosure->new(%{$_}));
  }
}

sub check {
  my $self = shift;
  foreach (@{$self->{power_enclosures}}) {
    $_->check();
  }
}

sub dump {
  my $self = shift;
  foreach (@{$self->{power_enclosures}}) {
    $_->dump();
  }
}


package HP::BladeSystem::Component::PowerEnclosureSubsystem::PowerEnclosure;
our @ISA = qw(HP::BladeSystem::Component::PowerEnclosureSubsystem);

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
  map { $self->{$_} = $params{$_} } grep /cpqRackPowerEnclosure/, keys %params;
  $self->{name} = $self->{cpqRackPowerEnclosureRack}.':'.$self->{cpqRackPowerEnclosureIndex};
  bless $self, $class;
  $self->init();
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('pe', $self->{name});
  my $info = sprintf 'power enclosure %s \'%s\' condition is %s',
      $self->{name}, $self->{cpqRackPowerEnclosureName}, $self->{cpqRackPowerEnclosureCondition};
  $self->add_info($info);
  if ($self->{cpqRackPowerEnclosureCondition} eq 'degraded') {
    $self->add_message(WARNING, $info);
  } 
} 
  
sub dump {
  my $self = shift;
    printf "[POWER_ENCLOSURE_%s]\n", $self->{cpqRackPowerEnclosureName};
  foreach (qw(cpqRackPowerEnclosureRack cpqRackPowerEnclosureIndex 
      cpqRackPowerEnclosureName cpqRackPowerEnclosureMgmgtBoardSerialNum
      cpqRackPowerEnclosureRedundant cpqRackPowerEnclosureLoadBalanced
      cpqRackPowerEnclosureInputPwrType cpqRackPowerEnclosurePwrFeedMax
      cpqRackPowerEnclosureCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


1;
