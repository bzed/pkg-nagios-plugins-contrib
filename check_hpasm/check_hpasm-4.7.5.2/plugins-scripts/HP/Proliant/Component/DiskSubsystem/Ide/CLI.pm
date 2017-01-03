package HP::Proliant::Component::DiskSubsystem::Ide::CLI;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Ide);

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
}

1;
