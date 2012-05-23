package HP::Storage;

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };
use Data::Dumper;

our @ISA = qw(HP::Server);

sub init {
  my $self = shift;
  $self->{components} = {
      powersupply_subsystem => undef,
      fan_subsystem => undef,
      temperature_subsystem => undef,
      cpu_subsystem => undef,
      memory_subsystem => undef,
      disk_subsystem => undef,
      sensor_subsystem => undef,
  };
  $self->{serial} = 'unknown';
  $self->{product} = 'unknown';
  $self->{romversion} = 'unknown';
  $self->collect();
  if (! $self->{runtime}->{plugin}->check_messages()) {
    $self->set_serial();
#    $self->check_for_buggy_firmware();
#    $self->analyze_cpus();
#    $self->analyze_powersupplies();
#    $self->analyze_fan_subsystem();
#    $self->analyze_temperatures();
#    $self->analyze_memory_subsystem();
    $self->analyze_disk_subsystem();
##    $self->analyze_sensor_subsystem();
#    $self->check_cpus();
#    $self->check_powersupplies();
#    $self->check_fan_subsystem();
#    $self->check_temperatures();
#    $self->check_memory_subsystem();
    $self->check_disk_subsystem();
##    $self->check_sensor_subsystem();
  }
}

sub identify {
  my $self = shift;
  return sprintf "System: '%s', S/N: '%s', ROM: '%s'", 
      $self->{product}, $self->{serial}, $self->{romversion};
}

sub check_for_buggy_firmware {
  my $self = shift;
  my @buggyfirmwares = (
      "P24 12/11/2001",
      "P24 11/15/2002",
      "D13 06/03/2003",
      "D13 09/15/2004",
      "P20 12/17/2002"
  );
  $self->{runtime}->{options}->{buggy_firmware} =
      grep /^$self->{romversion}/, @buggyfirmwares;
}

sub dump {
  my $self = shift;
  printf STDERR "serial %s\n", $self->{serial};
  printf STDERR "product %s\n", $self->{product};
  printf STDERR "romversion %s\n", $self->{romversion};
  printf STDERR "%s\n", Data::Dumper::Dumper($self->{components});
}

sub analyze_powersupplies {
  my $self = shift;
  $self->{components}->{powersupply_subsystem} =
      HP::Storage::Component::PowersupplySubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub analyze_fan_subsystem {
  my $self = shift;
  $self->{components}->{fan_subsystem} = 
      HP::Storage::Component::FanSubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub analyze_temperatures {
  my $self = shift;
  $self->{components}->{temperature_subsystem} = 
      HP::Storage::Component::TemperatureSubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub analyze_cpus {
  my $self = shift;
  $self->{components}->{cpu_subsystem} =
      HP::Storage::Component::CpuSubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub analyze_memory_subsystem {
  my $self = shift;
  $self->{components}->{memory_subsystem} = 
      HP::Storage::Component::MemorySubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub analyze_disk_subsystem {
  my $self = shift;
  $self->{components}->{disk_subsystem} =
      HP::Proliant::Component::DiskSubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub analyze_sensor_subsystem {
  my $self = shift;
  $self->{components}->{sensor_subsystem} =
      HP::FCMGMT::Component::SensorSubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub check_cpus {
  my $self = shift;
  $self->{components}->{cpu_subsystem}->check();
  $self->{components}->{cpu_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;
}

sub check_powersupplies {
  my $self = shift;
  $self->{components}->{powersupply_subsystem}->check();
  $self->{components}->{powersupply_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;
}

sub check_fan_subsystem {
  my $self = shift;
  $self->{components}->{fan_subsystem}->check();
  $self->{components}->{fan_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;
}

sub check_temperatures {
  my $self = shift;
  $self->{components}->{temperature_subsystem}->check();
  $self->{components}->{temperature_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;
}

sub check_memory_subsystem {
  my $self = shift;
  $self->{components}->{memory_subsystem}->check();
  $self->{components}->{memory_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;
}

sub check_disk_subsystem {
  my $self = shift;
  $self->{components}->{disk_subsystem}->check();
  $self->{components}->{disk_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 1;
}

sub check_sensor_subsystem {
  my $self = shift;
  $self->{components}->{isensor_subsystem}->check();
  $self->{components}->{sensor_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 1;
}


sub collect {
  my $self = shift;
  if ($self->{runtime}->{plugin}->opts->snmpwalk) {
    my $cpqSeMibCondition = '1.3.6.1.4.1.232.6.1.3.0';
    # rindsarsch!
    $self->{rawdata}->{$cpqSeMibCondition} = 0;
    if (! exists $self->{rawdata}->{$cpqSeMibCondition}) {
        $self->add_message(CRITICAL,
            'snmpwalk returns no health data (cpqhlth-mib)');
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
    } else {
      # revMajor is often used for discovery of hp devices
      my $cpqSeMibRev = '1.3.6.1.4.1.232.6.1';
      my $cpqSeMibRevMajor = '1.3.6.1.4.1.232.6.1.1.0';
      my $cpqSeMibCondition = '1.3.6.1.4.1.232.6.1.3.0';
      my $result = $session->get_request(
          -varbindlist => [$cpqSeMibCondition]
      );
      # rindsarsch!
      $result->{$cpqSeMibCondition} = 0;
      if (!defined($result) || 
          $result->{$cpqSeMibCondition} eq 'noSuchInstance' ||
          $result->{$cpqSeMibCondition} eq 'noSuchObject' ||
          $result->{$cpqSeMibCondition} eq 'endOfMibView') {
        $self->add_message(CRITICAL,
            'snmpwalk returns no health data (cpqhlth-mib)');
        $session->close;
      } else {
        # this is not reliable. many agents return 4=failed
        #if ($result->{$cpqSeMibCondition} != 2) {
        #  $obstacle = "cmapeerstart";
        #}
      }
    }
    if (! $self->{runtime}->{plugin}->check_messages()) {
      # snmp peer is alive
      $self->trace(2, sprintf "Protocol is %s", 
          $self->{runtime}->{snmpparams}->{'-version'});
      my $cpqSsSys =  "1.3.6.1.4.1.232.8";
      $session->translate;
      my $response = {}; #break the walk up in smaller pieces
      my $tic = time; my $tac = $tic;
      my $response1 = $session->get_table(
          -baseoid => $cpqSsSys);
      $tac = time;
      $self->trace(2, sprintf "%03d seconds for walk cpqSsSys (%d oids)",
          $tac - $tic, scalar(keys %{$response1}));
      $session->close;
      map { $response->{$_} = $response1->{$_} } keys %{$response1};
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
