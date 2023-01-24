package Classes::Brother;
our @ISA = qw(Classes::Device);
use strict;

sub init {
  my $self = shift;
  if ($self->mode =~ /device::hardware::health/) {
    $self->analyze_and_check_environmental_subsystem('Classes::HOSTRESOURCESMIB::Component::EnvironmentalSubsystem');
  } elsif ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem('Classes::Kyocera::Components::BatterySubsystem');
  } else {
    $self->no_such_mode();
  }
}

