package HP::Proliant::Component::BatterySubsystem::SNMP;
our @ISA = qw(HP::Proliant::Component::BatterySubsystem
    HP::Proliant::Component::SNMP);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    sysbatteries => [],
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  $self->init(%params);
  return $self;
}

sub init {
  my $self = shift;
  my %params = @_;
  my $snmpwalk = $self->{rawdata};
  my $oids = {
      cpqHeSysBatteryTable => '1.3.6.1.4.1.232.6.2.17.2',
      cpqHeSysBatteryEntry => '1.3.6.1.4.1.232.6.2.17.2.1',
      cpqHeSysBatteryChassis => '1.3.6.1.4.1.232.6.2.17.2.1.1',
      cpqHeSysBatteryIndex => '1.3.6.1.4.1.232.6.2.17.2.1.2',
      cpqHeSysBatteryPresent => '1.3.6.1.4.1.232.6.2.17.2.1.3',
      cpqHeSysBatteryPresentValue => {
        '1' => 'other',
        '2' => 'absent',
        '3' => 'present',
      },
      cpqHeSysBatteryCondition => '1.3.6.1.4.1.232.6.2.17.2.1.4',
      cpqHeSysBatteryConditionValue => {
        '1' => 'other',
        '2' => 'ok',
        '3' => 'degraded',
        '4' => 'failed',
      },
      cpqHeSysBatteryStatus => '1.3.6.1.4.1.232.6.2.17.2.1.5',
      cpqHeSysBatteryStatusValue => {
        '1' => 'noError',
        '2' => 'generalFailure',
        '3' => 'shutdownHighResistance',
        '4' => 'shutdownLowVoltage',
        '5' => 'shutdownShortCircuit',
        '6' => 'shutdownChargeTimeout',
        '7' => 'shutdownOverTemperature',
        '8' => 'shutdownDischargeMinVoltage',
        '9' => 'shutdownDischargeCurrent',
        '10' => 'shutdownLoadCountHigh',
        '11' => 'shutdownEnablePin',
        '12' => 'shutdownOverCurrent',
        '13' => 'shutdownPermanentFailure',
        '14' => 'shutdownBackupTimeExceeded',
      },
      cpqHeSysBatteryCapacityMaximum => '1.3.6.1.4.1.232.6.2.17.2.1.6',
      cpqHeSysBatteryProductName => '1.3.6.1.4.1.232.6.2.17.2.1.7',
      cpqHeSysBatteryModel => '1.3.6.1.4.1.232.6.2.17.2.1.8',
      cpqHeSysBatterySerialNumber => '1.3.6.1.4.1.232.6.2.17.2.1.9',
      cpqHeSysBatteryFirmwareRev => '1.3.6.1.4.1.232.6.2.17.2.1.10',
      cpqHeSysBatterySparePartNum => '1.3.6.1.4.1.232.6.2.17.2.1.11',
  };
  # INDEX { cpqHeSysBatteryChassis, cpqHeSysBatteryIndex }
  foreach ($self->get_entries($oids, 'cpqHeSysBatteryEntry')) {
    next if ! $_->{cpqHeSysBatteryPresent} eq "present";
    push(@{$self->{sysbatteries}},
        HP::Proliant::Component::BatterySubsystem::Battery->new(%{$_}));
  }
}

1;
