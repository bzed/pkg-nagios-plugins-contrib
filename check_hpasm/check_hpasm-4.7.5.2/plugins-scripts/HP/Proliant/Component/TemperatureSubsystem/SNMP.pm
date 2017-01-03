package HP::Proliant::Component::TemperatureSubsystem::SNMP;
our @ISA = qw(HP::Proliant::Component::TemperatureSubsystem
    HP::Proliant::Component::SNMP);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    temperatures => [],
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  $self->overall_init(%params);
  $self->init(%params);
  return $self;
}

sub overall_init {
  my $self = shift;
  my %params = @_;
  my $snmpwalk = $params{rawdata};
  # overall
  my $cpqHeThermalTempStatus  = '1.3.6.1.4.1.232.6.2.6.3.0';
  my $cpqHeThermalTempStatusValue = {
    1 => 'other',
    2 => 'ok',
    3 => 'degraded',
    4 => 'failed',
  };
  $self->{tempstatus} = lc SNMP::Utils::get_object_value(
      $snmpwalk, $cpqHeThermalTempStatus,
      $cpqHeThermalTempStatusValue);
  $self->{tempstatus} |= lc $self->{tempstatus};
}

sub init {
  my $self = shift;
  my %params = @_;
  my $snmpwalk = $self->{rawdata};
  my $oids = {
      cpqHeTemperatureEntry => "1.3.6.1.4.1.232.6.2.6.8.1",
      cpqHeTemperatureChassis => "1.3.6.1.4.1.232.6.2.6.8.1.1",
      cpqHeTemperatureIndex => "1.3.6.1.4.1.232.6.2.6.8.1.2",
      cpqHeTemperatureLocale => "1.3.6.1.4.1.232.6.2.6.8.1.3",
      cpqHeTemperatureCelsius => "1.3.6.1.4.1.232.6.2.6.8.1.4",
      cpqHeTemperatureThresholdCelsius => "1.3.6.1.4.1.232.6.2.6.8.1.5",
      cpqHeTemperatureCondition => "1.3.6.1.4.1.232.6.2.6.8.1.6",
      cpqHeTemperatureThresholdType => "1.3.6.1.4.1.232.6.2.6.8.1.7",
      cpqHeTemperatureLocaleValue => {
          1 => "other",
          2 => "unknown",
          3 => "system",
          4 => "systemBoard",
          5 => "ioBoard",
          6 => "cpu",
          7 => "memory",
          8 => "storage",
          9 => "removableMedia",
          10 => "powerSupply",
          11 => "ambient",
          12 => "chassis",
          13 => "bridgeCard",
      },
      cpqHeTemperatureConditionValue => {
          1 => 'other',
          2 => 'ok',
          3 => 'degraded',
          4 => 'failed',
      },
      cpqHeTemperatureThresholdTypeValue => {
          1 => 'other',
          5 => 'blowout',
          9 => 'caution',
          15 => 'critical',
      },
  };
  # INDEX { cpqHeTemperatureChassis, cpqHeTemperatureIndex }
  foreach ($self->get_entries($oids, 'cpqHeTemperatureEntry')) {
    # sieht aus, als wurden die gar nicht existieren.
    # im ilo4 werden sie als n/a angezeigt
    next if $_->{cpqHeTemperatureThresholdType} eq "caution" && $_->{cpqHeTemperatureThresholdCelsius} == 0;
    push(@{$self->{temperatures}},
        HP::Proliant::Component::TemperatureSubsystem::Temperature->new(%{$_}));
  }
}

sub overall_check {
  my $self = shift;
  my $result = 0;
  $self->blacklist('ots', '');
  if ($self->{tempstatus}) {
    if ($self->{tempstatus} eq "ok") {
      $result = 0;
      $self->add_info('all temp sensors are within normal operating range');
    } elsif ($self->{tempstatus} eq "degraded") {
      $result = 1;
      $self->add_info('a temp sensor is outside of normal operating range');
    } elsif ($self->{tempstatus} eq "failed") {
      $result = 2;
      $self->add_info('a temp sensor detects a condition that could permanently
damage the system');
    } elsif ($self->{tempstatus} eq "other") {
      $result = 0;
      $self->add_info('temp sensing is not supported by this system or driver');
    }
  } else {
    $result = 0;
    $self->add_info('no global temp status found');
  }
}

1;
