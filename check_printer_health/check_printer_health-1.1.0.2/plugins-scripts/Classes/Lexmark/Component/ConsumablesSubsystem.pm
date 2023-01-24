package Classes::Lexmark::Component::ConsumablesSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->get_snmp_tables('LEXMARK-MPS-MIB', [
      ['supplies', 'currentSuppliesTable', 'Classes::Lexmark::Component::ConsumablesSubsystem::Supply'],
  ]);
}

package Classes::Lexmark::Component::ConsumablesSubsystem::Supply;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my ($self) = @_;
  if ($self->{currentSupplyCurrentStatus} eq "low") {
    $self->add_warning_mitigation(sprintf "%s is %s",
        $self->{currentSupplyDescription},
        $self->{currentSupplyCurrentStatus});
  } elsif ($self->{currentSupplyCurrentStatus} eq "empty") {
    $self->add_critical(sprintf "%s is %s",
        $self->{currentSupplyDescription},
        $self->{currentSupplyCurrentStatus});
  } elsif ($self->{currentSupplyCurrentStatus} eq "invalid") {
    $self->add_critical(sprintf "%s is %s",
        $self->{currentSupplyDescription},
        $self->{currentSupplyCurrentStatus});
  }
}
