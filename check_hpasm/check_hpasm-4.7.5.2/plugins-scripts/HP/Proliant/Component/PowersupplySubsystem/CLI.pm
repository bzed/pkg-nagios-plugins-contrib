package HP::Proliant::Component::PowersupplySubsystem::CLI;
our @ISA = qw(HP::Proliant::Component::PowersupplySubsystem);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    powersupplies => [],
    powerconverters => [],
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
  my %tmpps = (
    runtime => $self->{runtime},
    cpqHeFltTolPowerSupplyChassis => 1,
  );
  my $inblock = 0;
  foreach (grep(/^powersupply/, split(/\n/, $self->{rawdata}))) {
    s/^powersupply\s*//g;
    if (/^Power supply #(\d+)/) {
      if ($inblock) {
        $inblock = 0;
        push(@{$self->{powersupplies}},
            HP::Proliant::Component::PowersupplySubsystem::Powersupply->new(%tmpps));
        %tmpps = (
          runtime => $self->{runtime},
          cpqHeFltTolPowerSupplyChassis => 1,
        );
      }
      $tmpps{cpqHeFltTolPowerSupplyBay} = $1;
      $inblock = 1;
    } elsif (/\s*Present\s+:\s+(\w+)/) {
      $tmpps{cpqHeFltTolPowerSupplyPresent} = lc $1 eq 'yes' ? 'present' :
          lc $1 eq 'no' ? 'absent': 'other';
    } elsif (/\s*Redundant\s*:\s+(\w+)/) {
      $tmpps{cpqHeFltTolPowerSupplyRedundant} = lc $1 eq 'yes' ? 'redundant' :
          lc $1 eq 'no' ? 'notRedundant' : 'other';
    } elsif (/\s*Condition\s*:\s+(\w+)/) {
      $tmpps{cpqHeFltTolPowerSupplyCondition} = lc $1;
    } elsif (/\s*Power\s*:\s+(\d+)/) {
      $tmpps{cpqHeFltTolPowerSupplyCapacityUsed} = $1;
    } elsif (/\s*Power Supply not present/) {
      $tmpps{cpqHeFltTolPowerSupplyPresent} = "absent";
      $tmpps{cpqHeFltTolPowerSupplyCondition} = "other";
      $tmpps{cpqHeFltTolPowerSupplyRedundant} = "notRedundant";
    } elsif (/^\s*$/) {
      if ($inblock) {
        $inblock = 0;
        push(@{$self->{powersupplies}},
            HP::Proliant::Component::PowersupplySubsystem::Powersupply->new(%tmpps));
        %tmpps = (
          runtime => $self->{runtime},
          cpqHeFltTolPowerSupplyChassis => 1,
        );
      }
    }
  }
  if ($inblock) {
    push(@{$self->{powersupplies}},
        HP::Proliant::Component::PowersupplySubsystem::Powersupply->new(%tmpps));
    %tmpps = (
      runtime => $params{runtime},
    );
  }
}

1;
