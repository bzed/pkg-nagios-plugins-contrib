#!/usr/bin/perl -w
#
# Nagios plugin to monitor different virtualization solutions using libvirt, e.g. Xen, KVM, Virtual Box.
#
# License: GPL
# Copyright (c) 2011 op5 AB
# Author: Kostyantyn Hushchyn <op5-users@lists.op5.com>
#
# For direct contact with any of the op5 developers send a mail to
# op5-users@lists.op5.com
# Discussions are directed to the mailing list op5-users@op5.com,
# see http://lists.op5.com/mailman/listinfo/op5-users
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use warnings;
use vars qw($PROGNAME $VERSION $output $result);
use Nagios::Plugin;
use File::Basename;
use Sys::Virt;
use XML::Simple;

$PROGNAME = basename($0);
$VERSION = '0.1.0';
my $spooldir="/opt/monitor/var/check_libvirt";

if (!-d $spooldir)
{
	mkdir($spooldir);
}

my $np = Nagios::Plugin->new(
  usage => "Usage: %s -H <hosturl> [ -N <vmname> ]\n"
    . "    [-u <user> -p <pass>]\n"
    . "    -l <command> [ -s <subcommand> ]\n"
    . "    [ -t <timeout> ] [ -w <warn_range> ] [ -c <crit_range> ]\n"
    . '    [ -V ] [ -h ]',
  version => $VERSION,
  plugin  => $PROGNAME,
  shortname => uc($PROGNAME),
  blurb => 'Plugin for monitoring virtualization solutions via libvirt: KVM/QEMU, VirtualBox, Xen, Microsoft Hyper-V, etc',
  extra   => "Supported commands :\n"
    . "    Host specific :\n"
    . "        * list - shows VM's list and their statuses\n"
    . "        * pool - shows pool info\n"
    . "            + (name) - query particular pool with name (name)\n"
    . "            ^ list pools and their statuses\n"
    . "        * volume - shows volume info\n"
    . "            + (name) - query particular volume in pool with full name (name)\n"
    . "            ^ list volumes and their statuses\n"
    . "        * running - queries VM state\n"
    . "            + (name) - query particular VM state by it's name (name)\n"
    . "    VM specific :\n"
    . "        * cpu - shows cpu usage info\n"
    . "        * mem - shows mem usage info\n"
    . "        * net - shows net info: TX bytes, TX packets, TX errors, TX drops, RX bytes, RX packets, RX errors, RX drops\n"
    . "        * io - shows io info: Read bytes, Read requests, Write bytes, Write requests, Errors\n"
    . "\n\nCopyright (c) 2011 op5",
  timeout => 30,
); 

$np->add_arg(
  spec => 'host|H=s',
  help => "-H, --host=<hosturl>\n"
    . "   libvirt remote urls. More information can be found here http://libvirt.org/remote.html#Remote_URI_reference\n"
    . ' and here http://libvirt.org/drivers.html .',
  required => 0,
);

$np->add_arg(
  spec => 'name|N=s',
  help => "-N, --name=<vmname>\n"
    . '   Virtual machine name.',
  required => 0,
);

$np->add_arg(
  spec => 'username|u=s',
  help => "-u, --username=<username>\n"
    . '   Username to connect to Hypervisor with.',
  required => 0,
);

$np->add_arg(
  spec => 'password|p=s',
  help => "-p, --password=<password>\n"
    . '   Password to use with the username.',
  required => 0,
);

$np->add_arg(
  spec => 'warning|w=s',
  help => "-w, --warning=THRESHOLD\n"
    . "   Warning threshold. See\n"
    . "   http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT\n"
    . '   for the threshold format.',
  required => 0,
);

$np->add_arg(
  spec => 'critical|c=s',
  help => "-c, --critical=THRESHOLD\n"
    . "   Critical threshold. See\n"
    . "   http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT\n"
    . '   for the threshold format.',
  required => 0,
);

$np->add_arg(
  spec => 'command|l=s',
  help => "-l, --command=COMMAND\n"
    . '   Specify command type (VM Server: LIST, POOL, VOLUME; VM Machine: CPU, MEM, NET, IO)',
  required => 1,
);

