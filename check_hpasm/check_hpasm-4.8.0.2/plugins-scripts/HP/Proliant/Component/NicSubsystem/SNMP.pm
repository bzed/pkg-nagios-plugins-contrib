package HP::Proliant::Component::NicSubsystem::SNMP;
our @ISA = qw(HP::Proliant::Component::NicSubsystem
    HP::Proliant::Component::SNMP);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
    logical_nics => [],
    physical_nics => [],
  };
  bless $self, $class;
  $self->overall_init(%params);
  $self->init();
  return $self;
}

sub overall_init {
  my $self = shift;
  my %params = @_;
  my $snmpwalk = $self->{rawdata};
  # overall
  my $cpqNicIfLogMapOverallCondition  = '1.3.6.1.4.1.232.18.2.2.2.0';
  my $cpqNicIfLogMapOverallConditionValue = {
    1 => 'other',
    2 => 'ok',
    3 => 'degraded',
    4 => 'failed',
  };
  $self->{lognicstatus} = SNMP::Utils::get_object_value(
      $snmpwalk, $cpqNicIfLogMapOverallCondition,
      $cpqNicIfLogMapOverallConditionValue);
}

sub init {
  my $self = shift;
  my $snmpwalk = $self->{rawdata};
  my $ifconnect = {};
  # CPQNIC-MIB
  my $oids = {
      cpqNicIfLogMapEntry => '1.3.6.1.4.1.232.18.2.2.1.1',
      cpqNicIfLogMapIndex => '1.3.6.1.4.1.232.18.2.2.1.1.1',
      cpqNicIfLogMapIfNumber => '1.3.6.1.4.1.232.18.2.2.1.1.2',
      cpqNicIfLogMapDescription => '1.3.6.1.4.1.232.18.2.2.1.1.3',
      cpqNicIfLogMapGroupType => '1.3.6.1.4.1.232.18.2.2.1.1.4',
      cpqNicIfLogMapAdapterCount => '1.3.6.1.4.1.232.18.2.2.1.1.5',
      cpqNicIfLogMapAdapterOKCount => '1.3.6.1.4.1.232.18.2.2.1.1.6',
      cpqNicIfLogMapPhysicalAdapters => '1.3.6.1.4.1.232.18.2.2.1.1.7',
      cpqNicIfLogMapMACAddress => '1.3.6.1.4.1.232.18.2.2.1.1.8',
      cpqNicIfLogMapSwitchoverMode => '1.3.6.1.4.1.232.18.2.2.1.1.9',
      cpqNicIfLogMapCondition => '1.3.6.1.4.1.232.18.2.2.1.1.10',
      cpqNicIfLogMapStatus => '1.3.6.1.4.1.232.18.2.2.1.1.11',
      cpqNicIfLogMapNumSwitchovers => '1.3.6.1.4.1.232.18.2.2.1.1.12',
      cpqNicIfLogMapHwLocation => '1.3.6.1.4.1.232.18.2.2.1.1.13',
      cpqNicIfLogMapSpeed => '1.3.6.1.4.1.232.18.2.2.1.1.14',
      cpqNicIfLogMapVlanCount => '1.3.6.1.4.1.232.18.2.2.1.1.15',
      cpqNicIfLogMapVlans => '1.3.6.1.4.1.232.18.2.2.1.1.16',

      cpqNicIfLogMapGroupTypeValue => {
          1 => "unknown",
          2 => "none",
          3 => "redundantPair",
          4 => "nft",
          5 => "alb",
          6 => "fec",
          7 => "gec",
          8 => "ad",
          9 => "slb",
          10 => "tlb",
          11 => "redundancySet",
      },
      cpqNicIfLogMapConditionValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "failed",
      },
      cpqNicIfLogMapStatusValue => {
          1 => "unknown",
          2 => "ok",
          3 => "primaryFailed",
          4 => "standbyFailed",
          5 => "groupFailed",
          6 => "redundancyReduced",
          7 => "redundancyLost",
      },
      cpqNicIfLogMapSwitchoverModeValue => {
          1 => "unknown",
          2 => "none",
          3 => "manual",
          4 => "switchOnFail",
          5 => "preferredPrimary",
      },
  };

  # INDEX { cpqNicIfLogMapIndex }
  foreach ($self->get_entries($oids, 'cpqNicIfLogMapEntry')) {
    push(@{$self->{logical_nics}}, 
        HP::Proliant::Component::NicSubsystem::LogicalNic->new(%{$_})
    );
  }

  $oids = {
      cpqNicIfPhysAdapterEntry => '1.3.6.1.4.1.232.18.2.3.1.1',
      cpqNicIfPhysAdapterIndex => '1.3.6.1.4.1.232.18.2.3.1.1.1',
      cpqNicIfPhysAdapterIfNumber => '1.3.6.1.4.1.232.18.2.3.1.1.2',
      cpqNicIfPhysAdapterRole => '1.3.6.1.4.1.232.18.2.3.1.1.3',
      cpqNicIfPhysAdapterMACAddress => '1.3.6.1.4.1.232.18.2.3.1.1.4',
      cpqNicIfPhysAdapterSlot => '1.3.6.1.4.1.232.18.2.3.1.1.5',
      cpqNicIfPhysAdapterIoAddr => '1.3.6.1.4.1.232.18.2.3.1.1.6',
      cpqNicIfPhysAdapterIrq => '1.3.6.1.4.1.232.18.2.3.1.1.7',
      cpqNicIfPhysAdapterDma => '1.3.6.1.4.1.232.18.2.3.1.1.8',
      cpqNicIfPhysAdapterMemAddr => '1.3.6.1.4.1.232.18.2.3.1.1.9',
      cpqNicIfPhysAdapterPort => '1.3.6.1.4.1.232.18.2.3.1.1.10',
      cpqNicIfPhysAdapterDuplexState => '1.3.6.1.4.1.232.18.2.3.1.1.11',
      cpqNicIfPhysAdapterCondition => '1.3.6.1.4.1.232.18.2.3.1.1.12',
      cpqNicIfPhysAdapterState => '1.3.6.1.4.1.232.18.2.3.1.1.13',
      cpqNicIfPhysAdapterStatus => '1.3.6.1.4.1.232.18.2.3.1.1.14',
      cpqNicIfPhysAdapterStatsValid => '1.3.6.1.4.1.232.18.2.3.1.1.15',
      cpqNicIfPhysAdapterGoodTransmits => '1.3.6.1.4.1.232.18.2.3.1.1.16',
      cpqNicIfPhysAdapterGoodReceives => '1.3.6.1.4.1.232.18.2.3.1.1.17',
      cpqNicIfPhysAdapterBadTransmits => '1.3.6.1.4.1.232.18.2.3.1.1.18',
      cpqNicIfPhysAdapterBadReceives => '1.3.6.1.4.1.232.18.2.3.1.1.19',
      cpqNicIfPhysAdapterAlignmentErrors => '1.3.6.1.4.1.232.18.2.3.1.1.20',
      cpqNicIfPhysAdapterFCSErrors => '1.3.6.1.4.1.232.18.2.3.1.1.21',
      cpqNicIfPhysAdapterSingleCollisionFrames => '1.3.6.1.4.1.232.18.2.3.1.1.22',
      cpqNicIfPhysAdapterMultipleCollisionFrames => '1.3.6.1.4.1.232.18.2.3.1.1.23',
      cpqNicIfPhysAdapterDeferredTransmissions => '1.3.6.1.4.1.232.18.2.3.1.1.24',
      cpqNicIfPhysAdapterLateCollisions => '1.3.6.1.4.1.232.18.2.3.1.1.25',
      cpqNicIfPhysAdapterExcessiveCollisions => '1.3.6.1.4.1.232.18.2.3.1.1.26',
      cpqNicIfPhysAdapterInternalMacTransmitErrors => '1.3.6.1.4.1.232.18.2.3.1.1.27',
      cpqNicIfPhysAdapterCarrierSenseErrors => '1.3.6.1.4.1.232.18.2.3.1.1.28',
      cpqNicIfPhysAdapterFrameTooLongs => '1.3.6.1.4.1.232.18.2.3.1.1.29',
      cpqNicIfPhysAdapterInternalMacReceiveErrors => '1.3.6.1.4.1.232.18.2.3.1.1.30',
      cpqNicIfPhysAdapterHwLocation => '1.3.6.1.4.1.232.18.2.3.1.1.31',
      cpqNicIfPhysAdapterPartNumber => '1.3.6.1.4.1.232.18.2.3.1.1.32',
      cpqNicIfPhysAdapterRoleValue => {
          1 => "unknown",
          2 => "primary",
          3 => "secondary",
          4 => "member",
          5 => "txRx",
          6 => "tx",
          7 => "standby",
          8 => "none",
          255 => "notApplicable",
      },
      cpqNicIfPhysAdapterDuplexStateValue => {
          1 => "unknown",
          2 => "half",
          3 => "full",
      },
      cpqNicIfPhysAdapterConditionValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "failed",
      },
      cpqNicIfPhysAdapterStateValue => {
          1 => "unknown",
          2 => "ok",
          3 => "standby",
          4 => "failed",
      },
      cpqNicIfPhysAdapterStatusValue => {
          1 => "unknown",
          2 => "ok",
          3 => "generalFailure",
          4 => "linkFailure",
      },

  };
  # INDEX { cpqNicIfPhysAdapterIndex }
  foreach ($self->get_entries($oids, 'cpqNicIfPhysAdapterEntry')) {
    push(@{$self->{physical_nics}},
        HP::Proliant::Component::NicSubsystem::PhysicalNic->new(%{$_}));
  }

}

1;
