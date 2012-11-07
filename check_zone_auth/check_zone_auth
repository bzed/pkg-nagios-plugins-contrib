#!/usr/bin/perl

# $Id: check_zone_auth,v 1.13 2010/07/23 15:54:08 wessels Exp $
#
# check_zone_auth
#
# nagios plugin to check that all authoritative nameservers for a zone
# have the same NS RRset and the same serial number.
#
# Can also check that the NS RRset is equal to specific nameservers
# passed on the command line.


# Copyright (c) 2008, The Measurement Factory, Inc. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 
# Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# Neither the name of The Measurement Factory nor the names of its
# contributors may be used to endorse or promote products derived
# from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# USAGE
#
# define command {
#   command_name    check-zone-auth
#   command_line    /usr/local/libexec/nagios-local/check_zone_auth -Z $HOSTADDRESS$
# }
# 
# define service {
#   name		   dns-auth-service
#   check_command	   check-zone-auth
#   ...
# }
# 
# define host {
#   use dns-zone
#   host_name zone.example.com
#   alias ZONE example.com
# }
# 
# define service {
#   use dns-auth-service
#   host_name zone.example.com
# }

# CONTRIBUTORS:
#
# Matt Christian

use warnings;
use strict;

use Getopt::Std;
use Net::DNS::Resolver;
use Net::DNS::Resolver::Recurse;
use Time::HiRes qw ( gettimeofday tv_interval);
use List::Util qw ( shuffle );

use vars qw( %opts @refs $zone $expected_ns_rrset $data $start $stop );
getopts('Z:N:d', \%opts);
usage() unless $opts{Z};
usage() if $opts{h};
$zone = $opts{Z};
$zone =~ s/^zone\.//;
$expected_ns_rrset = $opts{N} ? join(',', sort split(',', lc($opts{N}))) : undef;

@refs = qw (
a.root-servers.net
b.root-servers.net
c.root-servers.net
d.root-servers.net
e.root-servers.net
f.root-servers.net
g.root-servers.net
h.root-servers.net
i.root-servers.net
j.root-servers.net
k.root-servers.net
l.root-servers.net
m.root-servers.net
);

$start = [gettimeofday()];
do_recursion();
do_queries();
$stop = [gettimeofday()];
do_analyze();

sub do_recursion {
	my $done = 0;
	my $res = Net::DNS::Resolver->new;
	do {
		print STDERR "\nRECURSE\n" if $opts{d};
		my $pkt;
		foreach my $ns (shuffle @refs) {
			print STDERR "sending query for $zone SOA to $ns\n" if $opts{d};
			$res->nameserver($ns);
			$res->udp_timeout(5);
			$pkt = $res->send($zone, 'SOA');
			last if $pkt;
		}
		critical("No response to seed query") unless $pkt;
		critical($pkt->header->rcode . " from " . $pkt->answerfrom)
			unless ($pkt->header->rcode eq 'NOERROR');
		add_nslist_to_data($pkt);
		@refs = ();
		foreach my $rr ($pkt->authority) {
			next unless ($rr->type eq 'NS');
			print STDERR $rr->string, "\n" if $opts{d};
			push (@refs, $rr->nsdname);
			next unless names_equal($rr->name, $zone);
			$done = 1;
		}
	} while (! $done);
}


sub do_queries {
#
#	Net::DNS::Resolver::Recurse has some less-than-desirable
#	properties.  For one it seems to generate many more queries
#	than necessary.  Also it seems to have a tough time when
# 	IPv6 is involved.  For now this is disabled in favor
#	of a custom, simple recursor
#
#	my $recres = Net::DNS::Resolver::Recurse->new;
#	$recres->recursion_callback(sub {
#		my $p = shift;
#		#
#		# This debugging below is commented out because it
#		# generates a 'Variable "%opts" may be unavailable'
#		# warning when ePN (embedded perl nagios) is in use.
#		#
#		#print STDERR $p->string if $opts{d};
#		add_nslist_to_data($p);
#	});
#	my $seed = $recres->query_dorecursion($zone, 'SOA');
#	critical("No response to seed query") unless $seed;
#	$recres = undef;
#
#	critical($seed->header->rcode . " from " . $seed->answerfrom)
#		unless ($seed->header->rcode eq 'NOERROR');
#	print STDERR $seed->string if $opts{d};
#	add_nslist_to_data($seed);
	
	my $n;
	do {
		$n = 0;
		foreach my $ns (keys %$data) {
			next if $data->{$ns}->{done};
			print STDERR "\nQUERY $ns\n" if $opts{d};

			my $pkt = send_query($zone, 'SOA', $ns);
			add_nslist_to_data($pkt);
			$data->{$ns}->{queries}->{SOA} = $pkt;

			if ($pkt && $pkt->header->nscount == 0) {
				my $ns_pkt = send_query($zone, 'NS', $ns);
				add_nslist_to_data($ns_pkt);
				$data->{$ns}->{queries}->{NS} = $ns_pkt;
			}

			print STDERR "done with $ns\n" if $opts{d};
			$data->{$ns}->{done} = 1;
			$n++;
		}
	} while ($n);
}

