package HP::Proliant::Component::CpuSubsystem::CLI;
our @ISA = qw(HP::Proliant::Component::CpuSubsystem);

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
  $self->init(%params);
  return $self;
}

sub init {
  my $self = shift;
  my %params = @_;
  my %tmpcpu = (
    runtime => $params{runtime},
  );
  my $inblock = 0;
  foreach (grep(/^server/, split(/\n/, $self->{rawdata}))) {
    if (/Processor:\s+(\d+)/) {
      $tmpcpu{cpqSeCpuUnitIndex} = $1;
      $inblock = 1;
    } elsif (/Name\s*:\s+(.+?)\s*$/) {
      $tmpcpu{cpqSeCpuName} = $1;
    } elsif (/Status\s*:\s+(.+?)\s*$/) {
      $tmpcpu{cpqSeCpuStatus} = lc $1;
    } elsif (/Socket\s*:\s+(.+?)\s*$/) {
      $tmpcpu{cpqSeCpuSlot} = $1;
    } elsif (/^server\s*$/) {
      if ($inblock) {
        $inblock = 0;
        push(@{$self->{cpus}},
            HP::Proliant::Component::CpuSubsystem::Cpu->new(%tmpcpu));
        %tmpcpu = (
          runtime => $params{runtime},
        );
      }
    }
  }
  if ($inblock) {
    push(@{$self->{cpus}},
        HP::Proliant::Component::CpuSubsystem::Cpu->new(%tmpcpu));
  }
}

1;
