package HP::BladeSystem::Component::PowerSupplySubsystem;
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
    power_supplies => [],
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
      cpqRackPowerSupplyEntry => '1.3.6.1.4.1.232.22.2.5.1.1.1',
      cpqRackPowerSupplyRack => '1.3.6.1.4.1.232.22.2.5.1.1.1.1',
      cpqRackPowerSupplyChassis => '1.3.6.1.4.1.232.22.2.5.1.1.1.2',
      cpqRackPowerSupplyIndex => '1.3.6.1.4.1.232.22.2.5.1.1.1.3',
      cpqRackPowerSupplyEnclosureName => '1.3.6.1.4.1.232.22.2.5.1.1.1.4',
      cpqRackPowerSupplySerialNum => '1.3.6.1.4.1.232.22.2.5.1.1.1.5',
      cpqRackPowerSupplySparePartNumber => '1.3.6.1.4.1.232.22.2.5.1.1.1.7',
      cpqRackPowerSupplyFWRev => '1.3.6.1.4.1.232.22.2.5.1.1.1.8',
      cpqRackPowerSupplyMaxPwrOutput => '1.3.6.1.4.1.232.22.2.5.1.1.1.9',
      cpqRackPowerSupplyCurPwrOutput => '1.3.6.1.4.1.232.22.2.5.1.1.1.10',
      cpqRackPowerSupplyIntakeTemp => '1.3.6.1.4.1.232.22.2.5.1.1.1.12',
      cpqRackPowerSupplyExhaustTemp => '1.3.6.1.4.1.232.22.2.5.1.1.1.13',
      cpqRackPowerSupplyStatus => '1.3.6.1.4.1.232.22.2.5.1.1.1.14',
      cpqRackPowerSupplySupplyInputLineStatus => '1.3.6.1.4.1.232.22.2.5.1.1.1.15',
      cpqRackPowerSupplyPresent => '1.3.6.1.4.1.232.22.2.5.1.1.1.16',
      cpqRackPowerSupplyCondition => '1.3.6.1.4.1.232.22.2.5.1.1.1.17',
      cpqRackPowerSupplySupplyInputLineStatusValue => {
          1 => 'noError',
          2 => 'lineOverVoltage',
          3 => 'lineUnderVoltage',
          4 => 'lineHit',
          5 => 'brownOut',
          6 => 'linePowerLoss',
      },
      cpqRackPowerSupplyStatusValue => {
          1 => 'noError',
          2 => 'generalFailure',
          3 => 'bistFailure',
          4 => 'fanFailure',
          5 => 'tempFailure',
          6 => 'interlockOpen',
          7 => 'epromFailed',
          8 => 'vrefFailed',
          9 => 'dacFailed',
          10 => 'ramTestFailed',
          11 => 'voltageChannelFailed',
          12 => 'orringdiodeFailed',
          13 => 'brownOut',
          14 => 'giveupOnStartup',
          15 => 'nvramInvalid',
          16 => 'calibrationTableInvalid',
      },
      cpqRackPowerSupplyPresentValue => {
          1 => 'other',
          2 => 'absent',
          3 => 'present',
      },
      cpqRackPowerSupplyConditionValue => {
          1 => 'other',
          2 => 'ok',
          3 => 'degraded',
          4 => 'failed',
      },
  };
 
 
  # INDEX { cpqRackPowerSupplyRack, cpqRackPowerSupplyChassis, cpqRackPowerSupplyIndex }
  foreach ($self->get_entries($oids, 'cpqRackPowerSupplyEntry')) {
    push(@{$self->{power_supplies}},
        HP::BladeSystem::Component::PowerSupplySubsystem::PowerSupply->new(%{$_}));
  }
}

sub check {
  my $self = shift;
  my $total_current_watt = 0;
  my $total_max_watt = 0;
  my $total_in_temp = 0;
  my $total_out_temp = 0;
  my $num_ps = 0;
  foreach (@{$self->{power_supplies}}) {
    $_->check() if $_->{cpqRackPowerSupplyPresent} eq 'present' ||
        $self->{runtime}->{options}->{verbose} >= 3; # absent nur bei -vvv
    if ($_->{cpqRackPowerSupplyPresent} eq 'present') {
      $total_max_watt += $_->{cpqRackPowerSupplyMaxPwrOutput};
      $total_current_watt += $_->{cpqRackPowerSupplyCurPwrOutput};
      $total_in_temp += $_->{cpqRackPowerSupplyIntakeTemp} 
          if $_->{cpqRackPowerSupplyIntakeTemp} != -1;
      $total_out_temp += $_->{cpqRackPowerSupplyExhaustTemp}
          if $_->{cpqRackPowerSupplyExhaustTemp} != -1;
      $num_ps++;
    }
  }
  $self->{runtime}->{plugin}->add_perfdata(
      label => 'watt_total',
      value => $total_current_watt,
      warning => $total_max_watt,
      critical => $total_max_watt,
  );
  #$self->{runtime}->{plugin}->add_perfdata(
  #    label => 'watt_total_pct',
  #    value => ($total_current_watt == 0 ? 0 :
  #        sprintf("%.2f",
  #        ($total_current_watt / $total_max_watt * 100))),
  #    warning => 100,
  #    critical => 100,
  #    uom => '%',
  #);
  if ($total_in_temp) {
    $self->{runtime}->{plugin}->add_perfdata(
        label => 'in_temp',
        value => $total_in_temp / $num_ps,
    );
  }
  if ($total_out_temp) {
    $self->{runtime}->{plugin}->add_perfdata(
        label => 'out_temp',
        value => $total_out_temp / $num_ps,
    );
  }
}

