package Classes::Lexmark;
our @ISA = qw(Classes::Device);
use strict;

sub init {
  my $self = shift;
  if ($self->mode =~ /device::hardware::health/) {
    $self->analyze_and_check_lxprinter_subsystem('Classes::Lexmark::Component::PrinterSubsystem');
    if (! $self->check_errors()) {
      # ...kontrolle ist besser.
      $self->analyze_and_check_printer_subsystem('Classes::PRINTERMIB::Component::PrinterSubsystem');
    }
    $self->reduce_messages_short('hardware working fine');
  } elsif ($self->mode =~ /device::printer::consumables/) {
    $self->analyze_and_check_consumables_subsystem('Classes::Lexmark::Component::ConsumablesSubsystem');
    $self->analyze_and_check_consumables_subsystem('Classes::PRINTERMIB::Component::PrinterSubsystem');
    $self->reduce_messages_short('supplies status is fine');
  } else {
    $self->no_such_mode();
  }
}

