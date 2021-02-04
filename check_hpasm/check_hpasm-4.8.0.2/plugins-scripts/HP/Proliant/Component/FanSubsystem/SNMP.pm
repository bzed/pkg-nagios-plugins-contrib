package HP::Proliant::Component::FanSubsystem::SNMP;
our @ISA = qw(HP::Proliant::Component::FanSubsystem
    HP::Proliant::Component::SNMP);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    fans => [],
    he_fans => [],
    th_fans => [],
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  $self->overall_init(%params);
  $self->he_init(%params);
  $self->te_init(%params);
  $self->unite();
  return $self;
}

sub overall_init {
  my $self = shift;
  my %params = @_;
  my $snmpwalk = $params{rawdata};
  # overall
  my $cpqHeThermalSystemFanStatus = '1.3.6.1.4.1.232.6.2.6.4.0';
  my $cpqHeThermalSystemFanStatusValue = {
    1 => 'other',
    2 => 'ok',
    3 => 'degraded',
    4 => 'failed',
  };
  my $cpqHeThermalCpuFanStatus = '1.3.6.1.4.1.232.6.2.6.5.0';
  my $cpqHeThermalCpuFanStatusValue = {
    1 => 'other',
    2 => 'ok',
    4 => 'failed', # shutdown
  };
  $self->{sysstatus} = SNMP::Utils::get_object_value(
      $snmpwalk, $cpqHeThermalSystemFanStatus,
      $cpqHeThermalSystemFanStatusValue);
  $self->{cpustatus} = SNMP::Utils::get_object_value(
      $snmpwalk, $cpqHeThermalCpuFanStatus,
      $cpqHeThermalCpuFanStatusValue);
  $self->{sysstatus} |= lc $self->{sysstatus};
  $self->{cpustatus} |= lc $self->{cpustatus};
}

sub te_init {
  my $self = shift;
  my %params = @_;
  my $snmpwalk = $params{rawdata};
  my $ignore_redundancy = $params{ignore_redundancy};
  # cpqHeThermalFanTable
  my $oids = {
      cpqHeThermalFanEntry => '1.3.6.1.4.1.232.6.2.6.6.1',
      cpqHeThermalFanIndex => '1.3.6.1.4.1.232.6.2.6.6.1.1',
      cpqHeThermalFanRequired => '1.3.6.1.4.1.232.6.2.6.6.1.2',
      cpqHeThermalFanPresent => '1.3.6.1.4.1.232.6.2.6.6.1.3',
      cpqHeThermalFanCpuFan => '1.3.6.1.4.1.232.6.2.6.6.1.4',
      cpqHeThermalFanStatus => '1.3.6.1.4.1.232.6.2.6.6.1.5',
      cpqHeThermalFanHwLocation => '1.3.6.1.4.1.232.6.2.6.6.1.6',
      cpqHeThermalFanRequiredValue => {
        1 => 'other',
        2 => 'nonRequired',
        3 => 'required',
      },
      cpqHeThermalFanPresentValue => {
        1 => 'other',
        2 => 'absent',
        3 => 'present',
      },
      cpqHeThermalFanCpuFanValue => {
        1 => 'other',
        2 => 'systemFan',
        3 => 'cpuFan',
      },
      cpqHeThermalFanStatusValue => {
        1 => 'other',
        2 => 'ok',
        4 => 'failed',
      },
  };
  # INDEX { cpqHeThermalFanIndex }
  foreach ($self->get_entries($oids, 'cpqHeThermalFanEntry')) {
    next if ! $_->{cpqHeThermalFanPresent};
    push(@{$self->{th_fans}},
        HP::Proliant::Component::FanSubsystem::Fan->new(%{$_}));
  }
}