$np->add_arg(
  spec => 'subcommand|s=s',
  help => "-s, --subcommand=SUBCOMMAND\n"
    . '   Specify subcommand',
  required => 0,
);

$np->getopts;

my $host = $np->opts->host;
my $vmname = $np->opts->name;
my $username = $np->opts->username;
my $password = $np->opts->password;
my $warning = $np->opts->warning;
my $critical = $np->opts->critical;
my $command = $np->opts->command;
my $subcommand = $np->opts->subcommand;
my %runstates = (Sys::Virt::Domain::STATE_NOSTATE => "running", Sys::Virt::Domain::STATE_RUNNING => "running", Sys::Virt::Domain::STATE_BLOCKED => "running", Sys::Virt::Domain::STATE_PAUSED => "running", Sys::Virt::Domain::STATE_SHUTDOWN => "going down", Sys::Virt::Domain::STATE_SHUTOFF => "down", Sys::Virt::Domain::STATE_CRASHED => "crashed");
my %poolstates = (Sys::Virt::StoragePool::STATE_INACTIVE => "inactive", Sys::Virt::StoragePool::STATE_BUILDING => "building", Sys::Virt::StoragePool::STATE_RUNNING => "running", Sys::Virt::StoragePool::STATE_DEGRADED => "degraded");
my %voltypes = (Sys::Virt::StorageVol::TYPE_FILE => "image", Sys::Virt::StorageVol::TYPE_BLOCK => "dev");
$output = "Unknown ERROR!";
$result = CRITICAL;

if (defined($critical))
{
	$critical = undef if ($critical eq '');
}

if (defined($warning))
{
	$warning = undef if ($warning eq '');
}

$np->set_thresholds(critical => $critical, warning => $warning);

