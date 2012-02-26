package HP::Proliant::Component::PowersupplySubsystem;
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
    powersupplies => [],
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  if ($self->{method} eq 'snmp') {
    return HP::Proliant::Component::PowersupplySubsystem::SNMP->new(%params);
  } elsif ($self->{method} eq 'cli') {
    return HP::Proliant::Component::PowersupplySubsystem::CLI->new(%params);
  } else {
    die "unknown method";
  }
  return $self;
}

sub check {
  my $self = shift;
  my $errorfound = 0;
  $self->add_info('checking power supplies');
  if (scalar (@{$self->{powersupplies}}) == 0) {
    #$self->overall_check();
  } else {
    foreach (@{$self->{powersupplies}}) {
      $_->check();
    }
  }
}

sub dump {
  my $self = shift;
  foreach (@{$self->{powersupplies}}) {
    $_->dump();
  }
}


package HP::Proliant::Component::PowersupplySubsystem::Powersupply;
our @ISA = qw(HP::Proliant::Component::PowersupplySubsystem);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    cpqHeFltTolPowerSupplyChassis => $params{cpqHeFltTolPowerSupplyChassis},
    cpqHeFltTolPowerSupplyBay => $params{cpqHeFltTolPowerSupplyBay},
    cpqHeFltTolPowerSupplyPresent => $params{cpqHeFltTolPowerSupplyPresent},
    cpqHeFltTolPowerSupplyCondition => $params{cpqHeFltTolPowerSupplyCondition},
    cpqHeFltTolPowerSupplyRedundant => $params{cpqHeFltTolPowerSupplyRedundant},
    blacklisted => 0,
    info => undef,
    extendexinfo => undef,
  };
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('p', $self->{cpqHeFltTolPowerSupplyBay});
  if ($self->{cpqHeFltTolPowerSupplyPresent} eq "present") {
    if ($self->{cpqHeFltTolPowerSupplyCondition} ne "ok") {
      if ($self->{cpqHeFltTolPowerSupplyCondition} eq "other") {
        $self->add_info(sprintf "powersupply %d is missing",
            $self->{cpqHeFltTolPowerSupplyBay});
      } else {
        $self->add_info(sprintf "powersupply %d needs attention (%s)",
            $self->{cpqHeFltTolPowerSupplyBay},
            $self->{cpqHeFltTolPowerSupplyCondition});
      }
      $self->add_message(CRITICAL, $self->{info});
    } else {
      $self->add_info(sprintf "powersupply %d is %s",
          $self->{cpqHeFltTolPowerSupplyBay},
          $self->{cpqHeFltTolPowerSupplyCondition});
    }
    $self->add_extendedinfo(sprintf "ps_%s=%s",
        $self->{cpqHeFltTolPowerSupplyBay},
        $self->{cpqHeFltTolPowerSupplyCondition});
  } else {
    $self->add_info(sprintf "powersupply %d is %s",
        $self->{cpqHeFltTolPowerSupplyBay},
        $self->{cpqHeFltTolPowerSupplyPresent});
    $self->add_extendedinfo(sprintf "ps_%s=%s",
        $self->{cpqHeFltTolPowerSupplyBay},
        $self->{cpqHeFltTolPowerSupplyPresent});
  }
}


sub dump {
  my $self = shift;
  if (exists $self->{cpqHeFltTolPowerSupplyBay}) {
    printf "[PS_%s]\n", $self->{cpqHeFltTolPowerSupplyBay};
    foreach (qw(cpqHeFltTolPowerSupplyBay cpqHeFltTolPowerSupplyChassis
        cpqHeFltTolPowerSupplyPresent cpqHeFltTolPowerSupplyCondition
        cpqHeFltTolPowerSupplyRedundant)) {
      printf "%s: %s\n", $_, $self->{$_};
    }
  } elsif (exists $self->{cpqHePowerConvChassis}) {
    printf "[PS_%s]\n", ($self->{cpqHePowerConvChassis} ? $self->{cpqHePowerConvChassis}.":" : "").$self->{cpqHePowerConvIndex};
    foreach (qw(cpqHePowerConvIndex cpqHePowerConvPresent cpqHePowerConvRedundant cpqHePowerConvCondition)) {
      printf "%s: %s\n", $_, $self->{$_};
    }
  }
  printf "info: %s\n\n", $self->{info};
}


1;
