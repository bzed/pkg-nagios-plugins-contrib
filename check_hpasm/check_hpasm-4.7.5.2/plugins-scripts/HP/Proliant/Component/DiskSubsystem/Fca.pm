package HP::Proliant::Component::DiskSubsystem::Fca;
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
    host_controllers => [],
    controllers => [],
    accelerators => [],
    enclosures => [],
    physical_drives => [],
    logical_drives => [],
    spare_drives => [],
    global_status => undef,
    blacklisted => 0,
  };
  bless $self, $class;
  if ($self->{method} eq 'snmp') {
    bless $self, 'HP::Proliant::Component::DiskSubsystem::Fca::SNMP';
  } else {
    bless $self, 'HP::Proliant::Component::DiskSubsystem::Fca::CLI';
  }
  $self->init();
  $self->assemble();
  return $self;
}

sub assemble {
  my $self = shift;
  $self->trace(3, sprintf "%s controllers und platten zusammenfuehren",
      ref($self));
  $self->trace(3, sprintf "has %d host controllers", 
      scalar(@{$self->{host_controllers}}));
  $self->trace(3, sprintf "has %d controllers",
      scalar(@{$self->{controllers}}));
  $self->trace(3, sprintf "has %d physical_drives",
      scalar(@{$self->{physical_drives}}));
  $self->trace(3, sprintf "has %d logical_drives",
      scalar(@{$self->{logical_drives}}));
  $self->trace(3, sprintf "has %d spare_drives",
      scalar(@{$self->{spare_drives}}));
}

sub check {
  my $self = shift;
  foreach (@{$self->{host_controllers}}) {
    $_->check();
  }
  foreach (@{$self->{controllers}}) {
    $_->check();
  }
  foreach (@{$self->{accelerators}}) {
    $_->check();
  }
  foreach (@{$self->{logical_drives}}) {
    $_->check();
  }
  foreach (@{$self->{physical_drives}}) {
    $_->check();
  }
  # wozu eigentlich?
  #if (! $self->has_controllers()) {
    #$self->{global_status}->check();
  #}
}

sub dump {
  my $self = shift;
  foreach (@{$self->{host_controllers}}) {
    $_->dump();
  }
  foreach (@{$self->{controllers}}) {
    $_->dump();
  }
  foreach (@{$self->{accelerators}}) {
    $_->dump();
  }
  foreach (@{$self->{logical_drives}}) {
    $_->dump();
  }
  foreach (@{$self->{physical_drives}}) {
    $_->dump();
  }
  #$self->{global_status}->dump();
}


package HP::Proliant::Component::DiskSubsystem::Fca::GlobalStatus;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Fca);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    cpqFcaMibCondition => $params{cpqFcaMibCondition},
  };
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  if ($self->{cpqFcaMibCondition} eq 'other') {
    $self->add_message(OK,
        sprintf 'fcal overall condition is other, update your drivers, please');
  } elsif ($self->{cpqFcaMibCondition} ne 'ok') {
    $self->add_message(CRITICAL, 
        sprintf 'fcal overall condition is %s', $self->{cpqFcaMibCondition});
  }
  $self->{info} = 
      sprintf 'fcal overall condition is %s', $self->{cpqFcaMibCondition};
}

sub dump {
  my $self = shift;
  printf "[FCAL]\n";
  foreach (qw(cpqFcaMibCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


package HP::Proliant::Component::DiskSubsystem::Fca::HostController;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Fca);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    blacklisted => 0,
    info => undef,
    extendedinfo => undef, 
  }; 
  map { $self->{$_} = $params{$_} } grep /cpqFcaHostCntlr/, keys %params;
  $self->{name} = $params{name} || $self->{cpqFcaHostCntlrIndex};
  $self->{controllerindex} = $self->{cpqFcaHostCntlrIndex};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('fcahc', $self->{name});
  my $info = sprintf 'fcal host controller %s in slot %s is %s',
      $self->{name}, $self->{cpqFcaHostCntlrSlot}, $self->{cpqFcaHostCntlrCondition};
  if ($self->{cpqFcaHostCntlrCondition} eq 'other') {
    #$info .= sprintf ' and needs attention (%s)', $self->{cpqFcaHostCntlrStatus};
    # let's assume other=ok
    $self->add_message(OK, $info);
    $self->add_info($info);
  } elsif ($self->{cpqFcaHostCntlrCondition} ne 'ok') {
    $self->add_message(CRITICAL, $info);
    $self->add_info($info);
  } else { 
    $self->add_info($info);
  }
  $self->blacklist('fcahco', $self->{name});
  $info = sprintf 'fcal host controller %s overall condition is %s',
      $self->{name}, $self->{cpqFcaHostCntlrOverallCondition};
  if ($self->{cpqFcaHostCntlrOverallCondition} eq 'other') {
    $self->add_message(OK, $info);
  } elsif ($self->{cpqFcaHostCntlrOverallCondition} ne 'ok') {
    $self->add_message(WARNING, $info);
  }
  $self->add_info($info);
}   

