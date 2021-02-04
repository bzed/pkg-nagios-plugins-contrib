package HP::Proliant::Component::DiskSubsystem::Sas;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    method => $params{method},
    controllers => [],
    enclosures => [],
    physical_drives => [],
    logical_drives => [],
    spare_drives => [],
    condition => undef,
    blacklisted => 0,
  };
  bless $self, $class;
  if ($self->{method} eq 'snmp') {
    bless $self, 'HP::Proliant::Component::DiskSubsystem::Sas::SNMP';
  } else {
    bless $self, 'HP::Proliant::Component::DiskSubsystem::Sas::CLI';
  }
  $self->init();
  $self->assemble();
  return $self;
}

sub check {
  my $self = shift;
  foreach (@{$self->{controllers}}) {
    $_->check();
  }
}

sub dump {
  my $self = shift;
  foreach (@{$self->{controllers}}) {
    $_->dump();
  }
}

package HP::Proliant::Component::DiskSubsystem::Sas::Controller;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Sas);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    cpqSasHbaIndex => $params{cpqSasHbaIndex},
    cpqSasHbaLocation => $params{cpqSasHbaLocation},
    cpqSasHbaSlot => $params{cpqSasHbaSlot},
    cpqSasHbaStatus => $params{cpqSasHbaStatus},
    cpqSasHbaCondition => $params{cpqSasHbaCondition},
    blacklisted => 0,
  };
  $self->{name} = $params{name} || $self->{cpqSasHbaSlot};
  $self->{controllerindex} = $self->{cpqSasHbaIndex};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('saco', $self->{cpqSasHbaSlot});
  if ($self->{cpqSasHbaCondition} eq 'other') {
    if (scalar(@{$self->{physical_drives}})) {
      $self->add_message(CRITICAL,
          sprintf 'sas controller in slot %s needs attention',
              $self->{cpqSasHbaSlot});
      $self->add_info(sprintf 'sas controller in slot %s needs attention',
          $self->{cpqSasHbaSlot});
    } else {
      $self->add_info(sprintf 'sas controller in slot %s is ok and unused',
          $self->{cpqSasHbaSlot});
      $self->{blacklisted} = 1;
    }
  } elsif ($self->{cpqSasHbaCondition} ne 'ok') {
    $self->add_message(CRITICAL,
        sprintf 'sas controller in slot %s needs attention',
            $self->{cpqSasHbaSlot});
    $self->add_info(sprintf 'sas controller in slot %s needs attention',
        $self->{cpqSasHbaSlot});
  } else {
    $self->add_info(sprintf 'sas controller in slot %s is ok',
        $self->{cpqSasHbaSlot});
  }
  foreach (@{$self->{logical_drives}}) {
    $_->check();
  } 
  foreach (@{$self->{physical_drives}}) {
    $_->check();
  } 
  foreach (@{$self->{spare_drives}}) {
    $_->check();
  } 
} 

sub dump {
  my $self = shift;
  printf "[SAS_HBA%s]\n", $self->{name};
  foreach (qw(cpqSasHbaSlot cpqSasHbaIndex cpqSasHbaCondition
      cpqSasHbaStatus cpqSasHbaLocation)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
  foreach (@{$self->{logical_drives}}) {
    $_->dump();
  }
  foreach (@{$self->{physical_drives}}) {
    $_->dump();
  }
  foreach (@{$self->{spare_drives}}) {
    $_->dump();
  }
}


package HP::Proliant::Component::DiskSubsystem::Sas::LogicalDrive;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Sas);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    cpqSasLogDrvHbaIndex => $params{cpqSasLogDrvHbaIndex},
    cpqSasLogDrvIndex => $params{cpqSasLogDrvIndex},
    cpqSasLogDrvStatus => $params{cpqSasLogDrvStatus},
    cpqSasLogDrvCondition => $params{cpqSasLogDrvCondition},
    cpqSasLogDrvRebuildingPercent => $params{cpqSasLogDrvRebuildingPercent},
    cpqSasLogDrvRaidLevel => $params{cpqSasLogDrvRaidLevel},
    blacklisted => 0,
  };
  bless $self, $class;
  $self->{name} = $params{name} || 
      $self->{cpqSasLogDrvHbaIndex}.':'.$self->{cpqSasLogDrvIndex}; ####vorerst
  $self->{controllerindex} = $self->{cpqSasLogDrvHbaIndex};
  if (! $self->{cpqSasLogDrvRebuildingPercent} ||
      $self->{cpqSasLogDrvRebuildingPercent} == 4294967295) {
    $self->{cpqSasLogDrvRebuildingPercent} = 100;
  }
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('sald', $self->{name});
  if ($self->{cpqSasLogDrvCondition} ne "ok") {
    if ($self->{cpqSasLogDrvStatus} =~ 
        /rebuild|recovering|expanding|queued/) {
      $self->add_message(WARNING,
          sprintf "logical drive %s is %s", 
              $self->{name}, $self->{cpqSasLogDrvStatus});
    } else {
      $self->add_message(CRITICAL,
          sprintf "logical drive %s is %s",
              $self->{name}, $self->{cpqSasLogDrvStatus});
    }
  } 
  $self->add_info(
      sprintf "logical drive %s is %s (%s)", $self->{name},
          $self->{cpqSasLogDrvStatus}, $self->{cpqSasLogDrvRaidLevel});
}

sub dump {
  my $self = shift;
  printf "[LOGICAL_DRIVE]\n";
  foreach (qw(cpqSasLogDrvHbaIndex cpqSasLogDrvIndex cpqSasLogDrvRaidLevel
      cpqSasLogDrvStatus cpqSasLogDrvCondition
      cpqSasLogDrvRebuildingPercent)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


package HP::Proliant::Component::DiskSubsystem::Sas::PhysicalDrive;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Sas);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    cpqSasPhyDrvHbaIndex => $params{cpqSasPhyDrvHbaIndex},
    cpqSasPhyDrvIndex => $params{cpqSasPhyDrvIndex},
    cpqSasPhyDrvLocationString => $params{cpqSasPhyDrvLocationString},
    cpqSasPhyDrvStatus => $params{cpqSasPhyDrvStatus},
    cpqSasPhyDrvSize => $params{cpqSasPhyDrvSize},
    cpqSasPhyDrvCondition => $params{cpqSasPhyDrvCondition},
    blacklisted => 0,
  };
  $self->{name} = $params{name} || 
      $self->{cpqSasPhyDrvHbaIndex}.':'.$self->{cpqSasPhyDrvIndex}; ####vorerst
  $self->{controllerindex} = $self->{cpqSasPhyDrvHbaIndex};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('sapd', $self->{name});
  if ($self->{cpqSasPhyDrvCondition} ne 'ok') {
    $self->add_message(CRITICAL,
        sprintf "physical drive %s is %s", 
            $self->{name}, $self->{cpqSasPhyDrvCondition});
  }
  $self->add_info(
      sprintf "physical drive %s is %s", 
          $self->{name}, $self->{cpqSasPhyDrvCondition});
}

sub dump {
  my $self = shift;
  printf "[PHYSICAL_DRIVE]\n";
  foreach (qw(cpqSasPhyDrvHbaIndex cpqSasPhyDrvIndex cpqSasPhyDrvLocationString
      cpqSasPhyDrvSize cpqSasPhyDrvStatus cpqSasPhyDrvCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


package HP::Proliant::Component::DiskSubsystem::Sas::SpareDrive;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Sas);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub dump {
  my $self = shift;
  printf "[SPARE_DRIVE]\n";
}


1;
