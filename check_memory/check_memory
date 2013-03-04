#!/usr/bin/perl
#
# check_memory  -  Check free(1) data against given tresholds
#
# Copyright (C) 2007 Thomas Guyot-Sionnest <tguyot@gmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#


use strict;
use warnings;
use vars qw($PROGNAME $VERSION $FREECMD $UNIT);
use Nagios::Plugin;

$PROGNAME = "check_memory";
$VERSION = '1.0';
$FREECMD = '/usr/bin/free';
$UNIT = 'M';

my $np = Nagios::Plugin->new(
  usage => "Usage: %s [ -w <warning_threshold> ] [ -c <critical_threshold> ]\n"
    . '   [ -u <unit> ]',
  version => $VERSION,
  plugin  => $PROGNAME,
  shortname => uc($PROGNAME),
  blurb => 'Check free(1) data against given tresholds',
  timeout => 30,
);

$np->add_arg(
  spec => 'warning|w=s',
  help => "-w, --warning=THRESHOLD\n"
    . "   Warning threshold (in *bytes*) for free memory. See\n"
    . "   http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT\n"
    . "   for the threshold format. Alternatively this can be defined as a percentage\n"
    . '   of minimum free memory (warning and critical must be in the same format).',
  required => 0,
);

$np->add_arg(
  spec => 'critical|c=s',
  help => "-c, --critical=THRESHOLD\n"
    . "   Critical threshold (in *bytes*) for free memory. See\n"
    . "   http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT\n"
    . "   for the threshold format. Alternatively this can be defined as a percentage\n"
    . '   of minimum free memory (warning and critical must be in the same format).',
  required => 0,
);

$np->add_arg(
  spec => 'unit|u=s',
  help => "-u, --unit=UNIT\n"
    . "   Unit to use for human-redeable output. Can be 'b', 'K' 'M' or 'G' for\n"
    . "   bytes, KiB, MiB or GiB respectively (default: '$UNIT').",
  default => $UNIT,
  required => 0,
);

$np->getopts;

# Assign, then check args

my $multiple;
my $unit = $np->opts->unit;
if ($unit eq 'M') {
  $multiple = 1024 * 1024;
} elsif ( $unit eq 'K') {
  $multiple = 1024;
} elsif ( $unit eq 'b') {
  $multiple = 1;
} elsif ( $unit eq 'G') {
  $multiple = 1024 * 1024 * 1024;
} else {
  $np->nagios_exit('UNKNOWN', "Unit must be one of 'b', 'K', 'M' or 'G', case-sensitive.");
}
my $verbose = $np->opts->verbose;

# Would better fit later but doing it here validates thresholds
my $warning = $np->opts->warning;
my $critical = $np->opts->critical;
$np->set_thresholds(
    warning => ((defined($warning) && $warning !~ /^\d+%$/) ? $warning : undef),
    critical => ((defined($critical) && $critical !~ /^\d+%$/) ? $critical : undef),
);

# Better safe than sorry
alarm $np->opts->timeout;

# We always get bytes, then calculate units ourselves (Who knows... what if $FREECMD is on an offline device)
warn("Running: '$FREECMD -b'\n") if ($verbose);
open(RESULT, "$FREECMD -b |")
  or $np->nagios_exit('CRITICAL', "Could not run $FREECMD");

warn("Output from $FREECMD:\n") if ($verbose > 1);
my ($used, $free);
while (<RESULT>) {
  warn("  $_") if ($verbose > 1);
  next unless (m#^\-/\+\ buffers/cache:\s*(\d+)\s+(\d+)#);
  $used = $1;
  $free = $2;
}

close(RESULT);
alarm(0);

$np->nagios_exit('CRITICAL', "Unable to interpret $FREECMD output") if (!defined($free));

my $total = $used + $free;
if (defined($warning) && $warning =~ /^\d+%$/) {
  if ($warning) {
    $warning =~ s/%//;
    $warning = $total / 100 * $warning;
    $warning .= ':';
  }
  warn("Calculated threshold (from percentage): warn=>$warning\n") if ($verbose);
}

if (defined($critical) && $critical =~ /^\d+%$/) {
  if ($critical) {
    $critical =~ s/%//;
    $critical = $total / 100 * $critical;
    $critical .= ':';
  }
  warn("Calculated threshold (from percentage): crit=>$critical\n") if ($verbose);
}

$np->set_thresholds(
  warning => $warning,
  critical => $critical,
);

$np->add_perfdata(
  label => "free",
  value => $free,
  uom => 'b',
  threshold => $np->threshold,
);

my $freeprint = int($free/$multiple);

$np->nagios_exit($np->check_threshold($free), "$freeprint$unit free");

