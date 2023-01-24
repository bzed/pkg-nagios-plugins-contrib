package Classes::PRINTERMIB;
our @ISA = qw(Classes::Device);
use strict;

sub init {
  my $self = shift;
  if ($self->mode =~ /device::hardware::health/) {
    $self->analyze_and_check_environmental_subsystem('Classes::PRINTERMIB::Component::PrinterSubsystem');
  } elsif ($self->mode =~ /device::printer::consumables/) {
    $self->analyze_and_check_environmental_subsystem('Classes::PRINTERMIB::Component::PrinterSubsystem');
    $self->reduce_messages_short('supplies status is fine');
  } else {
    $self->no_such_mode();
  }
}

