package HP::BladeSystem;

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };
use Data::Dumper;

our @ISA = qw(HP::Server HP::Proliant::Component::SNMP);

sub init {
  my $self = shift;
  $self->{components} = {
      common_enclosure_subsystem => undef,
      power_enclosure_subsystem => undef,
      power_supply_subsystem => undef,
      net_connector_subsystem => undef,
      server_blade_subsystem => undef,
  };
  $self->{serial} = 'unknown';
  $self->{product} = 'unknown';
  $self->{romversion} = 'unknown';
  $self->trace(3, 'BladeSystem identified');
  $self->collect();
  if (! $self->{runtime}->{plugin}->check_messages()) {
    $self->set_serial();
    $self->analyze_common_enclosures();
    $self->analyze_power_enclosures();
    $self->analyze_power_supplies();
    $self->analyze_net_connectors();
    $self->analyze_server_blades();
    $self->check_common_enclosures();
    $self->check_power_enclosures();
    $self->check_power_supplies();
    $self->check_net_connectors();
    $self->check_server_blades();
  }
}

sub identify {
  my $self = shift;
  return sprintf "System: '%s', S/N: '%s'",
      $self->{product}, $self->{serial};
}

sub dump {
  my $self = shift;
  printf STDERR "serial %s\n", $self->{serial};
  printf STDERR "product %s\n", $self->{product};
  printf STDERR "romversion %s\n", $self->{romversion};
  printf STDERR "%s\n", Data::Dumper::Dumper($self->{enclosures});
}

sub analyze_common_enclosures {
  my $self = shift;
  $self->{components}->{common_enclosure_subsystem} =
      HP::BladeSystem::Component::CommonEnclosureSubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub analyze_power_enclosures {
  my $self = shift;
  $self->{components}->{power_enclosure_subsystem} =
      HP::BladeSystem::Component::PowerEnclosureSubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub analyze_power_supplies {
  my $self = shift;
  $self->{components}->{power_supply_subsystem} =
      HP::BladeSystem::Component::PowerSupplySubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub analyze_net_connectors {
  my $self = shift;
  $self->{components}->{net_connector_subsystem} =
      HP::BladeSystem::Component::NetConnectorSubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub analyze_server_blades {
  my $self = shift;
  $self->{components}->{server_blade_subsystem} =
      HP::BladeSystem::Component::ServerBladeSubsystem->new(
    rawdata => $self->{rawdata},
    method => $self->{method},
    runtime => $self->{runtime},
  );
}

sub check_common_enclosures {
  my $self = shift;
  $self->{components}->{common_enclosure_subsystem}->check();
  $self->{components}->{common_enclosure_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;
}

sub check_power_enclosures {
  my $self = shift;
  $self->{components}->{power_enclosure_subsystem}->check();
  $self->{components}->{power_enclosure_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;
}

sub check_power_supplies {
  my $self = shift;
  $self->{components}->{power_supply_subsystem}->check();
  $self->{components}->{power_supply_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;
}

sub check_net_connectors {
  my $self = shift;
  $self->{components}->{net_connector_subsystem}->check();
  $self->{components}->{net_connector_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;
}

sub check_server_blades {
  my $self = shift;
  $self->{components}->{server_blade_subsystem}->check();
  $self->{components}->{server_blade_subsystem}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;
}

sub collect {
  my $self = shift;
  if ($self->{runtime}->{plugin}->opts->snmpwalk) {
    my $cpqRackMibCondition = '1.3.6.1.4.1.232.22.1.3.0';
    $self->trace(3, 'getting cpqRackMibCondition');
    if (! exists $self->{rawdata}->{$cpqRackMibCondition}) {
        $self->add_message(CRITICAL,
            'snmpwalk returns no health data (cpqrack-mib)');
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
      my $cpqSeMibRev = '1.3.6.1.4.1.232.22.1';
      my $cpqSeMibRevMajor = '1.3.6.1.4.1.232.22.1.1.0';
      my $cpqRackMibCondition = '1.3.6.1.4.1.232.22.1.3.0';
      $self->trace(3, 'getting cpqRackMibCondition');
      my $result = $session->get_request(
          -varbindlist => [$cpqRackMibCondition]
      );
      if (!defined($result) ||
          $result->{$cpqRackMibCondition} eq 'noSuchInstance' ||
          $result->{$cpqRackMibCondition} eq 'noSuchObject' ||
          $result->{$cpqRackMibCondition} eq 'endOfMibView') {
        $self->add_message(CRITICAL,
            'snmpwalk returns no health data (cpqrack-mib)');
        $session->close;
      } else {
        $self->trace(3, 'getting cpqRackMibCondition done');
      }
    }
    if (! $self->{runtime}->{plugin}->check_messages()) {
      # snmp peer is alive
      $self->trace(2, sprintf "Protocol is %s",
          $self->{runtime}->{snmpparams}->{'-version'});
      my $cpqSiComponent = "1.3.6.1.4.1.232.2.2";
      my $cpqSiAsset = "1.3.6.1.4.1.232.2.2.2";
      my $cpqRackInfo = "1.3.6.1.4.1.232.22";
      $session->translate;
      my $response = {}; #break the walk up in smaller pieces
      my $tic = time; my $tac = $tic;
      # Walk for Asset
      $tic = time;
      my $response0 = $session->get_table(
          -maxrepetitions => 1,
          -baseoid => $cpqSiComponent);
      if (scalar (keys %{$response0}) == 0) {
        $self->trace(2, sprintf "maxrepetitions failed. fallback");
        $response0 = $session->get_table(
            -baseoid => $cpqSiComponent);
      }
      $tac = time;
      $self->trace(2, sprintf "%03d seconds for walk cpqSiComponent (%d oids)",
          $tac - $tic, scalar(keys %{$response0}));
      $tic = time;
      my $response1 = $session->get_table(
          -maxrepetitions => 1,
          -baseoid => $cpqRackInfo);
      if (scalar (keys %{$response1}) == 0) {
        $self->trace(2, sprintf "maxrepetitions failed. fallback");
        $response1 = $session->get_table(
            -baseoid => $cpqRackInfo);
      }
      $tac = time;
      $self->trace(2, sprintf "%03d seconds for walk cpqRackInfo (%d oids)",
          $tac - $tic, scalar(keys %{$response1}));
      $session->close;
      map { $response->{$_} = $response0->{$_} } keys %{$response0};
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

  my $cpqSiSysSerialNum = "1.3.6.1.4.1.232.2.2.2.1.0";
  my $cpqSiProductName = "1.3.6.1.4.1.232.2.2.4.2.0";

  $self->{serial} =
      SNMP::Utils::get_object($self->{rawdata}, $cpqSiSysSerialNum);
  $self->{product} =
      SNMP::Utils::get_object($self->{rawdata}, $cpqSiProductName);
  $self->{serial} = $self->{serial};
  $self->{product} = lc $self->{product};
  $self->{romversion} = 'unknown';
#####################################################################
$self->{runtime}->{product} = $self->{product};
}

