package HP::Proliant::Component::TemperatureSubsystem;
our @ISA = qw(HP::Proliant::Component);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
################################## custom_thresholds
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
      $params{runtime}->{options}->{customthresholds} = 
          do { local (@ARGV, $/) = 
              $params{runtime}->{options}->{customthresholds}; <> };
    }
    foreach my $ct_items
        (split(/\//, $params{runtime}->{options}->{customthresholds})) {
      if ($ct_items =~ /^(\d+):(\d+)$/) {
        $params{runtime}->{options}->{thresholds}->{$1} = $2;
      } else {
        die sprintf "invalid threshold %s", $ct_items;
      }
    }
  }
  if ($self->{method} eq 'snmp') {
    return HP::Proliant::Component::TemperatureSubsystem::SNMP->new(%params);
  } elsif ($self->{method} eq 'cli') {
    return HP::Proliant::Component::TemperatureSubsystem::CLI->new(%params);
  } else {
    die "unknown method";
  }
  return $self;
}

sub check {
  my $self = shift;
  my $errorfound = 0;
  $self->add_info('checking temperatures');
  if (scalar (@{$self->{temperatures}}) == 0) {
    #$self->overall_check(); 
    $self->add_info('no temperatures found');
  } else {
    foreach (sort { $a->{cpqHeTemperatureIndex} <=> $b->{cpqHeTemperatureIndex}}
        @{$self->{temperatures}}) {
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


package HP::Proliant::Component::TemperatureSubsystem::Temperature;
our @ISA = qw(HP::Proliant::Component::TemperatureSubsystem);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    cpqHeTemperatureChassis => $params{cpqHeTemperatureChassis},
    cpqHeTemperatureIndex => $params{cpqHeTemperatureIndex},
    cpqHeTemperatureLocale => $params{cpqHeTemperatureLocale},
    cpqHeTemperatureCelsius => $params{cpqHeTemperatureCelsius},
    cpqHeTemperatureThresholdCelsius => $params{cpqHeTemperatureThresholdCelsius},
    cpqHeTemperatureCondition => $params{cpqHeTemperatureCondition},
    cpqHeTemperatureThresholdType => $params{cpqHeTemperatureThresholdType} || "unknown",
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  if ($params{runtime}->{options}->{celsius}) {
    $self->{cpqHeTemperatureUnits} = 'C';
    $self->{cpqHeTemperature} = $self->{cpqHeTemperatureCelsius};
    $self->{cpqHeTemperatureThreshold} = 
        $self->{cpqHeTemperatureThresholdCelsius};
  } else {
    $self->{cpqHeTemperatureUnits} = 'F';
    $self->{cpqHeTemperature} = 
        (($self->{cpqHeTemperatureCelsius} * 9) / 5) + 32;
    $self->{cpqHeTemperatureThreshold} = 
        (($self->{cpqHeTemperatureThresholdCelsius} * 9) / 5) + 32;
  }
  my $index = $self->{cpqHeTemperatureIndex};
  if (exists $params{runtime}->{options}->{thresholds}->{$index}) {
    $self->{cpqHeTemperatureThreshold} = 
        $params{runtime}->{options}->{thresholds}->{$index};
        
  }
  if ($self->{cpqHeTemperatureThresholdCelsius} == -99) {
    bless $self, 'HP::Proliant::Component::TemperatureSubsystem::SoSTemperature';
  } elsif ($self->{cpqHeTemperatureThresholdCelsius} == 0) {
    # taucht auf, seit man gen8 ueber das ilo abfragen kann
    bless $self, 'HP::Proliant::Component::TemperatureSubsystem::SoSTemperature';
  }
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('t', $self->{cpqHeTemperatureIndex});
  if ($self->{cpqHeTemperature} > $self->{cpqHeTemperatureThreshold}) {
    $self->add_info(sprintf "%d %s temperature too high (%d%s, %d max)",
        $self->{cpqHeTemperatureIndex}, $self->{cpqHeTemperatureLocale},
        $self->{cpqHeTemperature}, $self->{cpqHeTemperatureUnits},
        $self->{cpqHeTemperatureThreshold});
    $self->add_message(CRITICAL, $self->{info});
  } elsif ($self->{cpqHeTemperature} < 0) {
    # #21 SCSI_BACKPLANE_ZONE -1C/31F 60C/140F OK - can't be true
    $self->add_info(sprintf "%d %s temperature too low (%d%s)",
        $self->{cpqHeTemperatureIndex}, $self->{cpqHeTemperatureLocale},
        $self->{cpqHeTemperature}, $self->{cpqHeTemperatureUnits});
    $self->add_message(CRITICAL, $self->{info});
  } else {
    $self->add_info(sprintf "%d %s temperature is %d%s (%d max)",
        $self->{cpqHeTemperatureIndex}, $self->{cpqHeTemperatureLocale}, 
        $self->{cpqHeTemperature}, $self->{cpqHeTemperatureUnits},
        $self->{cpqHeTemperatureThreshold});
  }
  if ($self->{runtime}->{options}->{perfdata} == 2) {
    $self->{runtime}->{plugin}->add_perfdata(
        label => sprintf('temp_%s', $self->{cpqHeTemperatureIndex}),
        value => $self->{cpqHeTemperature},
        warning => $self->{cpqHeTemperatureThreshold},
        critical => $self->{cpqHeTemperatureThreshold}
    );
  } elsif ($self->{runtime}->{options}->{perfdata} == 1) {
    $self->{runtime}->{plugin}->add_perfdata(
        label => sprintf('temp_%s_%s', $self->{cpqHeTemperatureIndex},
            $self->{cpqHeTemperatureLocale}),
        value => $self->{cpqHeTemperature},
        warning => $self->{cpqHeTemperatureThreshold},
        critical => $self->{cpqHeTemperatureThreshold}
    );
  } 
  $self->add_extendedinfo(sprintf "temp_%s=%d",
      $self->{cpqHeTemperatureIndex},
      $self->{cpqHeTemperature});
}

sub dump { 
  my $self = shift;
  printf "[TEMP_%s]\n", $self->{cpqHeTemperatureIndex};
  foreach (qw(cpqHeTemperatureChassis cpqHeTemperatureIndex 
      cpqHeTemperatureLocale cpqHeTemperatureCelsius cpqHeTemperatureThreshold
      cpqHeTemperatureThresholdType cpqHeTemperatureCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n\n", $self->{info};
}


package HP::Proliant::Component::TemperatureSubsystem::SoSTemperature;
our @ISA = qw(HP::Proliant::Component::TemperatureSubsystem::Temperature);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub check {
  my $self = shift;
  $self->blacklist('t', $self->{cpqHeTemperatureIndex});
  $self->add_info(sprintf "%d %s temperature is %d%s (no thresh.)",
      $self->{cpqHeTemperatureIndex}, $self->{cpqHeTemperatureLocale}, 
      $self->{cpqHeTemperature}, $self->{cpqHeTemperatureUnits});
  if ($self->{runtime}->{options}->{perfdata} == 2) {
    $self->{runtime}->{plugin}->add_perfdata(
        label => sprintf('temp_%s', $self->{cpqHeTemperatureIndex}),
        value => $self->{cpqHeTemperature},
    );
  } elsif ($self->{runtime}->{options}->{perfdata} == 1) {
    $self->{runtime}->{plugin}->add_perfdata(
        label => sprintf('temp_%s_%s', $self->{cpqHeTemperatureIndex},
            $self->{cpqHeTemperatureLocale}),
        value => $self->{cpqHeTemperature},
    );
  } 
  $self->add_extendedinfo(sprintf "temp_%s=%d",
      $self->{cpqHeTemperatureIndex},
      $self->{cpqHeTemperature});
}

1;

