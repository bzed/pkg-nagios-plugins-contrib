package HP::Proliant::Component::DiskSubsystem::Fca::SNMP;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Fca
    HP::Proliant::Component::SNMP);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = { 
    controllers => [],
    accelerators => [],
    enclosures => [],
    physical_drives => [],
    logical_drives => [],
    spare_drives => [],
    blacklisted => 0,
  };
  bless $self, $class;
  return $self;
}

sub init {
  my $self = shift;
  my $snmpwalk = $self->{rawdata};

  # CPQFCA-MIB
  my $oids = {
      cpqFcaHostCntlrEntry => '1.3.6.1.4.1.232.16.2.7.1.1',
      cpqFcaHostCntlrIndex => '1.3.6.1.4.1.232.16.2.7.1.1.1',
      cpqFcaHostCntlrSlot => '1.3.6.1.4.1.232.16.2.7.1.1.2',
      cpqFcaHostCntlrModel => '1.3.6.1.4.1.232.16.2.7.1.1.3',
      cpqFcaHostCntlrStatus => '1.3.6.1.4.1.232.16.2.7.1.1.4',
      cpqFcaHostCntlrCondition => '1.3.6.1.4.1.232.16.2.7.1.1.5',
      cpqFcaHostCntlrOverallCondition => '1.3.6.1.4.1.232.16.2.7.1.1.8',
      cpqFcaHostCntlrModelValue => {
          1 => "other",
          # You may need to upgrade your driver software and\or instrument
          # agent(s).  You have a drive array controller in the system
          # that the instrument agent does not recognize.  (other according to CPQFCAL-MIB)
          2 => "fchc-p",
          3 => "fchc-e",
          4 => "fchc64",
          5 => "sa-sam",
          6 => "fca-2101",
          7 => "sw64-33",
          8 => "fca-221x",
          9 => "dpfcmc",
          10 => 'fca-2404',
          11 => 'fca-2214',
          12 => 'a7298a',
          13 => 'fca-2214dc',
          14 => 'a6826a',
          15 => 'fcmcG3',
          16 => 'fcmcG4',
          17 => 'ab46xa',
          18 => 'fc-generic',
          19 => 'fca-1143',
          20 => 'fca-1243',
          21 => 'fca-2143',
          22 => 'fca-2243',
          23 => 'fca-1050',
          24 => 'fca-lpe1105',
          25 => 'fca-qmh2462',
          26 => 'fca-1142sr',
          27 => 'fca-1242sr',
          28 => 'fca-2142sr',
          29 => 'fca-2242sr',
          30 => 'fcmc20pe',
          31 => 'fca-81q',
          32 => 'fca-82q',
          33 => 'fca-qmh2562',
          34 => 'fca-81e',
          35 => 'fca-82e',
          36 => 'fca-1205',
      },
      cpqFcaHostCntlrStatusValue => {
          1 => "other",
          2 => "ok",
          3 => "failed",
          4 => "shutdown",
          5 => "loopDegraded",
          6 => "loopFailed",
          7 => "notConnected",
      },
      cpqFcaHostCntlrConditionValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "failed",
      },
      cpqFcaHostCntlrOverallConditionValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "failed",
      }, # cntrl + alle associated storage boxes
  };

  # INDEX { cpqFcaHostCntlrIndex }
  foreach ($self->get_entries($oids, 'cpqFcaHostCntlrEntry')) {
    push(@{$self->{host_controllers}},
        HP::Proliant::Component::DiskSubsystem::Fca::HostController->new(%{$_}));
  }

  $oids = {
      cpqFcaCntlrEntry => '1.3.6.1.4.1.232.16.2.2.1.1',
      cpqFcaCntlrBoxIndex => '1.3.6.1.4.1.232.16.2.2.1.1.1',
      cpqFcaCntlrBoxIoSlot => '1.3.6.1.4.1.232.16.2.2.1.1.2',
      cpqFcaCntlrModel => '1.3.6.1.4.1.232.16.2.2.1.1.3',
      cpqFcaCntlrStatus => '1.3.6.1.4.1.232.16.2.2.1.1.5',
      cpqFcaCntlrCondition => '1.3.6.1.4.1.232.16.2.2.1.1.6',
      cpqFcaCntlrModelValue => {
        1 => "other",
        2 => "fibreArray",
        3 => "msa1000",
        4 => "smartArrayClusterStorage",
        5 => "hsg80",
        6 => "hsv110", 
        7 => "msa500g2", 
        8 => "msa20",
        8 => "msa1510i",
      },
      cpqFcaCntlrStatusValue => {
          1 => "other",
          2 => "ok",
          3 => "failed",
          4 => "offline",
          5 => "redundantPathOffline",
          6 => "notConnected",
      },
      cpqFcaCntlrConditionValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "failed",
      },
  };

  # INDEX { cpqFcaCntlrBoxIndex, cpqFcaCntlrBoxIoSlot }
  foreach ($self->get_entries($oids, 'cpqFcaCntlrEntry')) {
    push(@{$self->{controllers}},
        HP::Proliant::Component::DiskSubsystem::Fca::Controller->new(%{$_}));
  }

  $oids = {
      cpqFcaAccelEntry => '1.3.6.1.4.1.232.16.2.2.2.1',
      cpqFcaAccelBoxIndex => '1.3.6.1.4.1.232.16.2.2.2.1.1',
      cpqFcaAccelBoxIoSlot => '1.3.6.1.4.1.232.16.2.2.2.1.2',
      cpqFcaAccelStatus => '1.3.6.1.4.1.232.16.2.2.2.1.3',
      cpqFcaAccelErrCode => '1.3.6.1.4.1.232.16.2.2.2.1.5',
      cpqFcaAccelBatteryStatus => '1.3.6.1.4.1.232.16.2.2.2.1.6',
      cpqFcaAccelCondition => '1.3.6.1.4.1.232.16.2.2.2.1.9',
      cpqFcaAccelStatusValue => {
          1 => "other",
          2 => "invalid",
          3 => "enabled",
          4 => "tmpDisabled",
          5 => "permDisabled",
      },
      cpqFcaAccelErrCodeValue => {
          1 => 'other',
          2 => 'invalid',
          3 => 'badConfig',
          4 => 'lowBattery',
          5 => 'disableCmd',
          6 => 'noResources',
          7 => 'notConnected',
          8 => 'badMirrorData',
          9 => 'readErr',
          10 => 'writeErr',
          11 => 'configCmd',
          12 => 'expandInProgress',
          13 => 'snapshotInProgress',
          14 => 'redundantLowBattery',
          15 => 'redundantSizeMismatch',
          16 => 'redundantCacheFailure',
          17 => 'excessiveEccErrors',
          19 => 'postEccErrors',
      },
      cpqFcaAccelBatteryStatusValue => {
          1 => 'other',
          2 => 'ok',
          3 => 'recharging',
          4 => 'failed',
          5 => 'degraded',
          6 => 'notPresent',
      },
      cpqFcaAccelConditionValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "failed",
      },
  };

  # INDEX { cpqFcaAccelBoxIndex, cpqFcaAccelBoxIoSlot }
  foreach ($self->get_entries($oids, 'cpqFcaAccelEntry')) {
    push(@{$self->{accelerators}},
        HP::Proliant::Component::DiskSubsystem::Fca::Accelerator->new(%{$_}));
  }

  $oids = {
      cpqFcaLogDrvEntry => '1.3.6.1.4.1.232.16.2.3.1.1',
      cpqFcaLogDrvBoxIndex => '1.3.6.1.4.1.232.16.2.3.1.1.1',
      cpqFcaLogDrvIndex => '1.3.6.1.4.1.232.16.2.3.1.1.2',
      cpqFcaLogDrvFaultTol => '1.3.6.1.4.1.232.16.2.3.1.1.3',
      cpqFcaLogDrvStatus => '1.3.6.1.4.1.232.16.2.3.1.1.4',
      cpqFcaLogDrvPercentRebuild => '1.3.6.1.4.1.232.16.2.3.1.1.6',
      cpqFcaLogDrvSize => '1.3.6.1.4.1.232.16.2.3.1.1.9',
      cpqFcaLogDrvPhyDrvIDs => '1.3.6.1.4.1.232.16.2.3.1.1.10',
      cpqFcaLogDrvCondition => '1.3.6.1.4.1.232.16.2.3.1.1.11',
      cpqFcaLogDrvFaultTolValue => {
          1 => 'other',
          2 => 'none',
          3 => 'mirroring',
          4 => 'dataGuard',
          5 => 'distribDataGuard',
          7 => 'advancedDataGuard',
      },
      cpqFcaLogDrvStatusValue => {
          1 => 'other',
          2 => 'ok',
          3 => 'failed',
          4 => 'unconfigured',
          5 => 'recovering',
          6 => 'readyForRebuild',
          7 => 'rebuilding',
          8 => 'wrongDrive',
          9 => 'badConnect',
          10 => 'overheating',
          11 => 'shutdown',
          12 => 'expanding',
          13 => 'notAvailable',
          14 => 'queuedForExpansion',
          15 => 'hardError',
      },
      cpqFcaLogDrvConditionValue => {
          1 => 'other',
          2 => 'ok',
          3 => 'degraded',
          4 => 'failed',
      },
  };

  # INDEX { cpqFcaLogDrvBoxIndex, cpqFcaLogDrvIndex }
  foreach ($self->get_entries($oids, 'cpqFcaLogDrvEntry')) {
    push(@{$self->{logical_drives}},
        HP::Proliant::Component::DiskSubsystem::Fca::LogicalDrive->new(%{$_}));
  }

  $oids = {
      cpqFcaPhyDrvEntry => '1.3.6.1.4.1.232.16.2.5.1.1',
      cpqFcaPhyDrvBoxIndex => '1.3.6.1.4.1.232.16.2.5.1.1.1',
      cpqFcaPhyDrvIndex => '1.3.6.1.4.1.232.16.2.5.1.1.2',
      cpqFcaPhyDrvModel => '1.3.6.1.4.1.232.16.2.5.1.1.3',
      cpqFcaPhyDrvBay => '1.3.6.1.4.1.232.16.2.5.1.1.5',
      cpqFcaPhyDrvStatus => '1.3.6.1.4.1.232.16.2.5.1.1.6',
      cpqFcaPhyDrvCondition => '1.3.6.1.4.1.232.16.2.5.1.1.31',
      cpqFcaPhyDrvSize => '1.3.6.1.4.1.232.16.2.5.1.1.38',
      cpqFcaPhyDrvBusNumber => '1.3.6.1.4.1.232.16.2.5.1.1.42',
      cpqFcaPhyDrvStatusValue => {
          1 => 'other',
          2 => 'unconfigured',
          3 => 'ok',
          4 => 'threshExceeded',
          5 => 'predictiveFailure',
          6 => 'failed',
      },
      cpqFcaPhyDrvConditionValue => {
          1 => 'other',
          2 => 'ok',
          3 => 'degraded',
          4 => 'failed',
      },
  };

  # INDEX { cpqFcaPhyDrvBoxIndex, cpqFcaPhyDrvIndex }
  foreach ($self->get_entries($oids, 'cpqFcaPhyDrvEntry')) {
    push(@{$self->{physical_drives}},
        HP::Proliant::Component::DiskSubsystem::Fca::PhysicalDrive->new(%{$_}));
  }

  $oids = {
      cpqFcaMibRevMajor => '1.3.6.1.4.1.232.16.1.1.0',
      cpqFcaMibRevMinor => '1.3.6.1.4.1.232.16.1.2.0',
      cpqFcaMibCondition => '1.3.6.1.4.1.232.16.1.3.0',
      cpqFcaMibConditionValue => {
          1 => 'other',
          2 => 'ok',
          3 => 'degraded',
          4 => 'failed',
      },
  };
  $self->{global_status} =
      HP::Proliant::Component::DiskSubsystem::Fca::GlobalStatus->new(
          runtime => $self->{runtime},
          cpqFcaMibCondition => 
            SNMP::Utils::get_object_value($snmpwalk,
                $oids->{cpqFcaMibCondition}, $oids->{cpqFcaMibConditionValue})
      );
}