sub he_init {
  my $self = shift;
  my %params = @_;
  my $snmpwalk = $params{rawdata};
  my $ignore_redundancy = $params{ignore_redundancy};
  # cpqHeFltTolFanTable
  my $oids = {
      cpqHeFltTolFanEntry => '1.3.6.1.4.1.232.6.2.6.7.1',
      cpqHeFltTolFanChassis => '1.3.6.1.4.1.232.6.2.6.7.1.1',
      cpqHeFltTolFanIndex => '1.3.6.1.4.1.232.6.2.6.7.1.2',
      cpqHeFltTolFanLocale => '1.3.6.1.4.1.232.6.2.6.7.1.3',
      cpqHeFltTolFanPresent => '1.3.6.1.4.1.232.6.2.6.7.1.4',
      cpqHeFltTolFanType => '1.3.6.1.4.1.232.6.2.6.7.1.5',
      cpqHeFltTolFanSpeed => '1.3.6.1.4.1.232.6.2.6.7.1.6',
      cpqHeFltTolFanRedundant => '1.3.6.1.4.1.232.6.2.6.7.1.7',
      cpqHeFltTolFanRedundantPartner => '1.3.6.1.4.1.232.6.2.6.7.1.8',
      cpqHeFltTolFanCondition => '1.3.6.1.4.1.232.6.2.6.7.1.9',
      cpqHeFltTolFanHotPlug => '1.3.6.1.4.1.232.6.2.6.7.1.10',
      cpqHeFltTolFanHwLocation => '1.3.6.1.4.1.232.6.2.6.7.1.11',
      cpqHeFltTolFanCurrentSpeed => '1.3.6.1.4.1.232.6.2.6.7.1.12',
      cpqHeFltTolFanLocaleValue => {
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
          14 => "managementBoard",
          15 => "backplane",
          16 => "networkSlot",
          17 => "bladeSlot",
          18 => "virtual",
      },
      cpqHeFltTolFanPresentValue => {
          1 => "other",
          2 => "absent",
          3 => "present",
      },
      cpqHeFltTolFanSpeedValue => {
          1 => "other",
          2 => "normal",
          3 => "high",
      },
      cpqHeFltTolFanRedundantValue => {
          1 => "other",
          2 => "notRedundant",
          3 => "redundant",
      },
      cpqHeFltTolFanTypeValue => {
          1 => "other",
          2 => "tachInput",
          3 => "spinDetect",
      },
      cpqHeFltTolFanConditionValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "failed",
      },
      cpqHeFltTolFanHotPlugValue => {
          1 => "other",
          2 => "nonHotPluggable",
          3 => "hotPluggable",
      },
  };
  # INDEX { cpqHeFltTolFanChassis, cpqHeFltTolFanIndex }
  foreach ($self->get_entries($oids, 'cpqHeFltTolFanEntry')) {
    next if ! defined $_->{cpqHeFltTolFanIndex};
    # z.b. USM65201WS hat nur solche fragmente. die werden erst gar nicht
    # als fans akzeptiert. dafuer gibts dann die overall condition
    # SNMPv2-SMI::enterprises.232.6.2.6.7.1.1.0.1 = INTEGER: 0
    # SNMPv2-SMI::enterprises.232.6.2.6.7.1.1.0.2 = INTEGER: 0
    $_->{cpqHeFltTolFanPctMax} = ($_->{cpqHeFltTolFanPresent} eq 'present') ?
        50 : 0;
    push(@{$self->{he_fans}},
        HP::Proliant::Component::FanSubsystem::Fan->new(%{$_}));
  }

}

sub unite {
  my $self = shift;
  my $tmpfans = {};
  foreach (@{$self->{he_fans}}) {
    $tmpfans->{$_->{cpqHeFltTolFanIndex}} = $_;
  }
  foreach (@{$self->{he_fans}}) {
    if (exists $tmpfans->{$_->{cpqHeFltTolFanRedundantPartner}}) {
      $_->{partner} = $tmpfans->{$_->{cpqHeFltTolFanRedundantPartner}};
    } else {
      $_->{partner} = undef;
    }
  }
  @{$self->{fans}} = @{$self->{he_fans}};
}

sub overall_check {
  my $self = shift;
  my $result = 0;
  $self->blacklist('ofs', '');
  if ($self->{sysstatus} && $self->{cpustatus}) {
    if ($self->{sysstatus} eq 'degraded') {
      $result = 1;
      $self->add_message(WARNING,
          sprintf 'system fan overall status is %s', $self->{sysstatus});
    } elsif ($self->{sysstatus} eq 'failed') {
      $result = 2;
      $self->add_message(CRITICAL,
          sprintf 'system fan overall status is %s', $self->{sysstatus});
    } 
    if ($self->{cpustatus} eq 'degraded') {
      $result = 1;
      $self->add_message(WARNING,
          sprintf 'cpu fan overall status is %s', $self->{cpustatus});
    } elsif ($self->{cpustatus} eq 'failed') {
      $result = 2;
      $self->add_message(CRITICAL,
          sprintf 'cpu fan overall status is %s', $self->{cpustatus});
    } 
    $self->add_info(sprintf 'overall fan status: system=%s, cpu=%s',
        $self->{sysstatus}, $self->{cpustatus});
  } else {
    $result = 0;
    $self->add_info('this system seems to be water-cooled. no fans found');
  }
  return $result;
}

1;

