package HP::Proliant::Component::DiskSubsystem::Ide::SNMP;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Ide
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

  # CPQIDE-MIB
  my $oids = {
      cpqIdeControllerEntry => '1.3.6.1.4.1.232.14.2.3.1.1',
      cpqIdeControllerIndex => '1.3.6.1.4.1.232.14.2.3.1.1.1',
      cpqIdeControllerOverallCondition => '1.3.6.1.4.1.232.14.2.3.1.1.2',
      cpqIdeControllerModel => '1.3.6.1.4.1.232.14.2.3.1.1.3',
      cpqIdeControllerSlot => '1.3.6.1.4.1.232.14.2.3.1.1.5',
      cpqIdeControllerOverallConditionValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "failed",
      },
  };

  # INDEX { cpqIdeControllerIndex }
  foreach ($self->get_entries($oids, 'cpqIdeControllerEntry')) {
    push(@{$self->{controllers}},
        HP::Proliant::Component::DiskSubsystem::Ide::Controller->new(%{$_}));
  }

  $oids = {
      cpqIdeLogicalDriveEntry => '1.3.6.1.4.1.232.14.2.6.1.1',
      cpqIdeLogicalDriveControllerIndex => '1.3.6.1.4.1.232.14.2.6.1.1.1',
      cpqIdeLogicalDriveIndex => '1.3.6.1.4.1.232.14.2.6.1.1.2',
      cpqIdeLogicalDriveRaidLevel => '1.3.6.1.4.1.232.14.2.6.1.1.3',
      cpqIdeLogicalDriveCapacity => '1.3.6.1.4.1.232.14.2.6.1.1.4',
      cpqIdeLogicalDriveStatus => '1.3.6.1.4.1.232.14.2.6.1.1.5',
      cpqIdeLogicalDriveCondition => '1.3.6.1.4.1.232.14.2.6.1.1.6',
      cpqIdeLogicalDriveDiskIds => '1.3.6.1.4.1.232.14.2.6.1.1.7',
      cpqIdeLogicalDriveSpareIds => '1.3.6.1.4.1.232.14.2.6.1.1.9',
      cpqIdeLogicalDriveRebuildingDisk => '1.3.6.1.4.1.232.14.2.6.1.1.10',
      cpqIdeLogicalDriveRaidLevelValue => {
          1 => "other",
          2 => "raid0",
          3 => "raid1",
          4 => "raid0plus1",
      },
      cpqIdeLogicalDriveStatusValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "rebuilding",
          5 => "failed",
      },
      cpqIdeLogicalDriveConditionValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "failed",
      },
  };
  # INDEX { cpqIdeLogicalDriveControllerIndex, cpqIdeLogicalDriveIndex }
  foreach ($self->get_entries($oids, 'cpqIdeLogicalDriveEntry')) {
    push(@{$self->{logical_drives}},
        HP::Proliant::Component::DiskSubsystem::Ide::LogicalDrive->new(%{$_}));
  }

  $oids = {
      cpqIdeAtaDiskEntry => '1.3.6.1.4.1.232.14.2.4.1.1',
      cpqIdeAtaDiskControllerIndex => '1.3.6.1.4.1.232.14.2.4.1.1.1',
      cpqIdeAtaDiskIndex => '1.3.6.1.4.1.232.14.2.4.1.1.2',
      cpqIdeAtaDiskModel => '1.3.6.1.4.1.232.14.2.4.1.1.3',
      cpqIdeAtaDiskStatus => '1.3.6.1.4.1.232.14.2.4.1.1.6',
      cpqIdeAtaDiskCondition => '1.3.6.1.4.1.232.14.2.4.1.1.7',
      cpqIdeAtaDiskCapacity => '1.3.6.1.4.1.232.14.2.4.1.1.8',
      cpqIdeAtaDiskLogicalDriveMember => '1.3.6.1.4.1.232.14.2.4.1.1.13',
      cpqIdeAtaDiskIsSpare => '1.3.6.1.4.1.232.14.2.4.1.1.14',
      cpqIdeAtaDiskStatusValue => {
          1 => "other",
          2 => "ok",
          3 => "smartError",
          4 => "failed",
      },
      cpqIdeAtaDiskConditionValue => {
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "failed",
      },
  };
  # INDEX { cpqIdeAtaDiskControllerIndex, cpqIdeAtaDiskIndex }
  foreach ($self->get_entries($oids, 'cpqIdeAtaDiskEntry')) {
    push(@{$self->{physical_drives}},
        HP::Proliant::Component::DiskSubsystem::Ide::PhysicalDrive->new(%{$_}));
  }

}
