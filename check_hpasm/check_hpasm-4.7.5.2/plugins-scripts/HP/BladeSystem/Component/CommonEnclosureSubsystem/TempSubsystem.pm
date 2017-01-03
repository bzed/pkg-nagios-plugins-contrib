package HP::BladeSystem::Component::CommonEnclosureSubsystem::TempSubsystem;
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
    condition => $params{condition},
    status => $params{status},
    temperatures => [],
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  if ($params{runtime}->{options}->{customthresholds}) {
    if (-f $params{runtime}->{options}->{customthresholds}) {
      open CT, $params{runtime}->{options}->{customthresholds};
      $params{runtime}->{options}->{customthresholds} = <CT>;
      close CT;
    }
    foreach my $ct_items
        (split(/\//, $params{runtime}->{options}->{customthresholds})) {
      if ($ct_items =~ /^(\d+):(\d+)$/) {
        my $temp = $2;
        $params{runtime}->{options}->{thresholds}->{$1} = $temp;
      } else {
        die sprintf "invalid threshold %s", $ct_items;
      }
    }
  }
  $self->init();
  return $self;
}

sub init {
  my $self = shift;
  my %params = @_;
  my $snmpwalk = $self->{rawdata};
  my $oids = {
      cpqRackCommonEnclosureTempEntry => '1.3.6.1.4.1.232.22.2.3.1.2.1',
      cpqRackCommonEnclosureTempRack => '1.3.6.1.4.1.232.22.2.3.1.2.1.1',
      cpqRackCommonEnclosureTempChassis => '1.3.6.1.4.1.232.22.2.3.1.2.1.2',
      cpqRackCommonEnclosureTempSensorIndex => '1.3.6.1.4.1.232.22.2.3.1.2.1.3',
      cpqRackCommonEnclosureTempSensorEnclosureName => '1.3.6.1.4.1.232.22.2.3.1.2.1.4',
      cpqRackCommonEnclosureTempLocation => '1.3.6.1.4.1.232.22.2.3.1.2.1.5',
      cpqRackCommonEnclosureTempCurrent => '1.3.6.1.4.1.232.22.2.3.1.2.1.6',
      cpqRackCommonEnclosureTempThreshold => '1.3.6.1.4.1.232.22.2.3.1.2.1.7',
      cpqRackCommonEnclosureTempCondition => '1.3.6.1.4.1.232.22.2.3.1.2.1.8',
      cpqRackCommonEnclosureTempType => '1.3.6.1.4.1.232.22.2.3.1.2.1.9',
      cpqRackCommonEnclosureTempConditionValue => {
          1 => 'other',
          2 => 'ok',
          3 => 'degraded',
          4 => 'failed',
      },
      cpqRackCommonEnclosureTempTypeValue => {
          1 => 'other',
          5 => 'blowout',
          9 => 'caution',
          15 => 'critical',
      },
  };
  # INDEX { cpqRackCommonEnclosureTempRack cpqRackCommonEnclosureTempChassis
  #         cpqRackCommonEnclosureTempSensorIndex }
  foreach ($self->get_entries($oids, 'cpqRackCommonEnclosureTempEntry')) {
    push(@{$self->{temperatures}},
       HP::BladeSystem::Component::CommonEnclosureSubsystem::TempSubsystem::Temp->new(%{$_}))  if (($_->{cpqRackCommonEnclosureTempCurrent} != -1 && $_->{cpqRackCommonEnclosureTempThreshold} != -1) && ($_->{cpqRackCommonEnclosureTempThreshold} != 0));
  }

}


sub check {
  my $self = shift;
  my $errorfound = 0;
  if (scalar (@{$self->{temperatures}}) == 0) {
    #$self->overall_check();
  } else {
    foreach (@{$self->{temperatures}}) {
      $_->check();
    }
  }
}

sub dump {
  my $self = shift;
  foreach (@{$self->{temperatures}}) {
    $_->dump();
  }
}


package HP::BladeSystem::Component::CommonEnclosureSubsystem::TempSubsystem::Temp;
our @ISA = qw(HP::BladeSystem::Component::CommonEnclosureSubsystem::TempSubsystem);

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
  map { $self->{$_} = $params{$_} } grep /cpqRackCommonEnclosureTemp/, keys %params;
  $self->{name} = $params{cpqRackCommonEnclosureTempRack}.':'.
      $params{cpqRackCommonEnclosureTempChassis}.':'.
      $params{cpqRackCommonEnclosureTempSensorIndex};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('t', $self->{name});
  if ($self->{cpqRackCommonEnclosureTempCurrent} > $self->{cpqRackCommonEnclosureTempThreshold}) {
    $self->add_info(sprintf "%s temperature too high (%d%s)",
        $self->{cpqRackCommonEnclosureTempLocation},
        $self->{cpqRackCommonEnclosureTempCurrent},
        $self->{runtime}->{options}->{celsius} ? "C" : "F");
    $self->add_message(CRITICAL, $self->{info});
  } else {
    $self->add_info(sprintf "%s temperature is %d%s (%d max)",
        $self->{cpqRackCommonEnclosureTempLocation},
        $self->{cpqRackCommonEnclosureTempCurrent},
        $self->{runtime}->{options}->{celsius} ? "C" : "F",
        $self->{cpqRackCommonEnclosureTempThreshold});
  }
  if ($self->{runtime}->{options}->{perfdata} == 2) {
    $self->{runtime}->{plugin}->add_perfdata(
        label => sprintf('temp_%s', $self->{name}),
        value => $self->{cpqRackCommonEnclosureTempCurrent},
        warning => $self->{cpqRackCommonEnclosureTempThreshold},
        critical => $self->{cpqRackCommonEnclosureTempThreshold}
    );
  } elsif ($self->{runtime}->{options}->{perfdata} == 1) {
    $self->{runtime}->{plugin}->add_perfdata(
        label => sprintf('temp_%s_%s', $self->{name},
            $self->{cpqRackCommonEnclosureTempLocation}),
        value => $self->{cpqRackCommonEnclosureTempCurrent},
        warning => $self->{cpqRackCommonEnclosureTempThreshold},
        critical => $self->{cpqRackCommonEnclosureTempThreshold}
    );
  }
  $self->add_extendedinfo(sprintf "temp_%s=%d", 
      $self->{name}, $self->{cpqRackCommonEnclosureTempCurrent});

}


sub dump {
  my $self = shift;
  printf "[TEMP_%s]\n", $self->{name};
  foreach (qw(cpqRackCommonEnclosureTempRack cpqRackCommonEnclosureTempChassis
      cpqRackCommonEnclosureTempSensorIndex cpqRackCommonEnclosureTempSensorEnclosureName
      cpqRackCommonEnclosureTempLocation
      cpqRackCommonEnclosureTempCurrent cpqRackCommonEnclosureTempThreshold 
      cpqRackCommonEnclosureTempCondition cpqRackCommonEnclosureTempType)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n\n", $self->{info};
}

1;

