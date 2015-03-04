# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# File version information:
# $Id: Makefile.PL 1404 2015-01-09 16:56:58Z corti $
# $Revision: 1404 $
# $HeadURL: https://svn.id.ethz.ch/nagios_plugins/check_rbl/Makefile.PL $
# $Date: 2015-01-09 17:56:58 +0100 (Fri, 09 Jan 2015) $

##############################################################################
# Define metadata (we read it from the binary)

name              'check_rbl';
version_from      'check_rbl';
perl_version_from 'check_rbl';
all_from          'check_rbl.pod';

##############################################################################
# Specific dependencies

include 'version';

requires 'Data::Validate::Domain'        => 0;
requires 'Data::Validate::IP'            => 0;
requires 'Monitoring::Plugin'            => 0;
requires 'Monitoring::Plugin::Getopt'    => 0;
requires 'Monitoring::Plugin::Threshold' => 0;
requires 'Net::DNS'                      => 0;
requires 'Readonly'                      => 0;
requires 'IO::Select'                    => 0;

install_script  'check_rbl';

tests 't/*.t';

WriteMakefile(
    INSTALLSCRIPT        => '/usr/lib/nagios/plugins/contrib',
    INSTALLSITESCRIPT    => '/usr/lib/nagios/plugins/contrib',
    MAN1PODS             => { 'check_rbl.pod' =>'blib/man1/check_rbl.1', },
    MAN3PODS             => { },
);

