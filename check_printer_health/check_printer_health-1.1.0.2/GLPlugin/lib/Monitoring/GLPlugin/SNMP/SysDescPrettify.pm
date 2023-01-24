package Monitoring::GLPlugin::SNMP::SysDescPrettify;
our @ISA = qw(Monitoring::GLPlugin::SNMP);

{
  no warnings qw(once);
  $Monitoring::GLPlugin::SNMP::SysDescPrettify::vendor_rules = {
    Cisco => {
      vendor_pattern => '.*cisco.*',
      prettifier_funcs => [
        sub {
          my ($sysdescr, $session) = @_;
          if ($sysdescr =~ /(Cisco NX-OS.*? n\d+),.*(Version .*), RELEASE SOFTWARE/) {
            return $1.' '.$2;
          }
          return undef;
        },
      ],
    },
    Netgear => {
      vendor_pattern => '.*(netgear|GS\d+TP).*',
      prettifier_funcs => [
        sub {
          my ($sysdescr, $session) = @_;
          if ($sysdescr =~ /GS\d+TP/) {
            return 'Netgear '.$sysdescr;
          }
          return undef;
        },
      ],
    },
  };
}

1;

__END__

