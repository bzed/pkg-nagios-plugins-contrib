package Classes::Lexmark::Component::PrinterSubsystem;;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my $self = shift;
  $self->get_snmp_tables('LEXMARK-MPS-MIB', [
      ['alerts', 'deviceAlertTable', 'Classes::Lexmark::Component::PrinterSubsystem::Alert'],
  ]);
  $self->get_snmp_tables('LEXMARK-PVT-MIB', [
      ['prtgens', 'prtgenStatusTable', 'Classes::Lexmark::Component::PrinterSubsystem::Printer'],
  ]);
}

package Classes::Lexmark::Component::PrinterSubsystem::Alert;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{deviceAlertTimeHuman} = scalar localtime $self->{deviceAlertTime};
  $self->{deviceAlertAgeMinutes} = (time - $self->{deviceAlertTime}) / 60;
}

sub check {
  my ($self) = @_;
  $self->add_info(sprintf '%s since %dmin',
      $self->{deviceAlertDescription},
      $self->{deviceAlertAgeMinutes}
  );
  if ($self->{deviceAlertSeverity} =~ /serviceRequired|warning/) {
    $self->add_warning_mitigation();
  } elsif ($self->{deviceAlertSeverity} eq "critical") {
    $self->add_critical();
  } elsif ($self->{deviceAlertSeverity} eq "unknown") {
    $self->add_unknown();
  } else {
    $self->add_ok();
  }
}


package Classes::Lexmark::Component::PrinterSubsystem::Printer;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my ($self) = @_;
  if ($self->{prtgenStatusIRC} ne "0") {
    $self->add_warning(sprintf "intervention required code %s is shown",
        $self->{prtgenStatusIRC});
  }
  if ($self->{prtgenStatusOutHopFull} eq "full") {
    $self->add_warning_mitigation("the current output hopper is full");
  }
  if ($self->{prtgenStatusInputEmpty} eq "empty") {
    $self->add_warning_mitigation("the active input paper tray is empty");
  }
  if ($self->{prtgenStatusPaperJam} eq "jamed") {
    $self->add_warning("the paper path is jammed");
  }
  if ($self->{prtgenStatusTonerError} eq "tonerError") {
    $self->add_warning_mitigation("the toner supply status shows an error");
  }
  if ($self->{prtgenStatusSrvcReqd} eq "serviceRequired") {
    $self->add_warning_mitigation("service required");
  }
  if ($self->{prtgenStatusDiskError} eq "diskError") {
    $self->add_critical("the disk has an error");
  }
  if ($self->{prtgenStatusCoverOpen} eq "coverOpen") {
    $self->add_warning("the cover is open");
  }
  if ($self->{prtgenStatusPageComplex} eq "complexPage") {
    #$self->add_warning("something is too complex????");
  }
  if ($self->{prtgenStatusLineStatus} eq "offline") {
    #$self->add_warning("the printer is offline");
  }
}