sub dump { 
  my $self = shift;
  printf "[FCAL_HOST_CONTROLLER_%s]\n", $self->{name};
  foreach (qw(cpqFcaHostCntlrIndex cpqFcaHostCntlrSlot
      cpqFcaHostCntlrModel cpqFcaHostCntlrStatus cpqFcaHostCntlrCondition
      cpqFcaHostCntlrOverallCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


package HP::Proliant::Component::DiskSubsystem::Fca::Controller;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Fca);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    blacklisted => 0,
    info => undef,
    extendedinfo => undef, 
  }; 
  map { $self->{$_} = $params{$_} } grep /cpqFcaCntlr/, keys %params;
  $self->{name} = $params{name} || 
      $self->{cpqFcaCntlrBoxIndex}.':'.$self->{cpqFcaCntlrBoxIoSlot};
  $self->{controllerindex} = $self->{cpqFcaCntlrBoxIndex};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('fcaco', $self->{name});
  my $info = sprintf 'fcal controller %s in box %s/slot %s is %s',
      $self->{name}, $self->{cpqFcaCntlrBoxIndex}, $self->{cpqFcaCntlrBoxIoSlot},
      $self->{cpqFcaCntlrCondition};
  if ($self->{cpqFcaCntlrCondition} eq 'other') {
    if (1) { # was ist mit phys. drives?
      $info .= ' needs attention';
      $info .= sprintf(' (%s)', $self->{cpqFcaCntlrStatus}) unless $self->{cpqFcaCntlrStatus} eq 'ok';
      $self->add_message(CRITICAL, $info);
      $self->add_info($info);
    } else {
      $self->add_info($info);
      $self->{blacklisted} = 1;
    }
  } elsif ($self->{cpqFcaCntlrCondition} ne 'ok') {
    $info .= ' needs attention';
    $info .= sprintf(' (%s)', $self->{cpqFcaCntlrStatus}) unless $self->{cpqFcaCntlrStatus} eq 'ok';
    $self->add_message(CRITICAL, $info);
    $self->add_info($info);
  } else {
    $self->add_info($info);
  }
} 

sub dump {
  my $self = shift;
  printf "[FCAL_CONTROLLER_%s]\n", $self->{name};
  foreach (qw(cpqFcaCntlrBoxIndex cpqFcaCntlrBoxIoSlot cpqFcaCntlrModel
      cpqFcaCntlrStatus cpqFcaCntlrCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


package HP::Proliant::Component::DiskSubsystem::Fca::Accelerator;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Fca);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    blacklisted => 0,
    info => undef,
    extendedinfo => undef, 
  }; 
  map { $self->{$_} = $params{$_} } grep /cpqFcaAccel/, keys %params;
  $self->{name} = $params{name} ||
      $self->{cpqFcaAccelBoxIndex}.':'.$self->{cpqFcaAccelBoxIoSlot};
  $self->{controllerindex} = $self->{cpqFcaAccelBoxIndex};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  # !!! cpqFcaAccelStatus
  $self->blacklist('fcaac', $self->{name});
  my $info = sprintf 'fcal accelerator %s in box %s/slot %s is ',
      $self->{name}, $self->{cpqFcaAccelBoxIndex}, $self->{cpqFcaAccelBoxIoSlot};
  if ($self->{cpqFcaAccelStatus} eq 'invalid') {
    $info .= 'not installed';
    $self->add_info($info);
  } elsif ($self->{cpqFcaAccelStatus} eq 'tmpDisabled') {
    $info .= 'temp disabled';
    $self->add_info($info);
  } elsif ($self->{cpqFcaAccelCondition} eq 'other') {
    $info .= sprintf '%s and needs attention (%s)',
        $self->{cpqFcaAccelCondition}, $self->{cpqFcaAccelErrCode};
    $self->add_message(CRITICAL, $info);
    $self->add_info($info);
  } elsif ($self->{cpqFcaAccelCondition} ne 'ok') {
    $info .= sprintf '%s and needs attention (%s)',
        $self->{cpqFcaAccelCondition}, $self->{cpqFcaAccelErrCode};
    $self->add_message(CRITICAL, $info);
    $self->add_info($info);
  } else {
    $info .= sprintf '%s', $self->{cpqFcaAccelCondition};
    $self->add_info($info);
  }
}

