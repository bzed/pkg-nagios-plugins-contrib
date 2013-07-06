package HP::Proliant::Component::DiskSubsystem::Da;
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
    accelerators => [],
    physical_drives => [],
    logical_drives => [],
    spare_drives => [],
    condition => undef,
    blacklisted => 0,
  };
  bless $self, $class;
  if ($self->{method} eq 'snmp') {
    bless $self, 'HP::Proliant::Component::DiskSubsystem::Da::SNMP';
  } else {
    bless $self, 'HP::Proliant::Component::DiskSubsystem::Da::CLI';
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

package HP::Proliant::Component::DiskSubsystem::Da::Controller;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Da);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    cpqDaCntlrIndex => $params{cpqDaCntlrIndex},
    cpqDaCntlrSlot => $params{cpqDaCntlrSlot},
    cpqDaCntlrModel => $params{cpqDaCntlrModel},
    cpqDaCntlrCondition => $params{cpqDaCntlrCondition},
    cpqDaCntlrBoardCondition => $params{cpqDaCntlrBoardCondition},
    blacklisted => 0,
  };
  $self->{name} = $params{name} || $self->{cpqDaCntlrSlot};
  $self->{controllerindex} = $self->{cpqDaCntlrIndex};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
#$self->dumper($self);
  $self->blacklist('daco', $self->{cpqDaCntlrIndex});
  foreach (@{$self->{accelerators}}) {
    $_->check();
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
  if ($self->{cpqDaCntlrCondition} eq 'other') {
    if (scalar(@{$self->{physical_drives}})) {
      $self->add_message(CRITICAL,
          sprintf 'da controller %s in slot %s needs attention', 
              $self->{cpqDaCntlrIndex}, $self->{cpqDaCntlrSlot});
      $self->add_info(sprintf 'da controller %s in slot %s needs attention',
          $self->{cpqDaCntlrIndex}, $self->{cpqDaCntlrSlot});
    } else {
      $self->add_info(sprintf 'da controller %s in slot %s is ok and unused',
          $self->{cpqDaCntlrIndex}, $self->{cpqDaCntlrSlot});
      $self->{blacklisted} = 1;
    }
  } elsif ($self->{cpqDaCntlrCondition} eq 'degraded') {
    # maybe only the battery has failed and is disabled, no problem
    if (scalar(grep {
        $_->has_failed() && $_->is_disabled()
    } @{$self->{accelerators}})) {
      # message was already written in the accel code
    } else {
      $self->add_message(CRITICAL,
          sprintf 'da controller %s in slot %s needs attention', 
              $self->{cpqDaCntlrIndex}, $self->{cpqDaCntlrSlot});
      $self->add_info(sprintf 'da controller %s in slot %s needs attention',
          $self->{cpqDaCntlrIndex}, $self->{cpqDaCntlrSlot});
    }
  } elsif ($self->{cpqDaCntlrCondition} ne 'ok') {
    $self->add_message(CRITICAL,
        sprintf 'da controller %s in slot %s needs attention', 
            $self->{cpqDaCntlrIndex}, $self->{cpqDaCntlrSlot});
    $self->add_info(sprintf 'da controller %s in slot %s needs attention',
        $self->{cpqDaCntlrIndex}, $self->{cpqDaCntlrSlot});
  } else {
    $self->add_info(sprintf 'da controller %s in slot %s is ok', 
        $self->{cpqDaCntlrIndex}, $self->{cpqDaCntlrSlot});
  }
} 

sub dump {
  my $self = shift;
  printf "[DA_CONTROLLER_%s]\n", $self->{name};
  foreach (qw(cpqDaCntlrSlot cpqDaCntlrIndex cpqDaCntlrCondition 
      cpqDaCntlrModel)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
  foreach (@{$self->{accelerators}}) {
    $_->dump();
  }
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


package HP::Proliant::Component::DiskSubsystem::Da::Accelerator;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Da);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    cpqDaAccelCntlrIndex => $params{cpqDaAccelCntlrIndex},
    cpqDaAccelBattery => $params{cpqDaAccelBattery} || 'notPresent',
    cpqDaAccelCondition => $params{cpqDaAccelCondition},
    cpqDaAccelStatus => $params{cpqDaAccelStatus},
    blacklisted => 0,
    failed => 0,
  };
  $self->{controllerindex} = $self->{cpqDaAccelCntlrIndex};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('daac', $self->{cpqDaAccelCntlrIndex});
  $self->add_info(sprintf 'controller accelerator is %s',
      $self->{cpqDaAccelCondition});
  if ($self->{cpqDaAccelStatus} ne "enabled") {
  } elsif ($self->{cpqDaAccelCondition} ne "ok") {
    if ($self->{cpqDaAccelBattery} eq "failed" &&
        $self->{cpqDaAccelStatus} eq "tmpDisabled") {
      # handled later
    } else {
      $self->add_message(CRITICAL, "controller accelerator needs attention");
    }
  }
  $self->blacklist('daacb', $self->{cpqDaAccelCntlrIndex});
  $self->add_info(sprintf 'controller accelerator battery is %s',
      $self->{cpqDaAccelBattery});
  if ($self->{cpqDaAccelBattery} eq "notPresent") {
  } elsif ($self->{cpqDaAccelBattery} eq "recharging") {
    $self->add_message(WARNING, "controller accelerator battery recharging");
  } elsif ($self->{cpqDaAccelBattery} eq "failed" &&
      $self->{cpqDaAccelStatus} eq "tmpDisabled") {
    $self->add_message(WARNING, "controller accelerator battery needs attention");
  } elsif ($self->{cpqDaAccelBattery} ne "ok") {
    # (other) failed degraded
    $self->add_message(CRITICAL, "controller accelerator battery needs attention");
  } 
}

