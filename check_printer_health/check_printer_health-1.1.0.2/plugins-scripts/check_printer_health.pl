# /usr/bin/perl -w

use strict;
no warnings qw(once);

if ( ! grep /BEGIN/, keys %Monitoring::GLPlugin::) {
  eval {
    require Monitoring::GLPlugin;
    require Monitoring::GLPlugin::SNMP;
    require Monitoring::GLPlugin::UPNP;
  };
  if ($@) {
    printf "UNKNOWN - module Monitoring::GLPlugin was not found. Either build a standalone version of this plugin or set PERL5LIB\n";
    printf "%s\n", $@;
    exit 3;
  }
}

my $plugin = Classes::Device->new(
    shortname => '',
    usage => 'Usage: %s [ -v|--verbose ] [ -t <timeout> ] '.
        '--mode <what-to-do> '.
        '--hostname <network-component> --community <snmp-community>'.
        '  ...]',
    version => '$Revision: #PACKAGE_VERSION# $',
    blurb => 'This plugin checks various parameters of network printers ',
    url => 'http://labs.consol.de/nagios/check_printer_health',
    timeout => 60,
    plugin => $Monitoring::GLPlugin::pluginname,
);
$plugin->add_mode(
    internal => 'device::hardware::health',
    spec => 'hardware-health',
    alias => undef,
    help => 'Check the status of hardware, if printing is possible',
);
$plugin->add_mode(
    internal => 'device::printer::consumables',
    spec => 'supplies-status',
    help => 'Check the availability of consumables (toner, ink, ...)',
);
$plugin->add_snmp_modes();
$plugin->add_snmp_args();
$plugin->add_default_args();
$plugin->mod_arg("name",
    help => "--name
   The name of an interface (ifDescr) or pool or ...",
);

$plugin->getopts();
$plugin->classify();
$plugin->validate_args();

if (! $plugin->check_messages()) {
  $plugin->init();
  if (! $plugin->check_messages()) {
    $plugin->add_ok($plugin->get_summary())
        if $plugin->get_summary();
    $plugin->add_ok($plugin->get_extendedinfo(" "))
        if $plugin->get_extendedinfo();
  }
} elsif ($plugin->opts->snmpwalk && $plugin->opts->offline) {
  ;
} else {
  ;
}
my ($code, $message) = $plugin->opts->multiline ?
    $plugin->check_messages(join => "\n", join_all => ', ') :
    $plugin->check_messages(join => ', ', join_all => ', ');
$message .= sprintf "\n%s\n", $plugin->get_info("\n")
    if $plugin->opts->verbose >= 1;

$plugin->nagios_exit($code, $message);