sub dump {
  my $self = shift;
  printf "[FCAL_ACCELERATOR_%s]\n", $self->{name};
  foreach (qw(cpqFcaAccelBoxIndex cpqFcaAccelBoxIoSlot cpqFcaAccelStatus
      cpqFcaAccelErrCode cpqFcaAccelBatteryStatus cpqFcaAccelCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


package HP::Proliant::Component::DiskSubsystem::Fca::LogicalDrive;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Fca);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    blacklisted => 0,
    info => undef,
    extendedinfo => undef, 
  }; 
  map { $self->{$_} = $params{$_} } grep /cpqFcaLogDrv/, keys %params;
  bless $self, $class;
  $self->{name} = $params{name} || 
      $self->{cpqFcaLogDrvBoxIndex}.':'.
      $self->{cpqFcaLogDrvIndex};
  $self->{controllerindex} = $self->{cpqFcaLogDrvBoxIndex};
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('fcald', $self->{name});
  my $info = sprintf 'logical drive %s (%s) is %s',
      $self->{name}, $self->{cpqFcaLogDrvFaultTol}, $self->{cpqFcaLogDrvCondition};
  if ($self->{cpqFcaLogDrvCondition} ne "ok") {
    $info .= sprintf ' (%s)', $self->{cpqFcaLogDrvStatus};
    if ($self->{cpqFcaLogDrvStatus} =~ 
        /rebuild|recovering|expand/) {
      $info .= sprintf ' (%s)', $self->{cpqFcaLogDrvStatus};
      $self->add_message(WARNING, $info);
    } else {
      $self->add_message(CRITICAL, $info);
    }
  } 
  $self->add_info($info);
}

sub dump {
  my $self = shift;
  printf "[LOGICAL_DRIVE_%s]\n", $self->{name};
  foreach (qw(cpqFcaLogDrvBoxIndex cpqFcaLogDrvIndex cpqFcaLogDrvFaultTol
      cpqFcaLogDrvStatus cpqFcaLogDrvPercentRebuild cpqFcaLogDrvSize 
      cpqFcaLogDrvPhyDrvIDs cpqFcaLogDrvCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


package HP::Proliant::Component::DiskSubsystem::Fca::PhysicalDrive;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Fca);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    blacklisted => 0,
    info => undef,
    extendedinfo => undef, 
  }; 
  map { $self->{$_} = $params{$_} } grep /cpqFcaPhyDrv/, keys %params;
  $self->{name} = $params{name} || 
      $self->{cpqFcaPhyDrvBoxIndex}.':'.$self->{cpqFcaPhyDrvIndex}; ####vorerst
  $self->{controllerindex} = $self->{cpqScsiPhyDrvCntlrIndex};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('fcapd', $self->{name});
  my $info = sprintf "physical drive %s is %s", 
      $self->{name}, $self->{cpqFcaPhyDrvStatus};
  if ($self->{cpqFcaPhyDrvStatus} eq 'unconfigured') {
    # not part of a logical drive
    # condition will surely be other
  } elsif ($self->{cpqFcaPhyDrvCondition} ne 'ok') {
    $self->add_message(CRITICAL, $info);
  }
  $self->add_info($info);
}

sub dump {
  my $self = shift;
  printf "[PHYSICAL_DRIVE_%s]\n", $self->{name};
  foreach (qw(cpqFcaPhyDrvBoxIndex cpqFcaPhyDrvIndex cpqFcaPhyDrvModel
      cpqFcaPhyDrvBay cpqFcaPhyDrvStatus cpqFcaPhyDrvCondition
      cpqFcaPhyDrvSize cpqFcaPhyDrvBusNumber)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


package HP::Proliant::Component::DiskSubsystem::Fca::SpareDrive;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Fca);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub dump {
  my $self = shift;
  printf "[SPARE_DRIVE]\n";
}


1;
