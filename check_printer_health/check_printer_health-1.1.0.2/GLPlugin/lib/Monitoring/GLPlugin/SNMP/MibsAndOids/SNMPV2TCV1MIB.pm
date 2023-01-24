package Monitoring::GLPlugin::SNMP::MibsAndOids::SNMPV2TCV1MIB;

$Monitoring::GLPlugin::SNMP::MibsAndOids::origin->{'SNMPv2-TC-v1-MIB'} = {
  url => '',
  name => 'SNMPv2-TC-v1-MIB',
};

$Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{'SNMPv2-TC-v1-MIB'} = {
  'TruthValue' => {
    1 => 'true',
    2 => 'false',
  },
  'RowStatus' => {
    1 => 'active',
    2 => 'notInService',
    3 => 'notReady',
    4 => 'createAndGo',
    5 => 'createAndWait',
    6 => 'destroy',
  },
};

1;

__END__
