package HP::Proliant::Component::DiskSubsystem::Da::CLI;
our @ISA = qw(HP::Proliant::Component::DiskSubsystem::Da);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    controllers => [],
    accelerators => [],
    enclosures => [],
    physical_drives => [],
    logical_drives => [],
    spare_drives => [],
    blacklisted => 0,
  };
  bless $self, $class;
  return $self;
}

sub init {
  my $self = shift;
  my $hpacucli = $self->{rawdata};
  my $slot = 0;
  my $type = "unkn";
  my @lines = ();
  my $thistype = 0;
  my $tmpcntl = {};
  my $tmpaccel = {};
  my $tmpld = {};
  my $tmppd = {};
  my $tmpencl = {};
  my $cntlindex = 0;
  my $enclosureindex = 0;
  my $ldriveindex = 0;
  my $pdriveindex = 0;
  my $incontroller = 0;
  foreach (split(/\n/, $hpacucli)) {
    next unless /^status/;
    next if /^status\s*$/;
    s/^status\s*//;
    if (/(MSA[\s\w]+)\s+in\s+(\w+)/) { 
      $incontroller = 1;
      $slot = $2;
      $cntlindex++;
      $tmpcntl->{$slot}->{cpqDaCntlrIndex} = $cntlindex;
      $tmpcntl->{$slot}->{cpqDaCntlrModel} = $1;
      $tmpcntl->{$slot}->{cpqDaCntlrSlot} = $slot;
    } elsif (/([\s\w]+) in Slot\s+(\d+)/) {
      $incontroller = 1;
      $slot = $2;
      $cntlindex++;
      $tmpcntl->{$slot}->{cpqDaCntlrIndex} = $cntlindex;
      $tmpcntl->{$slot}->{cpqDaCntlrModel} = $1;
      $tmpcntl->{$slot}->{cpqDaCntlrSlot} = $slot;
    } elsif (/Controller Status: (\w+)/) {
      $tmpcntl->{$slot}->{cpqDaCntlrBoardCondition} = lc $1;
      $tmpcntl->{$slot}->{cpqDaCntlrCondition} = lc $1;
    } elsif (/Cache Status: ([\w\s]+?)\s*$/) {
      # Cache Status: OK
      # Cache Status: Not Configured
      # Cache Status: Temporarily Disabled
      $tmpaccel->{$slot}->{cpqDaAccelCntlrIndex} = $cntlindex;
      $tmpaccel->{$slot}->{cpqDaAccelSlot} = $slot;
      #condition: other,ok,degraded,failed
      #status: other,invalid,enabled,tmpDisabled,permDisabled
      $tmpaccel->{$slot}->{cpqDaAccelCondition} = lc $1; 
      if ($tmpaccel->{$slot}->{cpqDaAccelCondition} eq 'ok') {
        $tmpaccel->{$slot}->{cpqDaAccelStatus} = 'enabled';
      } elsif ($tmpaccel->{$slot}->{cpqDaAccelCondition} eq 'not configured') {
        $tmpaccel->{$slot}->{cpqDaAccelCondition} = 'ok';
        $tmpaccel->{$slot}->{cpqDaAccelStatus} = 'enabled';
      } elsif ($tmpaccel->{$slot}->{cpqDaAccelCondition} eq 'temporarily disabled') {
        $tmpaccel->{$slot}->{cpqDaAccelCondition} = 'ok';
        $tmpaccel->{$slot}->{cpqDaAccelStatus} = 'tmpDisabled';
      } elsif ($tmpaccel->{$slot}->{cpqDaAccelCondition} eq 'permanently disabled') {
        $tmpaccel->{$slot}->{cpqDaAccelCondition} = 'ok';
        $tmpaccel->{$slot}->{cpqDaAccelStatus} = 'permDisabled';
      } else {
        $tmpaccel->{$slot}->{cpqDaAccelStatus} = 'enabled';
      }
    } elsif (/Battery.* Status: (\w+)/) {
      # sowas gibts auch Battery/Capacitor Status: OK
      $tmpaccel->{$slot}->{cpqDaAccelBattery} = lc $1;
    } elsif (/^\s*$/) {
    }
  }
  $slot = 0;
  $cntlindex = 0;
  $enclosureindex = 0;
  $ldriveindex = 0;
  $pdriveindex = 0;
  foreach (split(/\n/, $hpacucli)) {
    next unless /^config/;
    next if /^config\s*$/;
    s/^config\s*//;
    if (/(MSA[\s\w]+)\s+in\s+(\w+)/) {
      $slot = $2;
      $cntlindex++;
      $pdriveindex = 1;
    } elsif (/([\s\w]+) in Slot\s+(\d+)/) {
      #if ($slot ne $2 || ! $slot) {
        $cntlindex++;
        # 2012-12-15 das passt nicht zur oberen schleife
        # ich habe keine ahnung, was der hintergrund fuer dieses if ist
      #}
      $slot = $2;
      $pdriveindex = 1;
    } elsif (/([\s\w]+) at Port ([\w]+), Box (\d+), (.*)/) {
      $enclosureindex++;
      $tmpencl->{$slot}->{$enclosureindex}->{cpqDaEnclCntlrIndex} = $cntlindex;
      $tmpencl->{$slot}->{$enclosureindex}->{cpqDaEnclIndex} = $enclosureindex;
      $tmpencl->{$slot}->{$enclosureindex}->{cpqDaEnclPort} = $2;
      $tmpencl->{$slot}->{$enclosureindex}->{cpqDaEnclBox} = $3;
      $tmpencl->{$slot}->{$enclosureindex}->{cpqDaEnclCondition} = $4;
      $tmpencl->{$slot}->{$enclosureindex}->{cpqDaEnclStatus} =
          $tmpencl->{$slot}->{$enclosureindex}->{cpqDaEnclCondition};
      $tmpencl->{$slot}->{$enclosureindex}->{cpqDaLogDrvPhyDrvIDs} = 'unknown';
    } elsif (/logicaldrive\s+(.+?)\s+\((.*)\)/) {
      # logicaldrive 1 (683.5 GB, RAID 5, OK)
      # logicaldrive 1 (683.5 GB, RAID 5, OK)
      # logicaldrive 2 (442 MB, RAID 1+0, OK)
      $ldriveindex = $1;
      $tmpld->{$slot}->{$ldriveindex}->{cpqDaLogDrvCntlrIndex} = $cntlindex;
      $tmpld->{$slot}->{$ldriveindex}->{cpqDaLogDrvIndex} = $ldriveindex;
      ($tmpld->{$slot}->{$ldriveindex}->{cpqDaLogDrvSize},
          $tmpld->{$slot}->{$ldriveindex}->{cpqDaLogDrvFaultTol},
          $tmpld->{$slot}->{$ldriveindex}->{cpqDaLogDrvCondition}) =
          map { lc $_ } split(/,\s*/, $2);
      $tmpld->{$slot}->{$ldriveindex}->{cpqDaLogDrvStatus} =
          $tmpld->{$slot}->{$ldriveindex}->{cpqDaLogDrvCondition};
      $tmpld->{$slot}->{$ldriveindex}->{cpqDaLogDrvPhyDrvIDs} = 'unknown';
    } elsif (/physicaldrive\s+(.+?)\s+\((.*)\)/) {
      # physicaldrive 2:0   (port 2:id 0 , Parallel SCSI, 36.4 GB, OK)
      # physicaldrive 2I:1:6 (port 2I:box 1:bay 6, SAS, 146 GB, OK)
      # physicaldrive 1:1 (box 1:bay 1, Parallel SCSI, 146 GB, OK)
      my $name = $1;
      my($location, $type, $size, $status) = split(/,/, $2);
      $status =~ s/^\s+//g;
      $status =~ s/\s+$//g;
      $status = lc $status;
      my %location = ();
      foreach (split(/:/, $location)) {
        $location{$1} = $2 if /(\w+)\s+(\w+)/;
      }
      $location{box} ||= 0;
      $location{id} ||= $pdriveindex;
      $location{bay} ||= $location{id};
      $location{port} ||= $location{bay};
      $tmppd->{$slot}->{$name}->{name} = lc $name;
      $tmppd->{$slot}->{$name}->{cpqDaPhyDrvCntlrIndex} = $cntlindex;
      $tmppd->{$slot}->{$name}->{cpqDaPhyDrvIndex} = $location{id};
      $tmppd->{$slot}->{$name}->{cpqDaPhyDrvBay} = $location{bay};
      $tmppd->{$slot}->{$name}->{cpqDaPhyDrvBusNumber} = $location{port};
      $tmppd->{$slot}->{$name}->{cpqDaPhyDrvSize} = $size;
      $tmppd->{$slot}->{$name}->{cpqDaPhyDrvStatus} = $status;
      $tmppd->{$slot}->{$name}->{cpqDaPhyDrvCondition} = $status;
      $tmppd->{$slot}->{$name}->{ldriveindex} = $ldriveindex || -1;
      foreach (keys %{$tmppd->{$slot}->{$name}}) {
        $tmppd->{$slot}->{$name}->{$_} =~ s/^\s+//g;
        $tmppd->{$slot}->{$name}->{$_} =~ s/\s+$//g;
        $tmppd->{$slot}->{$name}->{$_} = lc $tmppd->{$slot}->{$name}->{$_};
      }
      $pdriveindex++;
    }
  }

  foreach my $slot (keys %{$tmpcntl}) {
    if (exists $tmpcntl->{$slot}->{cpqDaCntlrModel} &&
        ! $self->identified($tmpcntl->{$slot}->{cpqDaCntlrModel})) {
      delete $tmpcntl->{$slot};
      delete $tmpaccel->{$slot};
      delete $tmpencl->{$slot};
      delete $tmpld->{$slot};
      delete $tmppd->{$slot};
    }
  }

#printf "%s\n", Data::Dumper::Dumper($tmpcntl);
#printf "%s\n", Data::Dumper::Dumper($tmpaccel);
#printf "%s\n", Data::Dumper::Dumper($tmpld);
#printf "%s\n", Data::Dumper::Dumper($tmppd);
  foreach my $slot (sort {
      $tmpcntl->{$a}->{cpqDaCntlrIndex} <=> $tmpcntl->{$b}->{cpqDaCntlrIndex}
      }keys %{$tmpcntl}) {
    $tmpcntl->{$slot}->{runtime} = $self->{runtime};
    push(@{$self->{controllers}},
        HP::Proliant::Component::DiskSubsystem::Da::Controller->new(
            %{$tmpcntl->{$slot}}));
  }
  foreach my $slot (sort {
      $tmpaccel->{$a}->{cpqDaAccelCntlrIndex} <=> $tmpaccel->{$b}->{cpqDaAccelCntlrIndex}
      } keys %{$tmpaccel}) {
    $tmpaccel->{$slot}->{runtime} = $self->{runtime};
    push(@{$self->{accelerators}},
        HP::Proliant::Component::DiskSubsystem::Da::Accelerator->new(
            %{$tmpaccel->{$slot}}));
  }
  foreach my $slot (keys %{$tmpencl}) {
    foreach my $enclosureindex (keys %{$tmpencl->{$slot}}) {
      $tmpencl->{$slot}->{$enclosureindex}->{runtime} = $self->{runtime};
      push(@{$self->{enclosures}},
          HP::Proliant::Component::DiskSubsystem::Da::Enclosure->new(
              %{$tmpencl->{$slot}->{$enclosureindex}}));
    }
  }
  foreach my $slot (keys %{$tmpld}) {
    foreach my $ldriveindex (keys %{$tmpld->{$slot}}) {
      $tmpld->{$slot}->{$ldriveindex}->{runtime} = $self->{runtime};
      push(@{$self->{logical_drives}},
          HP::Proliant::Component::DiskSubsystem::Da::LogicalDrive->new(
              %{$tmpld->{$slot}->{$ldriveindex}}));
    }
    foreach my $pdriveindex (sort {
        (split ':', $a, 2)[0] cmp (split ':', $b, 2)[0] ||
        (split ':', $a, 2)[1] cmp (split ':', $b, 2)[1] ||
        (split ':', $a, 2)[2] <=> (split ':', $b, 2)[2]
        } keys %{$tmppd->{$slot}}) {
      $tmppd->{$slot}->{$pdriveindex}->{runtime} = $self->{runtime};
      push(@{$self->{physical_drives}},
          HP::Proliant::Component::DiskSubsystem::Da::PhysicalDrive->new(
              %{$tmppd->{$slot}->{$pdriveindex}}));
    }
  }
}

sub identified {
  my $self = shift;
  my $info = shift;
  return 1 if $info =~ /Parallel SCSI/;
  return 1 if $info =~ /Smart Array/; # Trond: works fine on E200i, P400, E400
  return 1 if $info =~ /MSA500/;
  #return 1 if $info =~ /Smart Array (5|6)/;
  #return 1 if $info =~ /Smart Array P400i/; # snmp sagt Da, trotz SAS in cli
  #return 1 if $info =~ /Smart Array P410i/; # dto
  return 0;
}
