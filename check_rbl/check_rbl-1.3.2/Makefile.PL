# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# File version information:
# $Id: Makefile.PL 1264 2011-07-11 05:45:43Z corti $
# $Revision: 1264 $
# $HeadURL: https://svn.id.ethz.ch/nagios_plugins/check_rbl/Makefile.PL $
# $Date: 2011-07-11 07:45:43 +0200 (Mon, 11 Jul 2011) $

##############################################################################
# Define metadata (we read it from the binary)

name              'check_rbl';
version_from      'check_rbl';
perl_version_from 'check_rbl';
all_from          'check_rbl.pod';

##############################################################################
# Specific dependencies

include 'version';

requires 'Nagios::Plugin'            => 0.31;
requires 'Nagios::Plugin::Getopt'    => 0;
requires 'Nagios::Plugin::Threshold' => 0;
requires 'Net::DNS'                  => 0;
requires 'Readonly'                  => 0;
requires 'IO::Select'                => 0;

install_script  'check_rbl';

tests 't/*.t';

WriteMakefile(
    INSTALLSCRIPT        => '/usr/lib/nagios/plugins/contrib',
    INSTALLSITESCRIPT    => '/usr/lib/nagios/plugins/contrib',
    MAN1PODS             => { 'check_rbl.pod' =>'blib/man1/check_rbl.1', },
    MAN3PODS             => { },
);

