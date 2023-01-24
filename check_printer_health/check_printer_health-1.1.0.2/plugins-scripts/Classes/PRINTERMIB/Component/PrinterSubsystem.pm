package Classes::PRINTERMIB::Component::PrinterSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::hardware::health/) {
    $self->get_snmp_tables('PRINTER-MIB', [
        ['displays', 'prtConsoleDisplayBufferTable', 'Classes::PRINTERMIB::Component::PrinterSubsystem::Display'],
        ['covers', 'prtCoverTable', 'Classes::PRINTERMIB::Component::PrinterSubsystem::Cover'],
        ['channels', 'prtChannelTable', 'Classes::PRINTERMIB::Component::PrinterSubsystem::Channel'],
    ]);
  } elsif ($self->mode =~ /device::printer::consumables/) {
    $self->get_snmp_tables('PRINTER-MIB', [
        ['inputs', 'prtInputTable', 'Classes::PRINTERMIB::Component::PrinterSubsystem::Input'],
        ['outputs', 'prtOutputTable', 'Classes::PRINTERMIB::Component::PrinterSubsystem::Output'],
        ['supplies', 'prtMarkerSuppliesTable', 'Classes::PRINTERMIB::Component::PrinterSubsystem::MarkerSupply'],
        ['markers', 'prtMarkerTable', 'Classes::PRINTERMIB::Component::PrinterSubsystem::Marker'],
        ['media', 'prtMediaPathTable', 'Classes::PRINTERMIB::Component::PrinterSubsystem::MediaPath'],
    ]);
  }
}

sub check {
  my ($self) = @_;
  $self->SUPER::check();
  if ($self->mode =~ /device::hardware::health/) {
    $self->reduce_messages("hardware working fine");
  } elsif ($self->mode =~ /device::printer::consumables/) {
    $self->reduce_messages("supplies status is fine");
  } else {
    $self->reduce_messages("wos is?");
  }
}

package Classes::PRINTERMIB::Component::PrinterSubsystem::Cover;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my ($self) = @_;
  $self->add_info(sprintf '%s is %s',
      $self->accentfree($self->{prtCoverDescription}),
      $self->{prtCoverStatus}
  );
  if ($self->{prtCoverStatus} =~ /Open/) {
    $self->add_warning();
  }
}

package Classes::PRINTERMIB::Component::PrinterSubsystem::Display;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my ($self) = @_;
  if ($self->{prtConsoleDisplayBufferText}) {
    $self->add_ok($self->accentfree($self->{prtConsoleDisplayBufferText}));
  }
}

package Classes::PRINTERMIB::Component::PrinterSubsystem::Input;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

package Classes::PRINTERMIB::Component::PrinterSubsystem::Output;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

package Classes::PRINTERMIB::Component::PrinterSubsystem::Marker;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

package Classes::PRINTERMIB::Component::PrinterSubsystem::MarkerSupply;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  if ($self->{prtMarkerSuppliesDescription} =~ /^[^ ]{2} [^ ]{2} [^ ]{2}/) {
    # wird ueblicherweise gehext, wenn da umlautschlonz drin ist
    $self->{prtMarkerSuppliesDescription} =
        $self->unhex_octet_string($self->{prtMarkerSuppliesDescription});
  } elsif (! $self->{prtMarkerSuppliesDescription}) {
    # Kyocera ECOSYS P2135dn, prtMarkerSuppliesDescription is empty
    $self->{prtMarkerSuppliesDescription} = $self->{prtMarkerSuppliesType};
  }
  $self->{prtMarkerSuppliesDescription} = $self->accentfree($self->{prtMarkerSuppliesDescription});
  # Found a JetDirect which added nul here and gearman cut off the perfdata
  $self->{prtMarkerSuppliesDescription} = unpack("Z*", $self->{prtMarkerSuppliesDescription});
}

