package HP::Proliant::Component::TemperatureSubsystem::CLI;
our @ISA = qw(HP::Proliant::Component::TemperatureSubsystem);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    temperatures => [],
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
  my $tempcnt = 1;
  foreach (grep(/^temp/, split(/\n/, $params{rawdata}))) {
    s/^temp\s*//g;
    if (/^#(\d+)\s+([\w_\/\-#]+)\s+(-*\d+)C\/(\d+)F\s+(\d+)C\/(\d+)F/) {
      my %params = ();
      $params{runtime} = $self->{runtime};
      $params{cpqHeTemperatureChassis} = 1;
      $params{cpqHeTemperatureIndex} = $1;
      $params{cpqHeTemperatureLocale} = lc $2;
      $params{cpqHeTemperatureCelsius} = $3;
      $params{cpqHeTemperatureThresholdCelsius} = $5;
      $params{cpqHeTemperatureCondition} = 'unknown';
      push(@{$self->{temperatures}},
          HP::Proliant::Component::TemperatureSubsystem::Temperature->new(
              %params));
    } elsif (/^#(\d+)\s+([\w_\/\-#]+)\s+\-\s+(\d+)C\/(\d+)F/) {
      # #3        CPU#2                -       0C/0F
      $self->trace(2, sprintf "skipping temperature %s", $_);
    } elsif (/^#(\d+)\s+([\w_\/\-#]+)\s+(\d+)C\/(\d+)F\s+\-/) {
      # #3        CPU#2                0C/0F       -
      $self->trace(2, sprintf "skipping temperature %s", $_);
    } elsif (/^#(\d+)\s+([\w_\/\-#]+)\s+\-\s+\-/) {
      # #3        CPU#2                -       -
      $self->trace(2, sprintf "skipping temperature %s", $_);
    } elsif (/^#(\d+)/) {
      $self->trace(0, sprintf "send this to lausser: %s", $_);
    }
  }
}

1;
