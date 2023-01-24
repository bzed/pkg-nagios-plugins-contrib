package Monitoring::GLPlugin::SNMP::MibsAndOids::PRINTERPORTMONITORMIB;

$Monitoring::GLPlugin::SNMP::MibsAndOids::origin->{'PRINTER-PORT-MONITOR-MIB'} = {
  url => '',
  name => 'PRINTER-PORT-MONITOR-MIB',
};

$Monitoring::GLPlugin::SNMP::MibsAndOids::mib_ids->{'PRINTER-PORT-MONITOR-MIB'} =
    '1.3.6.1.4.1.2699.1.2';

$Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{'PRINTER-PORT-MONITOR-MIB'} = {
  ppmMIB => '1.3.6.1.4.1.2699.1.2',
  ppmMIBObjects => '1.3.6.1.4.1.2699.1.2.1',
  ppmGeneral => '1.3.6.1.4.1.2699.1.2.1.1',
  ppmGeneralNaturalLanguage => '1.3.6.1.4.1.2699.1.2.1.1.1',
  ppmGeneralNumberOfPrinters => '1.3.6.1.4.1.2699.1.2.1.1.2',
  ppmGeneralNumberOfPorts => '1.3.6.1.4.1.2699.1.2.1.1.3',
  ppmPrinter => '1.3.6.1.4.1.2699.1.2.1.2',
  ppmPrinterTable => '1.3.6.1.4.1.2699.1.2.1.2.1',
  ppmPrinterEntry => '1.3.6.1.4.1.2699.1.2.1.2.1.1',
  ppmPrinterIndex => '1.3.6.1.4.1.2699.1.2.1.2.1.1.1',
  ppmPrinterName => '1.3.6.1.4.1.2699.1.2.1.2.1.1.2',
  ppmPrinterIEEE1284DeviceId => '1.3.6.1.4.1.2699.1.2.1.2.1.1.3',
  ppmPrinterNumberOfPorts => '1.3.6.1.4.1.2699.1.2.1.2.1.1.4',
  ppmPrinterPreferredPortIndex => '1.3.6.1.4.1.2699.1.2.1.2.1.1.5',
  ppmPrinterHrDeviceIndex => '1.3.6.1.4.1.2699.1.2.1.2.1.1.6',
  ppmPrinterSnmpCommunityName => '1.3.6.1.4.1.2699.1.2.1.2.1.1.7',
  ppmPrinterSnmpQueryEnabled => '1.3.6.1.4.1.2699.1.2.1.2.1.1.8',
  ppmPrinterSnmpQueryEnabledDefinition => 'SNMPv2-TC-v1-MIB::TruthValue',
  ppmPort => '1.3.6.1.4.1.2699.1.2.1.3',
  ppmPortTable => '1.3.6.1.4.1.2699.1.2.1.3.1',
  ppmPortEntry => '1.3.6.1.4.1.2699.1.2.1.3.1.1',
  ppmPortIndex => '1.3.6.1.4.1.2699.1.2.1.3.1.1.1',
  ppmPortEnabled => '1.3.6.1.4.1.2699.1.2.1.3.1.1.2',
  ppmPortName => '1.3.6.1.4.1.2699.1.2.1.3.1.1.3',
  ppmPortServiceNameOrURI => '1.3.6.1.4.1.2699.1.2.1.3.1.1.4',
  ppmPortProtocolType => '1.3.6.1.4.1.2699.1.2.1.3.1.1.5',
  ppmPortProtocolTargetPort => '1.3.6.1.4.1.2699.1.2.1.3.1.1.6',
  ppmPortProtocolAltSourceEnabled => '1.3.6.1.4.1.2699.1.2.1.3.1.1.7',
  ppmPortPrtChannelIndex => '1.3.6.1.4.1.2699.1.2.1.3.1.1.8',
  ppmPortLprByteCountEnabled => '1.3.6.1.4.1.2699.1.2.1.3.1.1.9',
  ppmMIBConformance => '1.3.6.1.4.1.2699.1.2.2',
  ppmMIBObjectGroups => '1.3.6.1.4.1.2699.1.2.2.2',
};

$Monitoring::GLPlugin::SNMP::MibsAndOids::definitions->{'PRINTER-PORT-MONITOR-MIB'} = {
};
