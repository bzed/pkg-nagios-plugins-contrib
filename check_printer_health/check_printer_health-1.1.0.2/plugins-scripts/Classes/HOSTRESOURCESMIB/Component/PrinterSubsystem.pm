package Classes::HOSTRESOURCESMIB::Component::PrinterSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my $self = shift;
  $self->get_snmp_tables('HOST-RESOURCES-MIB', [
      ['printers', 'hrPrinterTable', 'Classes::HOSTRESOURCESMIB::Component::PrinterSubsystem::Printer'],
      ['devices', 'hrDeviceTable', 'Classes::HOSTRESOURCESMIB::Component::DeviceSubsystem::Device'],
  ]);
  foreach my $printer (@{$self->{printers}}) {
    foreach my $device (@{$self->{devices}}) {
      if ($device->{flat_indices} eq $printer->{flat_indices}) {
        map {
          $printer->{$_} = $device->{$_};
        } grep { $_ =~ /^hrDevice/; } keys %{$device};
      }
    }
  }
  delete $self->{devices};
}

package Classes::HOSTRESOURCESMIB::Component::PrinterSubsystem::Printer;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my $self = shift;
  my @errors = split('|', $self->{hrPrinterDetectedErrorState});
  @errors = grep ! /^(no|low)/, @errors;
  if (! @errors && $self->{hrDeviceStatus} =~ /(warning|down)/) {
    $self->{hrDeviceStatus} = 'running';
  }
  $self->{hrPrinterDetectedErrorState} = join("|", @errors);
}

sub check {
  my $self = shift;
  $self->add_info(sprintf '%s has status %s',
      $self->{hrDeviceDescr},
      $self->{hrPrinterDetectedErrorState},
  );
  if ($self->{hrDeviceStatus} eq 'warning') {
    $self->add_warning();
  } elsif ($self->{hrDeviceStatus} eq 'down') {
    $self->add_critical();
  } else {
    $self->add_ok();
  }
}

