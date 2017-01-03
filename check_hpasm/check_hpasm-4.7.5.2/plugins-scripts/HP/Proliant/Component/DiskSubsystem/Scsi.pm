package HP::Proliant::Component::DiskSubsystem::Scsi;
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
    bless $self, 'HP::Proliant::Component::DiskSubsystem::Scsi::SNMP';
  } else {
    bless $self, 'HP::Proliant::Component::DiskSubsystem::Scsi::CLI';
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

package HP::Proliant::Component::DiskSubsystem::Scsi::Controller;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Scsi);

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
  map { $self->{$_} = $params{$_} } grep /cpqScsiCntlr/, keys %params;
  $self->{name} = $params{name} || $params{cpqScsiCntlrIndex}.':'.$params{cpqScsiCntlrBusIndex};
  $self->{controllerindex} = $self->{cpqScsiCntlrIndex};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('scco', $self->{name});
  my $info = sprintf 'scsi controller %s in slot %s is %s',
      $self->{name}, $self->{cpqScsiCntlrSlot}, $self->{cpqScsiCntlrCondition};
  if ($self->{cpqScsiCntlrCondition} eq 'other') {
    if (scalar(@{$self->{physical_drives}})) {
      $info .= ' and needs attention';
      $self->add_message(CRITICAL, $info);
      $self->add_info($info);
    } else {
      $info .= ' and unused';
      $self->add_info($info);
      $self->{blacklisted} = 1;
    }
  } elsif ($self->{cpqScsiCntlrCondition} ne 'ok') {
    $info .= ' and needs attention';
    $self->add_message(CRITICAL, $info);
    $self->add_info($info);
  } else {
    $self->add_info($info);
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
  printf "[SCSI_CONTROLLER_%s]\n", $self->{name};
  foreach (qw(cpqScsiCntlrIndex cpqScsiCntlrBusIndex cpqScsiCntlrSlot
      cpqScsiCntlrStatus cpqScsiCntlrCondition cpqScsiCntlrHwLocation)) {
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


package HP::Proliant::Component::DiskSubsystem::Scsi::LogicalDrive;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Scsi);

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
  map { $self->{$_} = $params{$_} } grep /cpqScsiLogDrv/, keys %params;
  $self->{name} = $params{name} || $params{cpqScsiLogDrvCntlrIndex}.':'.$params{cpqScsiLogDrvBusIndex}.':'.$params{cpqScsiLogDrvIndex};
  bless $self, $class;
  $self->{controllerindex} = $self->{cpqScsiLogDrvCntlrIndex};
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('scld', $self->{name});
  my $info = sprintf 'logical drive %s is %s', $self->{name}, $self->{cpqScsiLogDrvStatus};
  if ($self->{cpqScsiLogDrvCondition} ne "ok") {
    if ($self->{cpqScsiLogDrvStatus} =~ 
        /rebuild|recovering/) {
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
  foreach (qw(cpqScsiLogDrvCntlrIndex cpqScsiLogDrvBusIndex cpqScsiLogDrvIndex
      cpqScsiLogDrvFaultTol cpqScsiLogDrvStatus cpqScsiLogDrvSize 
      cpqScsiLogDrvPhyDrvIDs cpqScsiLogDrvCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


package HP::Proliant::Component::DiskSubsystem::Scsi::PhysicalDrive;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Scsi);

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
  map { $self->{$_} = $params{$_} } grep /cpqScsiPhyDrv/, keys %params;
  $self->{name} = $params{name} || 
      $self->{cpqScsiPhyDrvCntlrIndex}.':'.$self->{cpqScsiPhyDrvBusIndex}.':'.$self->{cpqScsiPhyDrvIndex}; 
  $self->{controllerindex} = $self->{cpqScsiPhyDrvCntlrIndex};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('scpd', $self->{name});
  my $info = sprintf 'physical drive %s is %s', $self->{name}, $self->{cpqScsiPhyDrvCondition};
  if ($self->{cpqScsiPhyDrvCondition} ne 'ok') {
    $self->add_message(CRITICAL, $info);
  }
  $self->add_info($info);
}

sub dump {
  my $self = shift;
  printf "[PHYSICAL_DRIVE_%s]\n", $self->{name};
  foreach (qw(cpqScsiPhyDrvCntlrIndex cpqScsiPhyDrvBusIndex cpqScsiPhyDrvIndex
      cpqScsiPhyDrvStatus cpqScsiPhyDrvSize cpqScsiPhyDrvCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


package HP::Proliant::Component::DiskSubsystem::Scsi::SpareDrive;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Scsi);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub dump {
  my $self = shift;
  printf "[SPARE_DRIVE]\n";
}


1;
