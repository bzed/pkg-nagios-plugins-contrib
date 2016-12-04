package HP::Proliant::Component::DiskSubsystem::Ide;
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
    bless $self, 'HP::Proliant::Component::DiskSubsystem::Ide::SNMP';
  } else {
    bless $self, 'HP::Proliant::Component::DiskSubsystem::Ide::CLI';
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

package HP::Proliant::Component::DiskSubsystem::Ide::Controller;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Ide);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    cpqIdeControllerIndex => $params{cpqIdeControllerIndex},
    cpqIdeControllerOverallCondition => $params{cpqIdeControllerOverallCondition},
    cpqIdeControllerModel => $params{cpqIdeControllerModel},
    cpqIdeControllerSlot => $params{cpqIdeControllerSlot}, # -1 ist sysboard?
    blacklisted => 0,
  };
  $self->{name} = $params{name} || $self->{cpqIdeControllerIndex};
  $self->{controllerindex} = $self->{cpqIdeControllerIndex};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('ideco', $self->{name});
  if ($self->{cpqIdeControllerOverallCondition} eq 'other') {
    if (scalar(@{$self->{physical_drives}})) {
      $self->add_message(CRITICAL,
          sprintf 'ide controller %s in slot %s needs attention',
              $self->{cpqIdeControllerIndex}, $self->{cpqIdeControllerSlot});
      $self->add_info(sprintf 'ide controller %s in slot %s needs attention',
          $self->{cpqIdeControllerIndex}, $self->{cpqIdeControllerSlot});
    } else {
      $self->add_info(sprintf 'ide controller %s in slot %s is ok and unused',
          $self->{cpqIdeControllerIndex}, $self->{cpqIdeControllerSlot});
      $self->{blacklisted} = 1;
    }
  } elsif ($self->{cpqIdeControllerOverallCondition} ne 'ok') {
    $self->add_message(CRITICAL,
        sprintf 'ide controller %s in slot %s needs attention',
            $self->{cpqIdeControllerIndex}, $self->{cpqIdeControllerSlot});
    $self->add_info(sprintf 'ide controller %s in slot %s needs attention',
        $self->{cpqIdeControllerIndex}, $self->{cpqIdeControllerSlot});
  } else {
    $self->add_info(sprintf 'ide controller %s in slot %s is ok',
        $self->{cpqIdeControllerIndex}, $self->{cpqIdeControllerSlot});
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
  printf "[IDE_CONTROLLER_%s]\n", $self->{name};
  foreach (qw(cpqIdeControllerIndex cpqIdeControllerSlot
      cpqIdeControllerModel cpqIdeControllerOverallCondition)) {
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


package HP::Proliant::Component::DiskSubsystem::Ide::LogicalDrive;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Ide);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    cpqIdeLogicalDriveControllerIndex => $params{cpqIdeLogicalDriveControllerIndex},
    cpqIdeLogicalDriveIndex => $params{cpqIdeLogicalDriveIndex},
    cpqIdeLogicalDriveRaidLevel => $params{cpqIdeLogicalDriveRaidLevel},
    cpqIdeLogicalDriveCapacity => $params{cpqIdeLogicalDriveCapacity},
    cpqIdeLogicalDriveStatus => $params{cpqIdeLogicalDriveStatus},
    cpqIdeLogicalDriveCondition => $params{cpqIdeLogicalDriveCondition},
    cpqIdeLogicalDriveDiskIds => $params{cpqIdeLogicalDriveDiskIds},
    cpqIdeLogicalDriveSpareIds => $params{cpqIdeLogicalDriveSpareIds},
    cpqIdeLogicalDriveRebuildingDisk => $params{cpqIdeLogicalDriveRebuildingDisk},
    blacklisted => 0,
  };
  bless $self, $class;
  $self->{name} = $params{name} || 
      $self->{cpqIdeLogicalDriveControllerIndex}.':'.
      $self->{cpqIdeLogicalDriveIndex};
  $self->{controllerindex} = $self->{cpqIdeLogicalDriveControllerIndex};
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('ideld', $self->{name});
  if ($self->{cpqIdeLogicalDriveCondition} ne "ok") {
    if ($self->{cpqIdeLogicalDriveStatus} =~ 
        /rebuild/) {
      $self->add_message(WARNING,
          sprintf "logical drive %s is %s", 
              $self->{name}, $self->{cpqIdeLogicalDriveStatus});
    } else {
      $self->add_message(CRITICAL,
          sprintf "logical drive %s is %s",
              $self->{name}, $self->{cpqIdeLogicalDriveStatus});
    }
  } 
  $self->add_info(
      sprintf "logical drive %s is %s", $self->{name},
          $self->{cpqIdeLogicalDriveStatus});
}

sub dump {
  my $self = shift;
  printf "[LOGICAL_DRIVE]\n";
  foreach (qw(cpqIdeLogicalDriveControllerIndex cpqIdeLogicalDriveIndex
      cpqIdeLogicalDriveRaidLevel cpqIdeLogicalDriveCapacity 
      cpqIdeLogicalDriveDiskIds cpqIdeLogicalDriveSpareIds 
      cpqIdeLogicalDriveRebuildingDisk cpqIdeLogicalDriveStatus 
      cpqIdeLogicalDriveCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


package HP::Proliant::Component::DiskSubsystem::Ide::PhysicalDrive;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Ide);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    cpqIdeAtaDiskControllerIndex => $params{cpqIdeAtaDiskControllerIndex},
    cpqIdeAtaDiskIndex => $params{cpqIdeAtaDiskIndex},
    cpqIdeAtaDiskModel => $params{cpqIdeAtaDiskModel},
    cpqIdeAtaDiskStatus => $params{cpqIdeAtaDiskStatus},
    cpqIdeAtaDiskCondition => $params{cpqIdeAtaDiskCondition},
    cpqIdeAtaDiskCapacity => $params{cpqIdeAtaDiskCapacity},
    cpqIdeAtaDiskLogicalDriveMember => $params{cpqIdeAtaDiskLogicalDriveMember},
    cpqIdeAtaDiskIsSpare => $params{cpqIdeAtaDiskIsSpare},
    blacklisted => 0,
  };
  $self->{name} = $params{name} || 
      $self->{cpqIdeAtaDiskControllerIndex}.':'.
      $self->{cpqIdeAtaDiskIndex}; ####vorerst
  $self->{controllerindex} = $self->{cpqIdeAtaDiskControllerIndex};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('idepd', $self->{name});
  if ($self->{cpqIdeAtaDiskCondition} ne 'ok') {
    $self->add_message(CRITICAL,
        sprintf "physical drive %s is %s", 
            $self->{name}, $self->{cpqIdeAtaDiskCondition});
  }
  $self->add_info(
      sprintf "physical drive %s is %s", 
          $self->{name}, $self->{cpqIdeAtaDiskCondition});
}

sub dump {
  my $self = shift;
  printf "[PHYSICAL_DRIVE]\n";
  foreach (qw(cpqIdeAtaDiskControllerIndex cpqIdeAtaDiskIndex
      cpqIdeAtaDiskModel cpqIdeAtaDiskCapacity cpqIdeAtaDiskLogicalDriveMember 
      cpqIdeAtaDiskStatus cpqIdeAtaDiskCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


package HP::Proliant::Component::DiskSubsystem::Ide::SpareDrive;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Ide);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub dump {
  my $self = shift;
  printf "[SPARE_DRIVE]\n";
}


1;