sub do_analyze {
	my $maxserial = 0;
	my $nscount = 0;
	foreach my $ns (keys %$data) {
		print STDERR "\nANALYZE $ns\n" if $opts{d};
		my $soa_pkt = $data->{$ns}->{queries}->{SOA};
		critical("No response from $ns") unless $soa_pkt;
		print STDERR $soa_pkt->string if $opts{d};
		critical($soa_pkt->header->rcode . " from $ns")
			unless ($soa_pkt->header->rcode eq 'NOERROR');
		critical("$ns is lame") unless $soa_pkt->header->ancount;
		my $serial = soa_serial($soa_pkt);
		$maxserial = $serial if ($serial > $maxserial);
		$nscount++;
	}
	warning("No nameservers found.  Is '$zone' a zone?") if ($nscount < 1);
	warning("Only one auth NS") if ($nscount < 2);
	if ($expected_ns_rrset) {
		my $got_ns_rrset = join(',', sort keys %$data);
		critical("Unexpected NS RRset: $got_ns_rrset")
			unless $expected_ns_rrset eq $got_ns_rrset;
	}
	foreach my $ns (keys %$data) {
		my $soa_pkt = $data->{$ns}->{queries}->{SOA};
		my $ns_pkt = $data->{$ns}->{queries}->{NS};

		# see if this nameserver lists all nameservers
		#
		my %all_ns;
		foreach my $data_ns (keys %$data) { $all_ns{$data_ns} = 1; }
		foreach my $soa_ns (get_nslist($soa_pkt)) { delete $all_ns{$soa_ns}; }
		foreach my $ns_ns (get_nslist($ns_pkt)) { delete $all_ns{$ns_ns}; }
		if (keys %all_ns) {
			warning("$ns does not include " .
				join(',', keys %all_ns) .
				" in NS RRset");
		}

		warning("$ns claims is it not authoritative") unless $soa_pkt->header->aa;

		my $serial = soa_serial($soa_pkt);
		warning("$ns serial ($serial) is less than the maximum ($maxserial)") if ($serial < $maxserial);
	}
	success("$nscount nameservers, serial $maxserial");
}

sub add_nslist_to_data {
	my $pkt = shift;
	foreach my $ns (get_nslist($pkt)) {
		print STDERR "adding NS $ns\n" if $opts{d};
		$data->{$ns}->{done} |= 0;
	}
}

sub soa_serial {
	my $pkt = shift;
	foreach my $rr ($pkt->answer) {
		next unless ($rr->type eq 'SOA');
		next unless ($rr->name eq $zone);
		return $rr->serial;
	}
	return 0;
}

sub success {
	output('OK', shift);
	exit(0);
}

sub warning {
	output('WARNING', shift);
	exit(1);
}

sub critical {
	output('CRITICAL', shift);
	exit(2);
}

sub output {
	my $state = shift;
	my $msg = shift;
	$stop = [gettimeofday()] unless $stop;
	my $latency = tv_interval($start, $stop);
	printf "ZONE %s: %s; (%.2fs) |time=%.6fs;;;0.000000\n",
		$state,
		$msg,
		$latency,
		$latency;
}

sub usage {
	print STDERR "usage: $0 -Z zone [-N ns1,ns2,ns3]\n";
	print STDERR "\t-Z specifies the zone to test\n";
	print STDERR "\t-N optionally specifies the expected NS RRset\n";
	exit 3;
}

sub send_query {
	my $qname = shift;
	my $qtype = shift;
	my $server = shift;
	my $res = Net::DNS::Resolver->new;
	$res->nameserver($server) if $server;
	return $res->send($qname, $qtype);
}

sub get_nslist {
	my $pkt = shift;
	return () unless $pkt;
	my @nslist = ();
	foreach my $rr ($pkt->authority) {
		next unless ($rr->type eq 'NS');
		next unless names_equal($rr->name, $zone);
		push(@nslist, lc($rr->nsdname));
	}
	return @nslist if @nslist;
	#
	# look for NS records in answer section too
	#
	foreach my $rr ($pkt->answer) {
		next unless ($rr->type eq 'NS');
		next unless names_equal($rr->name, $zone);
		push(@nslist, lc($rr->nsdname));
	}
	return @nslist;
}

sub names_equal {
	my $a = shift;
	my $b = shift;
	$a =~ s/\.$//;
	$b =~ s/\.$//;
	lc($a) eq lc($b);
}