sub dump {
  my $self = shift;
  foreach (@{$self->{power_supplies}}) {
    $_->dump() if $_->{cpqRackPowerSupplyPresent} eq 'present' ||
        $self->{runtime}->{options}->{verbose} >= 3; # absent nur bei -vvv
  }
}


package HP::BladeSystem::Component::PowerSupplySubsystem::PowerSupply;
our @ISA = qw(HP::BladeSystem::Component::PowerSupplySubsystem);

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
  map { $self->{$_} = $params{$_} } grep /cpqRackPowerSupply/, keys %params;
  $self->{name} = $params{cpqRackPowerSupplyRack}.
      ':'.$params{cpqRackPowerSupplyChassis}.
      ':'.$params{cpqRackPowerSupplyIndex};
  $self->{serfw} = sprintf "Ser: %s, FW: %s", $self->{cpqRackPowerSupplySerialNum}, $self->{cpqRackPowerSupplyFWRev};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('ps', $self->{name});
  my $info = sprintf 'power supply %s is %s, condition is %s (%s)', 
      $self->{name}, $self->{cpqRackPowerSupplyPresent},
      $self->{cpqRackPowerSupplyCondition}, $self->{serfw};
  $self->add_info($info);
  if ($self->{cpqRackPowerSupplyPresent} eq 'present') {
    if ($self->{cpqRackPowerSupplyCondition} eq 'degraded') {
      $info .= sprintf " (SparePartNum %s)", $self->{cpqRackPowerSupplySparePartNumber};
      $self->add_message(WARNING, $info);
      $self->add_info(sprintf 'power supply %s status is %s, inp.line status is %s',
          $self->{name}, $self->{cpqRackPowerSupplyStatus},
          $self->{cpqRackPowerSupplySupplyInputLineStatus});
    } elsif ($self->{cpqRackPowerSupplyCondition} eq 'failed') {
      $info .= sprintf " (SparePartNum %s)", $self->{cpqRackPowerSupplySparePartNumber};
      $self->add_message(CRITICAL, $info);
      $self->add_info(sprintf 'power supply %s status is %s, inp.line status is %s',
          $self->{name}, $self->{cpqRackPowerSupplyStatus},
          $self->{cpqRackPowerSupplySupplyInputLineStatus});
    } 
    if ($self->{runtime}->{options}->{perfdata} != 2) {
      $self->{runtime}->{plugin}->add_perfdata(
          label => sprintf('watt_%s', $self->{name}),
          value => $self->{cpqRackPowerSupplyCurPwrOutput},
          warning => $self->{cpqRackPowerSupplyMaxPwrOutput},
          critical => $self->{cpqRackPowerSupplyMaxPwrOutput}
      );
      #$self->{runtime}->{plugin}->add_perfdata(
      #    label => sprintf('watt_pct_%s', $self->{name}),
      #    value => ($self->{cpqRackPowerSupplyCurPwrOutput} == 0 ? 0 :
      #        sprintf ("%.2f",
      #        ($self->{cpqRackPowerSupplyCurPwrOutput} /
      #        $self->{cpqRackPowerSupplyMaxPwrOutput} * 100))),
      #    warning => 100,
      #    critical => 100,
      #    uom => '%',
      #);
      if ($self->{cpqRackPowerSupplyIntakeTemp} != -1) {
        $self->{runtime}->{plugin}->add_perfdata(
            label => sprintf('in_temp_%s', $self->{name}),
            value => $self->{cpqRackPowerSupplyIntakeTemp},
        );
      }
      if ($self->{cpqRackPowerSupplyExhaustTemp} != -1) {
        $self->{runtime}->{plugin}->add_perfdata(
            label => sprintf('out_temp_%s', $self->{name}),
            value => $self->{cpqRackPowerSupplyExhaustTemp},
        );
      }
    }
  }
} 
  
sub dump {
  my $self = shift;
    printf "[POWER_SUPPLY%s]\n", $self->{name};
  foreach (qw(cpqRackPowerSupplyRack cpqRackPowerSupplyChassis cpqRackPowerSupplyIndex cpqRackPowerSupplyEnclosureName cpqRackPowerSupplySerialNum cpqRackPowerSupplySparePartNumber cpqRackPowerSupplyFWRev cpqRackPowerSupplyMaxPwrOutput cpqRackPowerSupplyCurPwrOutput cpqRackPowerSupplyIntakeTemp cpqRackPowerSupplyExhaustTemp cpqRackPowerSupplyStatus cpqRackPowerSupplySupplyInputLineStatus cpqRackPowerSupplyPresent cpqRackPowerSupplyCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


1;
