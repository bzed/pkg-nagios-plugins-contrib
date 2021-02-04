package HP::Proliant::Component::BatterySubsystem;
our @ISA = qw(HP::Proliant::Component);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    method => $params{method},
    condition => $params{condition},
    status => $params{status},
    sysbatteries => [],
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  if ($self->{method} eq 'snmp') {
    return HP::Proliant::Component::BatterySubsystem::SNMP->new(%params);
  } elsif ($self->{method} eq 'cli') {
    #return HP::Proliant::Component::BatterySubsystem::CLI->new(%params);
  } else {
    die "unknown method";
  }
  return $self;
}

sub check {
  my $self = shift;
  my $errorfound = 0;
  $self->add_info('checking sysbatteries');
  if (scalar (@{$self->{sysbatteries}}) == 0) {
    #$self->overall_check(); 
    $self->add_info('no sysbatteries found');
  } else {
    foreach (sort { $a->{cpqHeSysBatteryIndex} <=> $b->{cpqHeSysBatteryIndex}}
        @{$self->{sysbatteries}}) {
      $_->check();
    }
  }
}

sub dump {
  my $self = shift;
  foreach (@{$self->{sysbatteries}}) {
    $_->dump();
  }
}


package HP::Proliant::Component::BatterySubsystem::Battery;
our @ISA = qw(HP::Proliant::Component::BatterySubsystem);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    cpqHeSysBatteryChassis => $params{cpqHeSysBatteryChassis},
    cpqHeSysBatteryIndex => $params{cpqHeSysBatteryIndex},
    cpqHeSysBatteryPresent => $params{cpqHeSysBatteryPresent},
    cpqHeSysBatteryCondition => $params{cpqHeSysBatteryCondition},
    cpqHeSysBatteryStatus => $params{cpqHeSysBatteryStatus},
    cpqHeSysBatteryCapacityMaximum => $params{cpqHeSysBatteryCapacityMaximum},
    cpqHeSysBatteryProductName => $params{cpqHeSysBatteryProductName},
    cpqHeSysBatteryModel => $params{cpqHeSysBatteryModel},
    cpqHeSysBatterySerialNumber => $params{cpqHeSysBatterySerialNumber},
    cpqHeSysBatteryFirmwareRev => $params{cpqHeSysBatteryFirmwareRev},
    cpqHeSysBatterySparePartNum => $params{cpqHeSysBatterySparePartNum},
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  $self->{name} = $params{name} ||
      $self->{cpqHeSysBatteryChassis}.':'.$self->{cpqHeSysBatteryIndex};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('sba', $self->{name});
  my $info = sprintf "battery %s/%s has condition %s and status %s",
      $self->{cpqHeSysBatteryChassis},
      $self->{cpqHeSysBatteryIndex},
      $self->{cpqHeSysBatteryCondition},
      $self->{cpqHeSysBatteryStatus};
  if ($self->{cpqHeSysBatteryCondition} eq "ok") {
  } elsif ($self->{cpqHeSysBatteryCondition} eq "degraded") {
    $self->add_info($info);
    $self->add_message(WARNING, $self->{info});
  } elsif ($self->{cpqHeSysBatteryCondition} eq "failed") {
    $self->add_info($info);
    $self->add_message(CRITICAL, $self->{info});
  } else {
    $self->add_info($info);
    $self->add_message(UNKNOWN, $self->{info});
  }
}

sub dump { 
  my $self = shift;
  printf "[SYSBATTERY_%s_%s]\n", $self->{cpqHeSysBatteryChassis},
      $self->{cpqHeSysBatteryIndex};
  foreach (qw(cpqHeSysBatteryChassis cpqHeSysBatteryIndex
      cpqHeSysBatteryPresent cpqHeSysBatteryCondition cpqHeSysBatteryStatus
      cpqHeSysBatteryCapacityMaximum cpqHeSysBatteryProductName
      cpqHeSysBatteryModel cpqHeSysBatterySerialNumber
      cpqHeSysBatteryFirmwareRev cpqHeSysBatterySparePartNum)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n\n", $self->{info};
}


1;

