package HP::Proliant::Component::DiskSubsystem::Sas::SNMP;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Sas
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
      cpqSasHbaEntry => "1.3.6.1.4.1.232.5.5.1.1.1",
      cpqSasHbaIndex => "1.3.6.1.4.1.232.5.5.1.1.1.1",
      cpqSasHbaLocation => "1.3.6.1.4.1.232.5.5.1.1.1.2",
      cpqSasHbaSlot  => "1.3.6.1.4.1.232.5.5.1.1.1.6",
      cpqSasHbaStatus  => "1.3.6.1.4.1.232.5.5.1.1.1.4",
      cpqSasHbaStatusValue => {
          1 => "other",
          2 => "ok",
          3 => "failed",
      },
      cpqSasHbaCondition  => "1.3.6.1.4.1.232.5.5.1.1.1.5",
      cpqSasHbaConditionValue => {
          1 => "other",
          2 => "ok", 
          3 => "degraded", 
          4 => "failed",
      },
  };

  # INDEX { cpqSasHbaIndex } 
  foreach ($self->get_entries($oids, 'cpqSasHbaEntry')) {
    push(@{$self->{controllers}},
        HP::Proliant::Component::DiskSubsystem::Sas::Controller->new(%{$_}));
  }

  $oids = {
      cpqSasLogDrvEntry => "1.3.6.1.4.1.232.5.5.3.1.1",
      cpqSasLogDrvHbaIndex => "1.3.6.1.4.1.232.5.5.3.1.1.1",
      cpqSasLogDrvIndex => "1.3.6.1.4.1.232.5.5.3.1.1.2",
      cpqSasLogDrvStatus => "1.3.6.1.4.1.232.5.5.3.1.1.4",
      cpqSasLogDrvCondition => "1.3.6.1.4.1.232.5.5.3.1.1.5",
      cpqSasLogDrvRebuildingPercent => "1.3.6.1.4.1.232.5.5.3.1.1.12",
      cpqSasLogDrvRaidLevel => "1.3.6.1.4.1.232.5.5.3.1.1.3",
      cpqSasLogDrvRaidLevelValue => {
          1 => "other",
          2 => "raid0",
          3 => "raid1",
          4 => "raid0plus1",
          5 => "raid5",
          6 => "raid15",
          7 => "volume",
      },
      cpqSasLogDrvConditionValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "failed",
      },
      cpqSasLogDrvStatusValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "rebuilding",
          5 => "failed",
          6 => "offline",
      }
  };
  # INDEX { cpqSasLogDrvCntlrIndex, cpqSasLogDrvIndex }
  foreach ($self->get_entries($oids, 'cpqSasLogDrvEntry')) {
    push(@{$self->{logical_drives}},
        HP::Proliant::Component::DiskSubsystem::Sas::LogicalDrive->new(%{$_}));
  }

  $oids = {
      cpqSasPhyDrvEntry => "1.3.6.1.4.1.232.5.5.2.1.1",
      cpqSasPhyDrvHbaIndex => "1.3.6.1.4.1.232.5.5.2.1.1.1",
      cpqSasPhyDrvIndex => "1.3.6.1.4.1.232.5.5.2.1.1.2",
      cpqSasPhyDrvLocationString => "1.3.6.1.4.1.232.5.5.2.1.1.3",
      cpqSasPhyDrvStatus => "1.3.6.1.4.1.232.5.5.2.1.1.5",
      cpqSasPhyDrvSize => "1.3.6.1.4.1.232.5.5.2.1.1.8",
      cpqSasPhyDrvCondition => "1.3.6.1.4.1.232.5.5.2.1.1.6",
      cpqSasPhyDrvConditionValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "failed",
      },
      cpqSasPhyDrvStatusValue => {
          1 => "other",
          2 => "ok",
          3 => "predictiveFailure",
          4 => "offline",
          5 => "failed",
          6 => "missingWasOk",
          7 => "missingWasPredictiveFailure",
          8 => "missingWasOffline",
          9 => "missingWasFailed",
      },
  };
    
  # INDEX { cpqPhyLogDrvCntlrIndex, cpqSasPhyDrvIndex }
  foreach ($self->get_entries($oids, 'cpqSasPhyDrvEntry')) {
    push(@{$self->{physical_drives}},
        HP::Proliant::Component::DiskSubsystem::Sas::PhysicalDrive->new(%{$_}));
  }

}
