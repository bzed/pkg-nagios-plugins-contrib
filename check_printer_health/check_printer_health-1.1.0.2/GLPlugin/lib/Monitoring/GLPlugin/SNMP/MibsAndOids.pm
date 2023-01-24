package Monitoring::GLPlugin::SNMP::MibsAndOids;
our @ISA = qw(Monitoring::GLPlugin::SNMP);

{
  no warnings qw(once);
  $Monitoring::GLPlugin::SNMP::MibsAndOids::discover_ids = {};
  $Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids = {};
  $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids = {};
  $Monitoring::GLPlugin::SNMP::MibsAndOids::definitions = {};
  $Monitoring::GLPlugin::SNMP::MibsAndOids::origin = {};
}

1;

__END__

