package HP::BladeSystem::Component::CommonEnclosureSubsystem::ManagerSubsystem;
our @ISA = qw(HP::BladeSystem::Component::CommonEnclosureSubsystem);

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
    managers => [],
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
      cpqRackCommonEnclosureManagerEntry => '1.3.6.1.4.1.232.22.2.3.1.6.1',
      cpqRackCommonEnclosureManagerRack => '1.3.6.1.4.1.232.22.2.3.1.6.1.1',
      cpqRackCommonEnclosureManagerChassis => '1.3.6.1.4.1.232.22.2.3.1.6.1.2',
      cpqRackCommonEnclosureManagerIndex => '1.3.6.1.4.1.232.22.2.3.1.6.1.3',
      cpqRackCommonEnclosureManagerEnclosureName => '1.3.6.1.4.1.232.22.2.3.1.6.1.4',
      cpqRackCommonEnclosureManagerLocation => '1.3.6.1.4.1.232.22.2.3.1.6.1.5',
      cpqRackCommonEnclosureManagerPartNumber => '1.3.6.1.4.1.232.22.2.3.1.6.1.6',
      cpqRackCommonEnclosureManagerSparePartNumber => '1.3.6.1.4.1.232.22.2.3.1.6.1.7',
      cpqRackCommonEnclosureManagerSerialNum => '1.3.6.1.4.1.232.22.2.3.1.6.1.8',
      cpqRackCommonEnclosureManagerRole => '1.3.6.1.4.1.232.22.2.3.1.6.1.9',
      cpqRackCommonEnclosureManagerPresent => '1.3.6.1.4.1.232.22.2.3.1.6.1.10',
      cpqRackCommonEnclosureManagerRedundant => '1.3.6.1.4.1.232.22.2.3.1.6.1.11',
      cpqRackCommonEnclosureManagerCondition => '1.3.6.1.4.1.232.22.2.3.1.6.1.12',
      cpqRackCommonEnclosureManagerFWRev => '1.3.6.1.4.1.232.22.2.3.1.6.1.15',
      cpqRackCommonEnclosureManagerRoleValue => {
          1 => 'standby',
          2 => 'active',
      },
      cpqRackCommonEnclosureManagerPresentValue => {
          1 => 'other',
          2 => 'absent', # mit vorsicht zu geniessen!
          3 => 'present',
      },
      cpqRackCommonEnclosureManagerRedundantValue => {
          0 => 'other', # meiner phantasie entsprungen, da sich hp nicht aeussert
          1 => 'other',
          2 => 'notRedundant',
          3 => 'redundant',
      },
      cpqRackCommonEnclosureManagerConditionValue => {
          1 => 'other',
          2 => 'ok',
          3 => 'degraded',
          4 => 'failed',
      }
  };
  # INDEX { cpqRackCommonEnclosureManagerRack, cpqRackCommonEnclosureManagerChassis, cpqRackCommonEnclosureManagerIndex }
  foreach ($self->get_entries($oids, 'cpqRackCommonEnclosureManagerEntry')) {
    push(@{$self->{managers}},
        HP::BladeSystem::Component::CommonEnclosureSubsystem::ManagerSubsystem::Manager->new(%{$_}));
  }
}

sub check {
  my $self = shift;
  foreach (@{$self->{managers}}) {
    $_->check() if $_->{cpqRackCommonEnclosureManagerPresent} eq 'present' ||
        $self->{runtime}->{options}->{verbose} >= 3; # absent nur bei -vvv
  }
}

sub dump {
  my $self = shift;
  foreach (@{$self->{managers}}) {
    $_->dump() if $_->{cpqRackCommonEnclosureManagerPresent} eq 'present' ||
        $self->{runtime}->{options}->{verbose} >= 3; # absent nur bei -vvv
  }
}


package HP::BladeSystem::Component::CommonEnclosureSubsystem::ManagerSubsystem::Manager;

our @ISA = qw(HP::BladeSystem::Component::CommonEnclosureSubsystem::ManagerSubsystem);

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
  map { $self->{$_} = $params{$_} } grep /cpqRackCommonEnclosureManager/, keys %params;
  $self->{name} = $self->{cpqRackCommonEnclosureManagerRack}.
      ':'.$self->{cpqRackCommonEnclosureManagerChassis}.
      ':'.$self->{cpqRackCommonEnclosureManagerIndex};
  if ($self->{cpqRackCommonEnclosureManagerPresent} eq "absent" &&
      defined $self->{cpqRackCommonEnclosureManagerEnclosureName}) {
    $self->{cpqRackCommonEnclosureManagerPresent} = "present";
  }
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('em', $self->{name});
  my $info = sprintf 'manager %s is %s, location is %s, redundance is %s, condition is %s, role is %s',
      $self->{name}, $self->{cpqRackCommonEnclosureManagerPresent},
      $self->{cpqRackCommonEnclosureManagerLocation},
      $self->{cpqRackCommonEnclosureManagerRedundant},
      $self->{cpqRackCommonEnclosureManagerCondition},
      $self->{cpqRackCommonEnclosureManagerRole};
  $self->add_info($info) if $self->{cpqRackCommonEnclosureManagerPresent} eq 'present' ||
      $self->{runtime}->{options}->{verbose} >= 3; # absent managers nur bei -vvv
  if ($self->{cpqRackCommonEnclosureManagerCondition} eq 'degraded') {
    $self->{info} .= sprintf ' (SparePartNum: %s)',
        $self->{cpqRackCommonEnclosureManagerSparePartNumber};
    $self->add_message(WARNING, $self->{info});
  } elsif ($self->{cpqRackCommonEnclosureManagerCondition} eq 'failed') {
    $self->{info} .= sprintf ' (SparePartNum: %s)',
        $self->{cpqRackCommonEnclosureManagerSparePartNumber};
    $self->add_message(CRITICAL, $self->{info});
  }
}

sub dump {
  my $self = shift;
  printf "[ENCLOSURE_MANAGER_%s]\n", $self->{name};
  foreach (qw(cpqRackCommonEnclosureManagerRack cpqRackCommonEnclosureManagerChassis 
      cpqRackCommonEnclosureManagerIndex cpqRackCommonEnclosureManagerEnclosureName 
      cpqRackCommonEnclosureManagerLocation cpqRackCommonEnclosureManagerPartNumber 
      cpqRackCommonEnclosureManagerSparePartNumber cpqRackCommonEnclosureManagerPresent 
      cpqRackCommonEnclosureManagerRedundant 
      cpqRackCommonEnclosureManagerCondition cpqRackCommonEnclosureManagerFWRev)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}

1;