sub has_failed {
  my $self = shift;
  return $self->{cpqDaAccelStatus} =~ /Disabled/ ? 1 : 0;
}

sub is_disabled {
  my $self = shift;
  return $self->{cpqDaAccelStatus} =~ /Disabled/ ? 1 : 0;
}

sub dump {
  my $self = shift;
  printf "[ACCELERATOR]\n";
  foreach (qw(cpqDaAccelCntlrIndex cpqDaAccelBattery
      cpqDaAccelStatus cpqDaAccelCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


package HP::Proliant::Component::DiskSubsystem::Da::LogicalDrive;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Da);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    cpqDaLogDrvIndex => $params{cpqDaLogDrvIndex},
    cpqDaLogDrvCntlrIndex => $params{cpqDaLogDrvCntlrIndex},
    cpqDaLogDrvSize => $params{cpqDaLogDrvSize},
    cpqDaLogDrvFaultTol => $params{cpqDaLogDrvFaultTol},
    cpqDaLogDrvPercentRebuild => $params{cpqDaLogDrvPercentRebuild},
    cpqDaLogDrvStatus => $params{cpqDaLogDrvStatus},
    cpqDaLogDrvCondition => $params{cpqDaLogDrvCondition},
    cpqDaLogDrvPhyDrvIDs => $params{cpqDaLogDrvPhyDrvIDs},
    blacklisted => 0,
  };
  bless $self, $class;
  $self->{name} = $params{name} || 
      $self->{cpqDaLogDrvCntlrIndex}.':'.$self->{cpqDaLogDrvIndex}; ##vorerst
  $self->{controllerindex} = $self->{cpqDaLogDrvCntlrIndex};
  if (! $self->{cpqDaLogDrvPercentRebuild} ||
      $self->{cpqDaLogDrvPercentRebuild} == 4294967295) {
    $self->{cpqDaLogDrvPercentRebuild} = 100;
  }
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('dald', $self->{name});
  $self->add_info(sprintf "logical drive %s is %s (%s)",
          $self->{name}, $self->{cpqDaLogDrvStatus},
          $self->{cpqDaLogDrvFaultTol});
  if ($self->{cpqDaLogDrvCondition} ne "ok") {
    if ($self->{cpqDaLogDrvStatus} =~ 
        /rebuild|recovering|recovery|expanding|queued/) {
      $self->add_message(WARNING,
          sprintf "logical drive %s is %s", 
              $self->{name}, $self->{cpqDaLogDrvStatus});
    } else {
      $self->add_message(CRITICAL,
          sprintf "logical drive %s is %s",
              $self->{name}, $self->{cpqDaLogDrvStatus});
    }
  } 
}

sub dump {
  my $self = shift;
  printf "[LOGICAL_DRIVE]\n";
  foreach (qw(cpqDaLogDrvCntlrIndex cpqDaLogDrvIndex cpqDaLogDrvSize
      cpqDaLogDrvFaultTol cpqDaLogDrvStatus cpqDaLogDrvCondition
      cpqDaLogDrvPercentRebuild cpqDaLogDrvPhyDrvIDs)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


package HP::Proliant::Component::DiskSubsystem::Da::PhysicalDrive;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Da);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    name => $params{name},
    cpqDaPhyDrvCntlrIndex => $params{cpqDaPhyDrvCntlrIndex},
    cpqDaPhyDrvIndex => $params{cpqDaPhyDrvIndex},
    cpqDaPhyDrvBay => $params{cpqDaPhyDrvBay},
    cpqDaPhyDrvBusNumber => $params{cpqDaPhyDrvBusNumber},
    cpqDaPhyDrvSize => $params{cpqDaPhyDrvSize},
    cpqDaPhyDrvStatus => $params{cpqDaPhyDrvStatus},
    cpqDaPhyDrvCondition => $params{cpqDaPhyDrvCondition},
    blacklisted => 0,
  };
  bless $self, $class;
  $self->{name} = $params{name} ||
      $self->{cpqDaPhyDrvCntlrIndex}.':'.$self->{cpqDaPhyDrvIndex}; ##vorerst
  $self->{controllerindex} = $self->{cpqDaPhyDrvCntlrIndex};
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('dapd', $self->{name});
  $self->add_info(
      sprintf "physical drive %s is %s",
          $self->{name}, $self->{cpqDaPhyDrvCondition});
  if ($self->{cpqDaPhyDrvCondition} ne 'ok') {
    $self->add_message(CRITICAL,
        sprintf "physical drive %s is %s", 
            $self->{name}, $self->{cpqDaPhyDrvCondition});
  }
}

sub dump {
  my $self = shift;
  printf "[PHYSICAL_DRIVE]\n";
  foreach (qw(cpqDaPhyDrvCntlrIndex cpqDaPhyDrvIndex cpqDaPhyDrvBay
      cpqDaPhyDrvBusNumber cpqDaPhyDrvSize cpqDaPhyDrvStatus
      cpqDaPhyDrvCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


package HP::Proliant::Component::DiskSubsystem::Da::SpareDrive;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Da);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub dump {
  my $self = shift;
  printf "[SPARE_DRIVE]\n";
  foreach (qw(cpqDaPhyDrvCntlrIndex cpqDaPhyDrvIndex cpqDaPhyDrvBay
      cpqDaPhyDrvBusNumber cpqDaPhyDrvSize cpqDaPhyDrvStatus
      cpqDaPhyDrvCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


1;
