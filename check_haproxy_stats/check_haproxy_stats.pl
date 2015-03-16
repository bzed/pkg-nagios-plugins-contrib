#!/usr/bin/env perl 
# vim: se et ts=4:

#
# Copyright (C) 2012, Giacomo Montagner <giacomo@entirelyunlike.net>
# 
# This program is free software; you can redistribute it and/or modify it 
# under the same terms as Perl 5.10.1. 
# For more details, see http://dev.perl.org/licenses/artistic.html
# 
# This program is distributed in the hope that it will be
# useful, but without any warranty; without even the implied
# warranty of merchantability or fitness for a particular purpose.
#

our $VERSION = "1.0.1";

# CHANGELOG:
#   1.0.0   - first release
#   1.0.1   - fixed empty message if all proxies are OK
#

use strict;
use warnings;
use 5.010.001;
use File::Basename qw/basename/;
use IO::Socket::UNIX;
use Getopt::Long;

sub usage {
    my $me = basename $0;
    print <<EOU;
NAME
    $me - check haproxy stats for errors, using UNIX socket interface

SYNOPSIS
    $me [OPTIONS]

DESCRIPTION
    Get haproxy statistics via UNIX socket and parse information searching for errors.

    OPTIONS
    -c, --critical
        Set critical threshold for sessions number (chacks current number of sessions
        against session limit, if enforced) to the specified percentage.
        If no session limit (slim) was specified for the given proxy, this option has
        no effect.

    -d, --dump
        Just dump haproxy stats and exit;

    -h, --help
        Print this message.

    -p, --proxy
        Check only named proxies, not every one. Use comma to separate proxies
        in list.

    -s, --sock, --socket
        Use named UNIX socket instead of default (/var/run/haproxy.sock)

    -w, --warning
        Set warning threshold for sessions number to the specified percentage (see -c)

CHECKS AND OUTPUT
    $me checks every proxy (or the named ones, if -p was given) 
    for status. It returns an error if any of the checked FRONTENDs is not OPEN, 
    any of the checked BACKENDs is not UP, or any of the checkes servers is not UP;
    $me reports any problem it found. 

EXAMPLES
    $me -s /var/spool/haproxy/sock
        Use /var/spool/haproxy/sock to communicate with haproxy.

    $me -p proxy1,proxy2 -w 60 -c 80
        Check only proxies named "proxy1" and "proxy2", and set sessions number 
        thresholds to 60% and 80%.

AUTHOR
    Written by Giacomo Montagner

REPORTING BUGS
    Please report any bug to bugs\@entirelyunlike.net

COPYRIGHT
    Copyright (C) 2012 Giacomo Montagner <giacomo\@entirelyunlike.net>. 
    $me is distributed under GPL and the Artistic License 2.0

SEE ALSO
    Check out online haproxy documentation at <http://haproxy.1wt.eu/>
    
EOU
}

my %check_statuses = (
    UNK     => "unknown",
    INI     => "initializing",
    SOCKERR => "socket error",
    L4OK    => "layer 4 check OK",
    L4CON   => "connection error",
    L4TMOUT => "layer 1-4 timeout",
    L6OK    => "layer 6 check OK",
    L6TOUT  => "layer 6 (SSL) timeout",
    L6RSP   => "layer 6 protocol error",
    L7OK    => "layer 7 check OK",
    L7OKC   => "layer 7 conditionally OK",
    L7TOUT  => "layer 7 (HTTP/SMTP) timeout",
    L7RSP   => "layer 7 protocol error",
    L7STS   => "layer 7 status error",
);

my @status_names = (qw/OK WARNING CRITICAL UNKNOWN/);

# Defaults
my $swarn = 80.0;
my $scrit = 90.0;
my $sock  = "/var/run/haproxy.sock";
my $dump;
my $proxy;
my $help;

# Read command line
Getopt::Long::Configure ("bundling");
GetOptions (
    "c|critical=i"    => \$scrit,
    "d|dump"          => \$dump,
    "h|help"          => \$help,
    "p|proxy=s"       => \$proxy,
    "s|sock|socket=s" => \$sock, 
    "w|warning=i"     => \$swarn,
);

# Want help?
if ($help) {
    usage;
    exit 3;
}

# Connect to haproxy socket and get stats
my $haproxy = new IO::Socket::UNIX (
    Peer => $sock,
    Type => SOCK_STREAM,
);
die "Unable to connect to haproxy socket: $@" unless $haproxy;
print $haproxy "show stat\n" or die "Print to socket failed: $!";

# Dump stats and exit if requested
if ($dump) {
    while (<$haproxy>) {
        print;
    }
    exit 0;
}

# Get labels from first output line and map them to their position in the line
my $labels = <$haproxy>;
chomp($labels);
$labels =~ s/^# // or die "Data format not supported."; 
my @labels = split /,/, $labels;
{ 
    no strict "refs";
    my $idx = 0;
    map { $$_ = $idx++ } @labels;
}

# Variables I will use from here on:
our $pxname;
our $svname;
our $status;

my @proxies = split ',', $proxy if $proxy;
my $exitcode = 0;
my $msg;
my $checked = 0;
while (<$haproxy>) {
    chomp;
    next if /^[[:space:]]*$/;
    my @data = split /,/, $_;
    if (@proxies) { next unless grep {$data[$pxname] eq $_} @proxies; };

    # Is session limit enforced? 
    our $slim;
    if ($data[$slim]) {
        # Check current session # against limit
        our $scur;
        my $sratio = $data[$scur]/$data[$slim];
        if ($sratio >= $scrit || $sratio >= $swarn) {
            $exitcode = $sratio >= $scrit ? 2 : 
                $exitcode < 2 ? 1 : $exitcode;
            $msg .= sprintf "%s:%s sessions: %.2f%%; ", $data[$pxname], $data[$svname], $sratio;
        }
    }

    # Check of BACKENDS
    if ($data[$svname] eq 'BACKEND') {
        if ($data[$status] ne 'UP') {
            $msg .= sprintf "BACKEND: %s is %s; ", $data[$pxname], $data[$status];
            $exitcode = 2;
        }
    # Check of FRONTENDS
    } elsif ($data[$svname] eq 'FRONTEND') {
        if ($data[$status] ne 'OPEN') {
            $msg .= sprintf "FRONTEND: %s is %s; ", $data[$pxname], $data[$status];
            $exitcode = 2;
        }
    # Check of servers
    } else {
        if ($data[$status] ne 'UP') {
            next if $data[$status] eq 'no check';   # Ignore server if no check is configured to be run
            $exitcode = 2;
            our $check_status;
            $msg .= sprintf "server: %s:%s is %s", $data[$pxname], $data[$svname], $data[$status];
            $msg .= sprintf " (check status: %s)", $check_statuses{$data[$check_status]} if $check_statuses{$data[$check_status]};
            $msg .= "; ";
        }
    }
    ++$checked;
}

unless ($msg) {
    $msg = @proxies ? sprintf("checked proxies: %s", join ', ', sort @proxies) : "checked $checked proxies.";
}
say "Check haproxy $status_names[$exitcode] - $msg";
exit $exitcode;

