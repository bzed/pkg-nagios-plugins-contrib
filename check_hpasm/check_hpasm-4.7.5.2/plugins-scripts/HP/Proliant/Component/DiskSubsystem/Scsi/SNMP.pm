package HP::Proliant::Component::DiskSubsystem::Scsi::SNMP;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Scsi
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

  # CPQSCSI-MIB
  my $oids = {
      cpqScsiCntlrEntry => '1.3.6.1.4.1.232.5.2.2.1.1',
      cpqScsiCntlrIndex => '1.3.6.1.4.1.232.5.2.2.1.1.1',
      cpqScsiCntlrBusIndex => '1.3.6.1.4.1.232.5.2.2.1.1.2',
      cpqScsiCntlrSlot => '1.3.6.1.4.1.232.5.2.2.1.1.6',
      cpqScsiCntlrStatus => '1.3.6.1.4.1.232.5.2.2.1.1.7',
      cpqScsiCntlrCondition => '1.3.6.1.4.1.232.5.2.2.1.1.12',
      cpqScsiCntlrHwLocation => '1.3.6.1.4.1.232.5.2.2.1.1.16',
      cpqScsiCntlrStatusValue => {
          1 => "other",
          2 => "ok",
          3 => "failed",
      },
      cpqScsiCntlrConditionValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "failed",
      }
  };

  # INDEX { cpqScsiCntlrIndex, cpqScsiCntlrBusIndex }
  foreach ($self->get_entries($oids, 'cpqScsiCntlrEntry')) {
    push(@{$self->{controllers}},
        HP::Proliant::Component::DiskSubsystem::Scsi::Controller->new(%{$_}));
  }

  $oids = {
      cpqScsiLogDrvEntry => '1.3.6.1.4.1.232.5.2.3.1.1',
      cpqScsiLogDrvCntlrIndex => '1.3.6.1.4.1.232.5.2.3.1.1.1',
      cpqScsiLogDrvBusIndex => '1.3.6.1.4.1.232.5.2.3.1.1.2',
      cpqScsiLogDrvIndex => '1.3.6.1.4.1.232.5.2.3.1.1.3',
      cpqScsiLogDrvFaultTol => '1.3.6.1.4.1.232.5.2.3.1.1.4',
      cpqScsiLogDrvStatus => '1.3.6.1.4.1.232.5.2.3.1.1.5',
      cpqScsiLogDrvSize => '1.3.6.1.4.1.232.5.2.3.1.1.6',
      cpqScsiLogDrvPhyDrvIDs => '1.3.6.1.4.1.232.5.2.3.1.1.7',
      cpqScsiLogDrvCondition => '1.3.6.1.4.1.232.5.2.3.1.1.8',
      cpqScsiLogDrvStatusValue => {
          1 => "other",
          2 => "ok",
          3 => "failed",
          4 => "unconfigured",
          5 => "recovering",
          6 => "readyForRebuild",
          7 => "rebuilding",
          8 => "wrongDrive",
          9 => "badConnect",
      },
      cpqScsiLogDrvConditionValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "failed",
      },
      cpqScsiLogDrvFaultTolValue => {
          1 => "other",
          2 => "none",
          3 => "mirroring",
          4 => "dataGuard",
          5 => "distribDataGuard",
      },

  };
  # INDEX { cpqScsiLogDrvCntlrIndex, cpqScsiLogDrvBusIndex, cpqScsiLogDrvIndex }
  foreach ($self->get_entries($oids, 'cpqScsiLogDrvEntry')) {
    push(@{$self->{logical_drives}},
        HP::Proliant::Component::DiskSubsystem::Scsi::LogicalDrive->new(%{$_}));
  }

  $oids = {
      cpqScsiPhyDrvEntry => '1.3.6.1.4.1.232.5.2.4.1.1',
      cpqScsiPhyDrvCntlrIndex => '1.3.6.1.4.1.232.5.2.4.1.1.1',
      cpqScsiPhyDrvBusIndex => '1.3.6.1.4.1.232.5.2.4.1.1.2',
      cpqScsiPhyDrvIndex => '1.3.6.1.4.1.232.5.2.4.1.1.3',
      cpqScsiPhyDrvStatus => '1.3.6.1.4.1.232.5.2.4.1.1.9',
      cpqScsiPhyDrvSize => '1.3.6.1.4.1.232.5.2.4.1.1.7',
      cpqScsiPhyDrvCondition => '1.3.6.1.4.1.232.5.2.4.1.1.26',
      cpqScsiPhyDrvConditionValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "failed",
      },
      cpqScsiPhyDrvStatusValue => {
          1 => "other",
          2 => "ok",
          3 => "failed",
          4 => "notConfigured",
          5 => "badCable",
          6 => "missingWasOk",
          7 => "missingWasFailed",
          8 => "predictiveFailure",
          9 => "missingWasPredictiveFailure",
          10 => "offline",
          11 => "missingWasOffline",
          12 => "hardError",
      },
  };
    
  # INDEX { cpqScsiPhyDrvCntlrIndex, cpqScsiPhyDrvBusIndex, cpqScsiPhyDrvIndex }
  foreach ($self->get_entries($oids, 'cpqScsiPhyDrvEntry')) {
    push(@{$self->{physical_drives}},
        HP::Proliant::Component::DiskSubsystem::Scsi::PhysicalDrive->new(%{$_}));
  }

}
