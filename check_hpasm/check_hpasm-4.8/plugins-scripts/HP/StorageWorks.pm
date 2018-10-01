package HP::StorageWorks;

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };
use Data::Dumper;

our @ISA = qw(HP::Server);

sub init {
  my $self = shift;
  $self->{serial} = 'unknown';
  $self->{product} = 'unknown';
  $self->{romversion} = 'unknown';
  $self->collect();
  if (! $self->{runtime}->{plugin}->check_messages()) {
    $self->set_serial();
    $self->overall_init();
    $self->overall_check();
  }
}

sub overall_init {
  my $self = shift;
  my %params = @_;
  my $snmpwalk = $self->{rawdata};
  my $cpqHoMibStatusArray = '1.3.6.1.4.1.232.11.2.10.1.0';
  $self->{cpqHoMibStatusArray} = SNMP::Utils::get_object(
      $snmpwalk, $cpqHoMibStatusArray);
  if ($self->{cpqHoMibStatusArray} =~ /^(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
    $self->{cpqHoMibStatusArray} = 1 * $2;
  } elsif ($self->{cpqHoMibStatusArray} =~ /^0x.*(\d\d)(\d\d)(\d\d)(\d\d)$/) {
    $self->{cpqHoMibStatusArray} = 1 * $2;
  }
}

sub overall_check {
  my $self = shift;
  if ($self->{cpqHoMibStatusArray} == 4) {
    $self->add_info('overall status is failed');
    $self->add_message(CRITICAL, 'overall status is failed');
  } elsif ($self->{cpqHoMibStatusArray} == 3) {
    $self->add_info('overall status is degraded');
    $self->add_message(WARNING, 'overall status is degraded');
  } elsif ($self->{cpqHoMibStatusArray} == 2) {
    $self->add_info('overall status is ok');
    $self->add_message(OK, 'overall status is ok');
  } elsif ($self->{cpqHoMibStatusArray} == 1) {
    $self->add_info('overall status is other');
    $self->add_message(UNKNOWN, 'overall status is other');
  }
}

sub identify {
  my $self = shift;
  return $self->{productname};
}

sub dump {
  my $self = shift;
  printf STDERR "serial %s\n", $self->{serial};
  printf STDERR "product %s\n", $self->{product};
  printf STDERR "romversion %s\n", $self->{romversion};
  printf STDERR "%s\n", Data::Dumper::Dumper($self->{components});
}

sub collect {
  my $self = shift;
  if ($self->{runtime}->{plugin}->opts->snmpwalk) {
    my $cpqHoMibStatusArray = '1.3.6.1.4.1.232.11.2.10.1.0';
    if (! exists $self->{rawdata}->{$cpqHoMibStatusArray}) {
        $self->add_message(CRITICAL,
            'snmpwalk returns no health data (cpqhost-mib)');
    }
  } else {
    my $net_snmp_version = Net::SNMP->VERSION(); # 5.002000 or 6.000000
    #$params{'-translate'} = [
    #  -all => 0x0
    #];
    my ($session, $error) = 
        Net::SNMP->session(%{$self->{runtime}->{snmpparams}});
    if (! defined $session) {
      $self->{plugin}->add_message(CRITICAL, 'cannot create session object');
      $self->trace(1, Data::Dumper::Dumper($self->{runtime}->{snmpparams}));
    }
    if (! $self->{runtime}->{plugin}->check_messages()) {
      # snmp peer is alive
      $self->trace(2, sprintf "Protocol is %s", 
          $self->{runtime}->{snmpparams}->{'-version'});
      my $cpqHoMibStatusArray = '1.3.6.1.4.1.232.11.2.10.1.0';
      $session->translate;
      my $tic = time;
      my $response = $session->get_request(
          -varbindlist => [$cpqHoMibStatusArray]
      );
      my $tac = time;
      $self->trace(2, sprintf "%03d seconds for walk cpqHoMibStatusArray (%d oids)",
          $tac - $tic, scalar(keys %{$response}));
      $session->close;
      map { $response->{$_} =~ s/^\s+//; $response->{$_} =~ s/\s+$//; }
          keys %$response;
      $self->{rawdata} = $response;
    }
  }
  return $self->{runtime}->{plugin}->check_messages();
}

sub set_serial {
  my $self = shift;
  my $snmpwalk = $self->{rawdata};
  my @serials = ();
  my @models = ();
  my @fws = ();
  my $cpqSsBackplaneEntry = '1.3.6.1.4.1.232.8.2.2.6.1';
  my $cpqSsBackplaneFWRev = '1.3.6.1.4.1.232.8.2.2.6.1.3';
  my $cpqSsBackplaneModel = '1.3.6.1.4.1.232.8.2.2.6.1.9';
  my $cpqSsBackplaneSerialNumber = '1.3.6.1.4.1.232.8.2.2.6.1.13';
  # INDEX { cpqSsBackplaneChassisIndex, cpqSsBackplaneIndex }
  my @indexes = SNMP::Utils::get_indices($snmpwalk,
      $cpqSsBackplaneEntry);
  foreach (@indexes) {
    my($idx1, $idx2) = ($_->[0], $_->[1]);
    my $fw = SNMP::Utils::get_object($snmpwalk,
        $cpqSsBackplaneFWRev, $idx1, $idx2);
    my $model = SNMP::Utils::get_object($snmpwalk,
        $cpqSsBackplaneModel, $idx1, $idx2);
    my $serial = SNMP::Utils::get_object($snmpwalk,
        $cpqSsBackplaneSerialNumber, $idx1, $idx2);
    push(@serials, $serial);
    push(@models, $model);
    push(@fws, $fw);
  }
  
  $self->{serial} = join('/', @serials);
  $self->{product} = join('/', @models);
  $self->{romversion} = join('/', @fws);
  $self->{runtime}->{product} = $self->{product};
}



















1;
