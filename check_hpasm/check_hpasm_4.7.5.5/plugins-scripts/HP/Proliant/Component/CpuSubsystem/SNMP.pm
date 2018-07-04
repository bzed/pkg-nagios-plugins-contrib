package HP::Proliant::Component::CpuSubsystem::SNMP;
our @ISA = qw(HP::Proliant::Component::CpuSubsystem
    HP::Proliant::Component::SNMP);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    cpus => [],
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  $self->init();
  return $self;
}

sub init {
  my $self = shift;
  my $snmpwalk = $self->{rawdata};
  # CPQSTDEQ-MIB
  my $oids = {
      cpqSeCpuEntry => '1.3.6.1.4.1.232.1.2.2.1.1',
      cpqSeCpuUnitIndex => '1.3.6.1.4.1.232.1.2.2.1.1.1',
      cpqSeCpuSlot => '1.3.6.1.4.1.232.1.2.2.1.1.2',
      cpqSeCpuName => '1.3.6.1.4.1.232.1.2.2.1.1.3',
      cpqSeCpuStatus => '1.3.6.1.4.1.232.1.2.2.1.1.6',
      cpqSeCpuStatusValue => {
          1 => "unknown",
          2 => "ok",
          3 => "degraded",
          4 => "failed",
          5 => "disabled",
      },
  };

  # INDEX { cpqSeCpuUnitIndex }
  foreach ($self->get_entries($oids, 'cpqSeCpuEntry')) {
    push(@{$self->{cpus}},
        HP::Proliant::Component::CpuSubsystem::Cpu->new(%{$_}));
  }
}

1;