eval
{
	my $con = Sys::Virt->new(address => $host, readonly => 1, auth => (defined($username) && defined($password)),
		credlist => [
			Sys::Virt::CRED_AUTHNAME,
			Sys::Virt::CRED_PASSPHRASE,
		],
		callback =>
		sub {
			my $creds = shift;

			foreach my $cred (@{$creds}) {
				if ($cred->{type} == Sys::Virt::CRED_AUTHNAME) {
					$cred->{result} = $username;
				}
				if ($cred->{type} == Sys::Virt::CRED_PASSPHRASE) {
					$cred->{result} = $password;
				}
			}
			return 0;
		}
	);

	if (!defined($vmname))
	{
		if (uc($command) eq "LIST")
		{
			my @updoms = $con->list_domains();
			my $up = @updoms;
			my $cnt = $con->num_of_defined_domains();
			my @downdoms = $con->list_defined_domain_names($cnt);
			$output = "";

			while (my $dom = shift(@downdoms))
			{
				$output .= $dom . "(" . $runstates{Sys::Virt::Domain::STATE_SHUTOFF} . "), ";
			}

			$cnt += $up;
			while (my $dom = shift(@updoms))
			{
				my $domstate = $dom->get_info()->{"state"};
				if (exists($runstates{$domstate}))
				{
				 	if ($runstates{$domstate} ne "running")
					{
						$up--;
						$output = $dom->get_name() . "(" . $runstates{$domstate} . "), " . $output;
					}
					else
					{
						$output .= $dom->get_name() . "(running), ";
					}
				}
				else
				{
					$up--;
					$output = $dom->get_name() . "(unknown), " . $output;
				}
			}

			chop($output);
			chop($output);
			$output = $up . "/" . $cnt . " VMs up: " . $output;
			$np->add_perfdata(label => "vmcount", value => $up, uom => 'units', threshold => $np->threshold);
			$result = $np->check_threshold(check => $up);
		}
		elsif (uc($command) eq "POOL")
		{
			if (!defined($subcommand))
			{
				my @pools = $con->list_storage_pools();
				push(@pools, $con->list_defined_storage_pools());

				$output = "";
				while (my $pool = shift(@pools))
				{
					my $poolinfo = $pool->get_info();
					if (exists($poolstates{$poolinfo->{"state"}}))
					{
						my $value1 = $poolinfo->{"allocation"};
						my $value2 = simplify_number($value1 / $poolinfo->{"capacity"} * 100);
						$value1 = simplify_number($value1 / 1024 / 1024);
						$output .= $pool->get_name() . "(" . $poolstates{$poolinfo->{"state"}} . ")=" . $value1 . "MB(" . $value2 . "%), ";
					}
					else
					{
						$output .= $pool->get_name() . "(unknown)=unavialable, ";
					}
				}
				chop($output);
				chop($output);
				$result = OK;
			}
			else
			{
				my $pool = $con->get_storage_pool_by_name($subcommand);
				my $poolinfo = $pool->get_info();
				my $value1 = $poolinfo->{"allocation"};
				my $value2 = simplify_number($value1 / $poolinfo->{"capacity"} * 100);
				$value1 = simplify_number($value1 / 1024 / 1024);
				$output = $pool->get_name() . "(" . $poolstates{$poolinfo->{"state"}} . ")=" . $value1 . "MB(" . $value2 . "%)";
				$np->add_perfdata(label => $pool->get_name(), value => $value1, uom => 'MB', threshold => $np->threshold);
				$result = $np->check_threshold(check => $value1);
			}
		}
		elsif (uc($command) eq "VOLUME")
		{
			if (!defined($subcommand))
			{
				my @pools = $con->list_storage_pools();
				push(@pools, $con->list_defined_storage_pools());

				$output = "";
				while (my $pool = shift(@pools))
				{
					my @volumes = $pool->list_volumes();
					while (my $vol = shift(@volumes))
					{
						my $volinfo = $vol->get_info();
						my $value1 = simplify_number($volinfo->{"allocation"} / 1024 / 1024);
						my $value2 = simplify_number($volinfo->{"capacity"} / 1024 / 1024);
						$output .= $vol->get_name() . "(" . $voltypes{$volinfo->{"type"}} . ")=" . $value1 . "MB/" . $value2 . "MB, ";
					}
				}
				chop($output);
				chop($output);
				$result = OK;
			}
			else
			{
				my ($poolname, $volname) = split(/\//, $subcommand, 2);
				die "Volume name is not defined. Please provide argument in form 'pool/volume'.\n" if (!defined($volname));
				my $pool = $con->get_storage_pool_by_name($poolname);
				my $vol = $pool->get_volume_by_name($volname);
				my $volinfo = $vol->get_info();
				my $value1 = simplify_number($volinfo->{"allocation"} / 1024 / 1024);
				my $value2 = simplify_number($volinfo->{"capacity"} / 1024 / 1024);
				$output = $vol->get_name() . "(" . $voltypes{$volinfo->{"type"}} . ")=" . $value1 . "MB/" . $value2 . "MB";
				$np->add_perfdata(label => $vol->get_name(), value => $value1, uom => 'MB', threshold => $np->threshold);
				$result = $np->check_threshold(check => $value1);
			}
		}
		elsif (uc($command) eq "RUNNING")
		{
			die "VM name is not defined. Please provide argument in -s command.\n" if (!defined($subcommand));
			my $dom = $con->get_domain_by_name($subcommand);
			my $domstate = $dom->get_info()->{"state"};
			if (exists($runstates{$domstate}))
			{
				$result = ($runstates{$domstate} eq "running") ? OK : CRITICAL;
				$output = $dom->get_name() . " is in " . $runstates{$domstate} . " state\n";
			}
			else
			{
				$result = CRITICAL;
				$output = $dom->get_name() . " is in unknown state\n";
			}
		}
		else
		{
			$result = CRITICAL;
			$output = "unknown command '$command' for Host\n";
		}
	}
	else
	{
		my $dom = $con->get_domain_by_name($vmname);
		my $dominfo = $dom->get_info();
		my $domstate = $dominfo->{"state"};
		die "VM '$vmname' is " . $runstates{$domstate} . ".\n" if (!exists($runstates{$domstate}) || $runstates{$domstate} ne "running");

		if (uc($command) eq "CPU")
		{
			my $vars;
			my $range = time();
			($result, $vars) = process_domstat($np, $spooldir . "/" . $vmname . "_cpu", $range, {cpu_time => $dominfo->{"cpuTime"}});
			die {msg => ("Skipped, first time of data collection.\n"), code => OK} if (ref($vars) ne "HASH");
			# cpuTime is in nano seconds
			my $cpuusage = simplify_number($vars->{"cpu_time"} / 1000000000 * 100);
			$output = "CPU usage = " . $cpuusage . " %\n";
			$np->add_perfdata(label => "cpu", value => $cpuusage, threshold => $np->threshold);
			$result = $np->check_threshold(check => $cpuusage);
		}
		elsif (uc($command) eq "MEM")
		{
			my $value = simplify_number($dominfo->{"memory"} / 1024);
			$output = "MEM usage = " . $value . " MB\n";
			$np->add_perfdata(label => "memory", value => $value, threshold => $np->threshold);
			$result = $np->check_threshold(check => $value);
		}
		elsif (uc($command) eq "NET")
		{
			my $vmdesc = XML::Simple->new()->XMLin($dom->get_xml_description());
			my $ifaces = $vmdesc->{"devices"}->{"interface"};
			$ifaces = [ $ifaces ] if (ref($ifaces) ne "ARRAY");
			my $tx_bytes = 0;
			my $tx_pkts = 0;
			my $tx_drop = 0;
			my $tx_errs = 0;
			my $rx_bytes = 0;
			my $rx_pkts = 0;
			my $rx_drop = 0;
			my $rx_errs = 0;

			while (my $iface = shift(@{$ifaces}))
			{
				my $ifacedev = $iface->{"target"}->{"dev"};
				my $devname = $ifacedev;
				die {msg => ("Can not access network interfaces. Unsure that VM is running as paravirt guest or PV drivers are installed.\n"), code => CRITICAL} if (!defined($devname));
				$devname =~ s/\./_/g;

				my $vars;
				my $range = time();
				($result, $vars) = process_domstat($np, $spooldir . "/" . $vmname . "_" . $devname . "_net", $range, $dom->interface_stats($ifacedev));
				next if (ref($vars) ne "HASH");

				$output = "";
				$tx_bytes += $vars->{"tx_bytes"};
				$tx_pkts += $vars->{"tx_packets"};
				$tx_drop += $vars->{"tx_drop"};
				$tx_errs += $vars->{"tx_errs"};
				$rx_bytes += $vars->{"rx_bytes"};
				$rx_pkts += $vars->{"rx_packets"};
				$rx_drop += $vars->{"rx_drop"};
				$rx_errs += $vars->{"rx_errs"};
			}
			die {msg => ("Skipped, first time of data collection.\n"), code => OK} if ($output);

			$np->add_perfdata(label => "tx_bytes", value => $tx_bytes, threshold => $np->threshold);
			$np->add_perfdata(label => "tx_packets", value => $tx_pkts, threshold => $np->threshold);
			$np->add_perfdata(label => "tx_drop", value => $tx_drop, threshold => $np->threshold);
			$np->add_perfdata(label => "tx_errs", value => $tx_errs, threshold => $np->threshold);
			$np->add_perfdata(label => "rx_bytes", value => $rx_bytes, threshold => $np->threshold);
			$np->add_perfdata(label => "rx_packets", value => $rx_pkts, threshold => $np->threshold);
			$np->add_perfdata(label => "rx_drop", value => $rx_drop, threshold => $np->threshold);
			$np->add_perfdata(label => "rx_errs", value => $rx_errs, threshold => $np->threshold);

			$output = "NET TX bytes = " . $tx_bytes . ", TX pkts = " . $tx_pkts . ", TX drops = " . $tx_drop . ", TX errors = " . $tx_errs . ", RX bytes = " . $rx_bytes . ", RX pkts = " . $rx_pkts . ", RX drops = " . $rx_drop . ", RX errors = " . $rx_errs;
		}
		elsif (uc($command) eq "IO")
		{
			my $vmdesc = XML::Simple->new()->XMLin($dom->get_xml_description());
			my $blks = $vmdesc->{"devices"}->{"disk"};
			$blks = [ $blks ] if (ref($blks) ne "ARRAY");
			my $rd_bytes = 0;
			my $rd_req = 0;
			my $wr_bytes = 0;
			my $wr_req = 0;
			my $errs = 0;

			while (my $blk = shift(@{$blks}))
			{
				my $blkdev = $blk->{"target"}->{"dev"};
				my $devname = $blkdev;
				die {msg => ("Can not access disk device. Unsure that VM is running as paravirt guest or PV drivers are installed.\n"), code => CRITICAL} if (!defined($devname));
				$devname =~ s/\./_/g;

				my $vars;
				my $range = time();
				($result, $vars) = process_domstat($np, $spooldir . "/" . $vmname . "_" . $devname . "_io", $range, $dom->block_stats($blkdev));
				next if (ref($vars) ne "HASH");

				$output = "";
				$rd_bytes += $vars->{"rd_bytes"};
				$rd_req += $vars->{"rd_req"};
				$wr_bytes += $vars->{"wr_bytes"};
				$wr_req += $vars->{"wr_req"};
				$errs += $vars->{"errs"};
			}
			die {msg => ("Skipped, first time of data collection.\n"), code => OK} if ($output);

			$np->add_perfdata(label => "rd_bytes", value => $rd_bytes, threshold => $np->threshold);
			$np->add_perfdata(label => "rd_req", value => $rd_req, threshold => $np->threshold);
			$np->add_perfdata(label => "wr_bytes", value => $wr_bytes, threshold => $np->threshold);
			$np->add_perfdata(label => "wr_req", value => $wr_req, threshold => $np->threshold);
			$np->add_perfdata(label => "errors", value => $errs, threshold => $np->threshold);

			$output = "IO read bytes = " . $rd_bytes . ", read req = " . $rd_req . ", write bytes = " . $wr_bytes . ", write req = " . $wr_req . ", errors = " . $errs;
		}
		else
		{
			$result = CRITICAL;
			$output = "unknown command '$command' for VM '$vmname'\n";
		}
	}
};

if ($@)
{
	if (uc(ref($@)) eq "HASH")
	{
		$output = $@->{msg};
		$result = $@->{code};
	}
	else
	{
		$output = $@ . "";
		$result = CRITICAL;
	}
	$output =~ s/libvirt error code: [0-9]+, message: //;
	$output =~ s/\r\n//;
}

$np->nagios_exit($result, $output);

sub simplify_number
{
	my ($number, $cnt) = @_;
	$cnt = 2 if (!defined($cnt));
	return sprintf("%.${cnt}f", "$number");
}

sub process_domstat
{
	my ($np, $datapath, $range, $new_vars) = @_;
	my $result = OK;
	my $old_range = 0;

	# Read old info
	my %old_vars;
	if (open(OLDSPOOL, "<" . $datapath))
	{
		$old_range = <OLDSPOOL>;
		while (my $line = <OLDSPOOL>)
		{
			my @vals = split(/\s/, $line);
			$old_vars{$vals[0]} = $vals[1];
		}
		close(OLDSPOOL);
	}

	# Save new info
	open(SPOOL, ">" . $datapath) or die {msg => ("Can not create file " . $datapath . ". Please check permissions, disk space and mount point availability.\n"), code => CRITICAL};
	print(SPOOL $range . "\n");
	while (my ($key, $value) = each %{$new_vars})
	{
		print(SPOOL $key . " " . $value . "\n")
	}
	close(SPOOL);

	return OK if (!scalar keys %old_vars);

	# Compute usage statistic
	my %vars;
	$range = $range - $old_range;
	foreach my $key (keys %{$new_vars})
	{
		if (exists($old_vars{$key}))
		{
			my $value = simplify_number(($new_vars->{$key} - $old_vars{$key}) / $range);
			$vars{$key} = $value;
			return OK if ($value < 0);
		}
		else
		{
			$result = CRITICAL;
		}
	}

	die {msg => ("Can not retreive any value.\n"), code => CRITICAL} if (!scalar keys %vars);

	return ($result, \%vars);
}