sub check {
  my ($self) = @_;
  if ($self->{prtMarkerSuppliesMaxCapacity} == 0) {
    # prtMarkerSuppliesClass: supplyThatIsConsumed
    # prtMarkerSuppliesDescription: Black Toner
    # prtMarkerSuppliesLevel: 0
    # prtMarkerSuppliesMarkerIndex: 1
    # prtMarkerSuppliesMaxCapacity: 0
    $self->{usage} = $self->{prtMarkerSuppliesClass} eq 'supplyThatIsConsumed' ?
        100 : 0;
  } else {
    $self->{usage} = 100 * $self->{prtMarkerSuppliesLevel} /
        $self->{prtMarkerSuppliesMaxCapacity};
  }
  $self->add_info(sprintf '%s is at %.2f%%',
      $self->{prtMarkerSuppliesDescription}, $self->{usage}
  );
  my $label = $self->accentfree($self->{prtMarkerSuppliesDescription});
  $label =~ s/\s+/_/g;
  $label =~ s/://g;
  if ($self->{prtMarkerSuppliesClass} eq 'supplyThatIsConsumed') {
    $label .= '_remaining';
    $self->set_thresholds(
        metric => $label, warning => '20:', critical => '5:',
    );
  } elsif ($self->{prtMarkerSuppliesClass} eq 'receptacleThatIsFilled') {
    $label .= '_used';
    $self->set_thresholds(
        metric => $label, warning => '90', critical => '95',
    );
  }
  if ($self->{prtMarkerSuppliesLevel} == -1) {
    # indicates that the sub-unit places no restrictions on this parameter
    $self->add_ok();
  } elsif ($self->{prtMarkerSuppliesLevel} == -2) {
    # The value (-2) means unknown
    $self->add_unknown(sprintf 'status of %s is unknown',
        $self->{prtMarkerSuppliesDescription});
  } elsif ($self->{prtMarkerSuppliesLevel} == -3) {
    # A value of (-3) means that the
    # printer knows that there is some supply/remaining space
    $self->add_info(sprintf '%s is sufficiently large',
        $self->{prtMarkerSuppliesDescription}
    );
    $self->add_ok();
  } else {
    if ($self->opts->can("morphmessage") && $self->opts->morphmessage) {
      foreach my $key (keys %{$self->opts->morphmessage}) {
        next if $key ne "empty_full" && $key ne "leer_voll";
        my $empty = (split("_", $key))[0];
        my $full = (split("_", $key))[1];
        if ($self->{prtMarkerSuppliesDescription} =~
            $self->opts->morphmessage->{$key}) {
          $self->get_last_info();
          if ($self->check_thresholds(
              metric => $label, value => $self->{usage})) {
            if ($self->{prtMarkerSuppliesClass} eq 'supplyThatIsConsumed') {
              $self->add_info(sprintf '%s %s',
                  $self->{prtMarkerSuppliesDescription}, $empty);
            } else {
              $self->add_info(sprintf '%s %s',
                  $self->{prtMarkerSuppliesDescription}, $full);
            }
          } else {
            if ($self->{prtMarkerSuppliesClass} eq 'supplyThatIsConsumed') {
              $self->add_info(sprintf '%s %s',
                  $self->{prtMarkerSuppliesDescription}, $full);
            } else {
              $self->add_info(sprintf '%s %s',
                  $self->{prtMarkerSuppliesDescription}, $empty);
            }
          }
        }
      }
    }
    $self->add_message($self->check_thresholds(
        metric => $label, value => $self->{usage},
    ));
    $self->add_perfdata(
        label => $label, value => $self->{usage}, uom => '%',
    );
  }
}

package Classes::PRINTERMIB::Component::PrinterSubsystem::MediaPath;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

package Classes::PRINTERMIB::Component::PrinterSubsystem::Channel;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

__END__


PRINTER-MIB::prtInputStatus
PRINTER-MIB::prtOutputStatus

