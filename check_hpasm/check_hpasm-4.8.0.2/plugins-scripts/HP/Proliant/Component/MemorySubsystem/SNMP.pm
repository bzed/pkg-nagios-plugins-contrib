package HP::Proliant::Component::MemorySubsystem::SNMP;
our @ISA = qw(HP::Proliant::Component::MemorySubsystem
    HP::Proliant::Component::SNMP);

use strict;

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    dimms => [],
    si_dimms => [],
    he_dimms => [],
    h2_dimms => [],
    he_cartridges => [],
    h2_cartridges => [],
    si_overall_condition => undef,
    he_overall_condition => undef,
    h2_overall_condition => undef,
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  $self->si_init();
  $self->he_init();
  $self->he_cartridge_init();
  $self->h2_init();
  #$self->h2_cartridge_init();
  $self->condense();
  return $self;
}

sub si_init {
  my $self = shift;
  my $snmpwalk = $self->{rawdata};
  my $oids = {
      cpqSiMemModuleEntry => '1.3.6.1.4.1.232.2.2.4.5.1',
      cpqSiMemBoardIndex => '1.3.6.1.4.1.232.2.2.4.5.1.1',
      cpqSiMemModuleIndex => '1.3.6.1.4.1.232.2.2.4.5.1.2',
      cpqSiMemModuleSize => '1.3.6.1.4.1.232.2.2.4.5.1.3',
      cpqSiMemModuleType => '1.3.6.1.4.1.232.2.2.4.5.1.4',
      cpqSiMemECCStatus => '1.3.6.1.4.1.232.2.2.4.5.1.11',
      cpqSiMemModuleHwLocation => '1.3.6.1.4.1.232.2.2.4.5.1.12',
      cpqSiMemModuleTypeValue => {
          1 => 'other',
          2 => 'board',
          3 => 'cpqSingleWidthModule',
          4 => 'cpqDoubleWidthModule',
          5 => 'simm',
          6 => 'pcmcia',
          7 => 'compaq-specific',
          8 => 'dimm',
          9 => 'smallOutlineDimm',
          10 => 'rimm',
          11 => 'srimm',
      },
      cpqSiMemECCStatusValue => {
          0 => "n/a",
          1 => "other",
          2 => "ok",
          3 => "degraded",
          4 => "degradedModuleIndexUnknown",
          34 => 'n/a', # es ist zum kotzen...
          104 => 'n/a',
      },
  };
  # INDEX { cpqSiMemBoardIndex, cpqSiMemModuleIndex }
  foreach ($self->get_entries($oids, 'cpqSiMemModuleEntry')) {
    $_->{cartridge} = $_->{cpqSiMemBoardIndex};
    $_->{module} = $_->{cpqSiMemModuleIndex};
    next if (! defined $_->{cartridge} || ! defined $_->{module});
    $_->{size} = $_->{cpqSiMemModuleSize};
    $_->{type} = $_->{cpqSiMemModuleType};
    $_->{condition} = $_->{cpqSiMemECCStatus};
    $_->{status} = ($_->{cpqSiMemModuleSize} > 0) ? 'present' : 'notPresent';
    push(@{$self->{si_dimms}},
        HP::Proliant::Component::MemorySubsystem::Dimm->new(%{$_})
    );
  } 
  my $cpqSiMemECCCondition = '1.3.6.1.4.1.232.2.2.4.15.0';
  my $cpqSiMemECCConditionValue = {
    1 => 'other',
    2 => 'ok',
    3 => 'degraded',
  };
  $self->{si_overall_condition} = SNMP::Utils::get_object_value(
        $self->{rawdata}, $cpqSiMemECCCondition,
        $cpqSiMemECCConditionValue);
  $self->trace(2, sprintf 'overall si condition is %s', 
      $self->{si_overall_condition} || 'undefined');
}

sub he_init {
  my $self = shift;
  my $snmpwalk = $self->{rawdata};
  my $oids = {
      cpqHeResMemModuleEntry => '1.3.6.1.4.1.232.6.2.14.11.1',
      cpqHeResMemBoardIndex => '1.3.6.1.4.1.232.6.2.14.11.1.1',
      cpqHeResMemModuleIndex => '1.3.6.1.4.1.232.6.2.14.11.1.2',
      cpqHeResMemModuleStatus => '1.3.6.1.4.1.232.6.2.14.11.1.4',
      cpqHeResMemModuleCondition => '1.3.6.1.4.1.232.6.2.14.11.1.5',
      cpqHeResMemModuleStatusValue => {
          1 => "other",         # unknown or could not be determined
          2 => "notPresent",    # not present or un-initialized
          3 => "present",       # present but not in use
          4 => "good",          # present and in use. ecc threshold not exceeded
          5 => "add",           # added but not yet in use
          6 => "upgrade",       # upgraded but not yet in use
          7 => "missing",       # expected but missing
          8 => "doesNotMatch",  # does not match the other modules in the bank
          9 => "notSupported",  # module not supported
          10 => "badConfig",    # violates add/upgrade configuration
          11 => "degraded",     # ecc exceeds threshold
      },
      # condition = status of the correctable memory errors
      cpqHeResMemModuleConditionValue => {
          0 => "n/a", # this appears only with buggy firmwares.
          # (only 1 module shows up)
          1 => "other",
          2 => "ok",
          3 => "degraded",
      },
  };
  my $tablesize = SNMP::Utils::get_size($snmpwalk, 
      $oids->{cpqHeResMemModuleEntry});
  # INDEX { cpqHeResMemBoardIndex, cpqHeResMemModuleIndex }
  foreach ($self->get_entries($oids, 'cpqHeResMemModuleEntry')) {
    $_->{cartridge} = $_->{cpqHeResMemBoardIndex};
    $_->{module} = $_->{cpqHeResMemModuleIndex};
    $_->{present} = $_->{cpqHeResMemModuleStatus};
    $_->{status} = $_->{cpqHeResMemModuleStatus};
    $_->{condition} = $_->{cpqHeResMemModuleCondition};
    if ((! defined $_->{module}) && ($_->{cartridge} == 0)) {
      $_->{module} = $_->{index2}; # auf dem systemboard verbaut
    }

    push(@{$self->{he_dimms}}, 
        HP::Proliant::Component::MemorySubsystem::Dimm->new(%{$_})
    ) unless (! defined $_->{cartridge} || ! defined $_->{module} ||
        $tablesize == 1);
  }
  my $cpqHeResilientMemCondition = '1.3.6.1.4.1.232.6.2.14.4.0';
  my $cpqHeResilientMemConditionValue = {
    1 => 'other',
    2 => 'ok',
    3 => 'degraded',
  };
  $self->{he_overall_condition} = SNMP::Utils::get_object_value(
        $self->{rawdata}, $cpqHeResilientMemCondition,
        $cpqHeResilientMemConditionValue);
  $self->trace(2, sprintf 'overall he condition is %s', 
      $self->{hei_overall_condition} || 'undefined');
}

sub he_cartridge_init {
  my $self = shift;
  my $snmpwalk = $self->{rawdata};
  my $oids = {
      cpqHeResMemBoardEntry => '1.3.6.1.4.1.232.6.2.14.10.1',
      cpqHeResMemBoardSlotIndex => '1.3.6.1.4.1.232.6.2.14.10.1.1',
      cpqHeResMemBoardOnlineStatus => '1.3.6.1.4.1.232.6.2.14.10.1.2',
      cpqHeResMemBoardErrorStatus => '1.3.6.1.4.1.232.6.2.14.10.1.3',
      cpqHeResMemBoardNumSockets => '1.3.6.1.4.1.232.6.2.14.10.1.5',
      cpqHeResMemBoardOsMemSize => '1.3.6.1.4.1.232.6.2.14.10.1.6',
      cpqHeResMemBoardTotalMemSize => '1.3.6.1.4.1.232.6.2.14.10.1.7',
      cpqHeResMemBoardCondition => '1.3.6.1.4.1.232.6.2.14.10.1.8',
      # onlinestatus
      cpqHeResMemBoardOnlineStatusValue => {
          0 => "n/a", # this appears only with buggy firmwares.
          # (only 1 module shows up)
          1 => "other",
          2 => "present",
          3 => "absent",
      },
      cpqHeResMemBoardErrorStatusValue => {
          1 => "other",         #
          2 => "noError",       #
          3 => "dimmEccError",  #
          4 => "unlockError",   #
          5 => "configError",   #
          6 => "busError",      #
          7 => "powerError",    #
      },
      # condition = status of the correctable memory errors
      cpqHeResMemBoardConditionValue => {
          0 => "n/a", # this appears only with buggy firmwares.
          # (only 1 module shows up)
          1 => "other",
          2 => "ok",
          3 => "degraded",
      },
  };
  my $tablesize = SNMP::Utils::get_size($snmpwalk,
      $oids->{cpqHeResMemBoardEntry});
  # INDEX { cpqHeResMemBoardIndex, cpqHeResMemBoardIndex }
  foreach ($self->get_entries($oids, 'cpqHeResMemBoardEntry')) {
    push(@{$self->{he_cartridges}},
        HP::Proliant::Component::MemorySubsystem::Cartridge->new(%{$_})
    ) unless (! defined $_->{cpqHeResMemBoardSlotIndex} || $tablesize == 1);
  }
}

sub h2_init {
  my $self = shift;
  my $snmpwalk = $self->{rawdata};
  my $oids = {
      cpqHeResMem2ModuleEntry => '1.3.6.1.4.1.232.6.2.14.13.1',
      cpqHeResMem2BoardNum => '1.3.6.1.4.1.232.6.2.14.13.1.2',
      cpqHeResMem2ModuleNum => '1.3.6.1.4.1.232.6.2.14.13.1.5',
      cpqHeResMem2ModuleStatus => '1.3.6.1.4.1.232.6.2.14.13.1.19',
      cpqHeResMem2ModuleCondition => '1.3.6.1.4.1.232.6.2.14.13.1.20',
      cpqHeResMem2ModuleSize => '1.3.6.1.4.1.232.6.2.14.13.1.6',
    
      cpqHeResMem2ModuleStatusValue => {
          1 => "other",         # unknown or could not be determined
          2 => "notPresent",    # not present or un-initialized
          3 => "present",       # present but not in use
          4 => "good",          # present and in use. ecc threshold not exceeded
          5 => "add",           # added but not yet in use
          6 => "upgrade",       # upgraded but not yet in use
          7 => "missing",       # expected but missing
          8 => "doesNotMatch",  # does not match the other modules in the bank
          9 => "notSupported",  # module not supported
          10 => "badConfig",    # violates add/upgrade configuration
          11 => "degraded",     # ecc exceeds threshold
      },
      # condition = status of the correctable memory errors
      cpqHeResMem2ModuleConditionValue => {
          0 => "n/a", # this appears only with buggy firmwares.
          # (only 1 module shows up)
          1 => "other",
          2 => "ok",
          3 => "degraded",
      },
  };
  # INDEX { cpqHeResMem2ModuleNum }
  my $lastboard = 0;
  my $lastmodule = 0;
  my $myboard= 0;
  my $hpboard = 0;
  foreach (sort { $a->{index1} <=> $b->{index1} }
      $self->get_entries($oids, 'cpqHeResMem2ModuleEntry')) {
    $hpboard = $_->{cpqHeResMem2BoardNum};
      # dass hier faelschlicherweise 0 zurueckkommt, wundert mich schon
      # gar nicht mehr
    $_->{module} = $_->{cpqHeResMem2ModuleNum};
    if ($_->{module} < $lastmodule) {
      # sieht so aus, als haette man es mit einem neuen board zu tun
      # da hp zu bloed ist, selber hochzuzaehlen, muss ich das tun
      $myboard++;
    }
    $lastmodule = $_->{cpqHeResMem2ModuleNum};
    $_->{cartridge} = ($myboard != $hpboard) ? $myboard : $hpboard;
    $_->{present} = $_->{cpqHeResMem2ModuleStatus};
    $_->{status} = $_->{cpqHeResMem2ModuleStatus};
    $_->{condition} = $_->{cpqHeResMem2ModuleCondition};
    $_->{size} = $_->{cpqHeResMem2ModuleSize};
    push(@{$self->{h2_dimms}},
        HP::Proliant::Component::MemorySubsystem::Dimm->new(%{$_})
    ) unless (! defined $_->{cpqHeResMem2BoardNum} ||
        ! defined $_->{cpqHeResMem2ModuleNum});
  }
}

sub h2_cartridge_init {
  my $self = shift;
  my $snmpwalk = $self->{rawdata};
  my $oids = {
      cpqHeResMem2BoardEntry => '1.3.6.1.4.1.232.6.2.14.12.1',
      cpqHeResMem2BoardIndex => '1.3.6.1.4.1.232.6.2.14.12.1.1',
      cpqHeResMem2BoardOnlineStatus => '1.3.6.1.4.1.232.6.2.14.12.1.5',
      cpqHeResMem2BoardErrorStatus => '1.3.6.1.4.1.232.6.2.14.12.1.6',
      cpqHeResMem2BoardNumSockets => '1.3.6.1.4.1.232.6.2.14.12.1.8',
      cpqHeResMem2BoardOsMemSize => '1.3.6.1.4.1.232.6.2.14.12.1.9',
      cpqHeResMem2BoardTotalMemSize => '1.3.6.1.4.1.232.6.2.14.12.1.10',
      cpqHeResMem2BoardCondition => '1.3.6.1.4.1.232.6.2.14.12.1.11',
      # onlinestatus
      cpqHeResMem2BoardOnlineStatusValue => {
          0 => "n/a", # this appears only with buggy firmwares.
          # (only 1 module shows up)
          1 => "other",
          2 => "present",
          3 => "absent",
      },
      cpqHeResMem2BoardErrorStatusValue => {
          1 => "other",         #
          2 => "noError",       #
          3 => "dimmEccError",  #
          4 => "unlockError",   #
          5 => "configError",   #
          6 => "busError",      #
          7 => "powerError",    #
      },
      # condition = status of the correctable memory errors
      cpqHeResMem2BoardConditionValue => {
          0 => "n/a", # this appears only with buggy firmwares.
          # (only 1 module shows up)
          1 => "other",
          2 => "ok",
          3 => "degraded",
      },
  };
  my $tablesize = SNMP::Utils::get_size($snmpwalk,
      $oids->{cpqHeResMemBoardEntry});
  # INDEX { cpqHeResMem2BoardIndex, cpqHeResMem2BoardIndex }
  foreach ($self->get_entries($oids, 'cpqHeResMem2BoardEntry')) {
    push(@{$self->{h2_cartridges}},
        HP::Proliant::Component::MemorySubsystem::Cartridge->new(%{$_})
    ) unless (! defined $_->{cpqHeRes2MemBoardIndex} || $tablesize == 1);
  }
}

sub condense {
  my $self = shift;
  my $snmpwalk = $self->{rawdata};
  # wenn saemtliche dimms n/a sind
  #  wenn ignore dimms: ignoring %d dimms with status 'n/a'
  #  wenn buggyfirmware: ignoring %d dimms with status 'n/a' because of buggy firmware
  # if buggy firmware : condition n/a ist normal
  # ignore-dimms :
  # es gibt si_dimms und he_dimms
  my $si_dimms = scalar(@{$self->{si_dimms}});
  my $he_dimms = scalar(@{$self->{he_dimms}});
  my $h2_dimms = scalar(@{$self->{h2_dimms}});
  $self->trace(2, sprintf "SI: %02d   HE: %02d   H2: %02d",
      $si_dimms, $he_dimms, $h2_dimms)
      if ($self->{runtime}->{options}->{verbose} >= 2);
  foreach ($self->get_si_boards()) {
    printf "SI%02d-> ", $_ if ($self->{runtime}->{options}->{verbose} >= 2);
    foreach ($self->get_si_modules($_)) {
      printf "%02d ", $_ if ($self->{runtime}->{options}->{verbose} >= 2);
    }
    printf "\n" if ($self->{runtime}->{options}->{verbose} >= 2);
  }
  foreach ($self->get_he_boards()) {
    printf "HE%02d-> ", $_ if ($self->{runtime}->{options}->{verbose} >= 2);
    foreach ($self->get_he_modules($_)) {
      printf "%02d ", $_ if ($self->{runtime}->{options}->{verbose} >= 2);
    }
    printf "\n" if ($self->{runtime}->{options}->{verbose} >= 2);
  }
  foreach ($self->get_h2_boards()) {
    printf "H2%02d-> ", $_ if ($self->{runtime}->{options}->{verbose} >= 2);
    foreach ($self->get_h2_modules($_)) {
      printf "%02d ", $_ if ($self->{runtime}->{options}->{verbose} >= 2);
    }
    printf "\n" if ($self->{runtime}->{options}->{verbose} >= 2);
  }
  if (($h2_dimms == 0) && ($he_dimms == 0) && ($si_dimms > 0)) {
    printf "TYP1 %s\n", $self->{runtime}->{product}
        if ($self->{runtime}->{options}->{verbose} >= 2);
    @{$self->{dimms}} = $self->update_si_with_si();
  } elsif (($h2_dimms == 0) && ($he_dimms > 0) && ($si_dimms > 0)) {
    printf "TYP2 %s\n", $self->{runtime}->{product}
        if ($self->{runtime}->{options}->{verbose} >= 2);
    @{$self->{dimms}} = $self->update_si_with_he();
  } elsif (($h2_dimms == 0) && ($he_dimms > 0) && ($si_dimms == 0)) {
    printf "TYP3 %s\n", $self->{runtime}->{product}
        if ($self->{runtime}->{options}->{verbose} >= 2);
    @{$self->{dimms}} = $self->update_he_with_he();
  } elsif (($h2_dimms > 0) && ($he_dimms == 0) && ($si_dimms == 0)) {
    printf "TYP4 %s\n", $self->{runtime}->{product}
        if ($self->{runtime}->{options}->{verbose} >= 2);
    @{$self->{dimms}} = $self->update_h2_with_h2();
  } elsif (($h2_dimms > 0) && ($he_dimms > 0) && ($si_dimms == 0)) {
    printf "TYP5 %s\n", $self->{runtime}->{product}
        if ($self->{runtime}->{options}->{verbose} >= 2);
    @{$self->{dimms}} = $self->update_he_with_h2();
  } elsif (($h2_dimms > 0) && ($he_dimms == 0) && ($si_dimms > 0)) {
    printf "TYP6 %s\n", $self->{runtime}->{product}
        if ($self->{runtime}->{options}->{verbose} >= 2);
    @{$self->{dimms}} = $self->update_si_with_h2();
  } elsif (($h2_dimms > 0) && ($he_dimms > 0) && ($si_dimms > 0)) {
    if ($h2_dimms > $si_dimms) {
      printf "TYP7 %s\n", $self->{runtime}->{product}
          if ($self->{runtime}->{options}->{verbose} >= 2);
      @{$self->{dimms}} = $self->update_he_with_h2();
    } else {
      printf "TYP8 %s\n", $self->{runtime}->{product}
          if ($self->{runtime}->{options}->{verbose} >= 2);
      @{$self->{dimms}} = $self->update_si_with_he();
    }
  } else {
    printf "TYPX %s\n", $self->{runtime}->{product}
        if ($self->{runtime}->{options}->{verbose} >= 2);
  }
  my $all_dimms = scalar(@{$self->{dimms}});
  $self->trace(2, sprintf "ALL: %02d", $all_dimms);
}

sub dump {
  my $self = shift;
  if ($self->{runtime}->{options}->{verbose} > 2) {
    printf "[SI]\n";
    foreach (@{$self->{si_dimms}}) {
      $_->dump();
    }
    printf "[HE]\n";
    foreach (@{$self->{he_dimms}}) {
      $_->dump();
    }
    printf "[H2]\n";
    foreach (@{$self->{h2_dimms}}) {
      $_->dump();
    }
  }
  $self->SUPER::dump();
}

sub update_si_with_si {
  my $self = shift;
  my $snmpwalk = $self->{rawdata};
  my @dimms = ();
  my $repaircondition = undef;
  # wenn si keine statusinformationen liefert, dann besteht die chance
  # dass ein undokumentiertes he-fragment vorliegt
  # 1.3.6.1.4.1.232.6.2.14.11.1.1.0.<anzahl der dimms>
  my $cpqHeResMemModuleEntry = "1.3.6.1.4.1.232.6.2.14.11.1";
  if (SNMP::Utils::get_size($snmpwalk, $cpqHeResMemModuleEntry) == 1) {
    $repaircondition = lc SNMP::Utils::get_object(
        $snmpwalk, $cpqHeResMemModuleEntry.'.1.0.'.scalar(@{$self->{si_dimms}}));
    # repaircondition 0 (ok) biegt alles wieder gerade
  } else { 
    # anderer versuch
    if ($self->{si_overall_condition} &&
        $self->{si_overall_condition} eq 'ok') {
      $repaircondition = 0;
    }
  }
  foreach my $si_dimm (@{$self->{si_dimms}}) {
    if (($si_dimm->{condition} eq 'n/a') ||
        ($si_dimm->{condition} eq 'other')) {
      $si_dimm->{condition} = 'ok' if
          (defined $repaircondition && $repaircondition == 0);
    }
    push(@dimms,
        HP::Proliant::Component::MemorySubsystem::Dimm->new(
            runtime => $si_dimm->{runtime},
            cartridge => $si_dimm->{cartridge},
            module => $si_dimm->{module},
            size => $si_dimm->{size},
            status => $si_dimm->{status},
            condition => $si_dimm->{condition},
    ));
  }
  return @dimms;
}

sub update_si_with_he {
  my $self = shift;
  my @dimms = ();
  my $first_si_cartridge = ($self->get_si_boards())[0];
  my $first_he_cartridge = ($self->get_he_boards())[0];
  my $offset = 0;
  if (scalar(@{$self->{si_dimms}}) == scalar(@{$self->{he_dimms}})) {
    # aufpassen! sowas kann vorkommen: si cartridge 0...6, he cartridge 1...7
    if ($first_si_cartridge != $first_he_cartridge) {
      # README case 5
      $offset = $first_si_cartridge - $first_he_cartridge;
    }
  } elsif ((scalar(@{$self->{si_dimms}}) > 1) && 
      (scalar(@{$self->{he_dimms}}) == 1)) {
    # siehe update_si_with_si. he-fragment
    return $self->update_si_with_si();
  } else { 
    # z.b. 4 si notpresent, 4 si present, 4 he
  }
  foreach my $si_dimm (@{$self->{si_dimms}}) {
    if (($si_dimm->{condition} eq 'n/a') || 
        ($si_dimm->{condition} eq 'other')) {
      if (my $he_dimm = $self->get_he_module(
          $si_dimm->{cartridge} - $offset, $si_dimm->{module})) {
        # vielleicht hat he mehr ahnung
        $si_dimm->{condition} = $he_dimm->{condition};
        if (($si_dimm->{condition} eq 'n/a') || 
            ($si_dimm->{condition} eq 'other')) {
          # wenns immer noch kein brauchbares ergebnis gibt....
          if ($self->{he_overall_condition} &&
              $self->{he_overall_condition} eq 'ok') {
            # wird schon stimmen...
            $si_dimm->{condition} = 'ok';
          } else {
            # ansonsten stellen wir uns dumm
            $si_dimm->{status} = 'notPresent';
          }
        }
      } else {
        # in dem fall zeigt si unbestueckte cartridges an
      }
    }
    push(@dimms,
        HP::Proliant::Component::MemorySubsystem::Dimm->new(
            runtime => $si_dimm->{runtime},
            cartridge => $si_dimm->{cartridge},
            module => $si_dimm->{module},
            size => $si_dimm->{size},
            status => $si_dimm->{status},
            condition => $si_dimm->{condition},
    ));
  }
  return @dimms;
}

sub update_he_with_he {
  my $self = shift;
  my @dimms = ();
  foreach my $he_dimm (@{$self->{he_dimms}}) {
    push(@dimms,
        HP::Proliant::Component::MemorySubsystem::Dimm->new(
            runtime => $he_dimm->{runtime},
            cartridge => $he_dimm->{cartridge},
            module => $he_dimm->{module},
            size => $he_dimm->{size},
            status => $he_dimm->{status},
            condition => $he_dimm->{condition},
    ));
  }
  return @dimms;
}

sub update_si_with_h2 {
  my $self = shift;
  my @dimms = ();
  my $first_si_cartridge = ($self->get_si_boards())[0];
  my $first_h2_cartridge = ($self->get_h2_boards())[0];
  my $offset = 0;
  if (scalar(@{$self->{si_dimms}}) == scalar(@{$self->{h2_dimms}})) {
    # aufpassen! sowas kann vorkommen: si cartridge 0...6, he cartridge 1...7
    if ($first_si_cartridge != $first_h2_cartridge) {
      # README case 5
      $offset = $first_si_cartridge - $first_h2_cartridge;
    }
  } else { 
    # z.b. 4 si notpresent, 4 si present, 4 he
  }
  foreach my $si_dimm (@{$self->{si_dimms}}) {
    if (($si_dimm->{condition} eq 'n/a') || 
        ($si_dimm->{condition} eq 'other')) {
      if (my $h2_dimm = $self->get_h2_module(
          $si_dimm->{cartridge} - $offset, $si_dimm->{module})) {
        # vielleicht hat h2 mehr ahnung
        $si_dimm->{condition} = $h2_dimm->{condition};
        if (1) {
          # ist zwar da, aber irgendwie auskonfiguriert
          $si_dimm->{status} = 'notPresent' if $h2_dimm->{status} eq 'other';
        }
      } else {
        # in dem fall zeigt si unbestueckte cartridges an
      }
    }
    push(@dimms,
        HP::Proliant::Component::MemorySubsystem::Dimm->new(
            runtime => $si_dimm->{runtime},
            cartridge => $si_dimm->{cartridge},
            module => $si_dimm->{module},
            size => $si_dimm->{size},
            status => $si_dimm->{status},
            condition => $si_dimm->{condition},
    ));
  }
  return @dimms;
}

sub update_he_with_h2 {
  my $self = shift;
  my @dimms = ();
  my $first_he_cartridge = ($self->get_he_boards())[0];
  my $first_h2_cartridge = ($self->get_h2_boards())[0];
  my $offset = 0;
  # auch hier koennte sowas u.u.vorkommen: he cartridge 0..6, h2 cartridge 1..7
  # ich habs zwar nie gesehen, aber wer weiss...
  if ($first_h2_cartridge != $first_he_cartridge) {
    $offset = $first_h2_cartridge - $first_he_cartridge;
  }
  foreach my $he_dimm (@{$self->{he_dimms}}) {
    if (($he_dimm->{condition} eq 'n/a') || 
        ($he_dimm->{condition} eq 'other')) {
      if (my $h2_dimm = $self->get_h2_module(
          $he_dimm->{cartridge} + $offset, $he_dimm->{module})) {
        # vielleicht hat h2 mehr ahnung
        $he_dimm->{condition} = $h2_dimm->{condition};
        if (1) {
          # ist zwar da, aber irgendwie auskonfiguriert
          $he_dimm->{status} = 'notPresent' if $h2_dimm->{status} eq 'other';
        }
      } else {
        # in dem fall weiss he mehr als h2
      }
    }
    if ($he_dimm->{size} == 0) {
      if (my $h2_dimm = $self->get_h2_module(
          $he_dimm->{cartridge} + $offset, $he_dimm->{module})) {
        $he_dimm->{size} = $h2_dimm->{size};
        # h2 beinhaltet eine size-oid
      }
    }
    push(@dimms,
        HP::Proliant::Component::MemorySubsystem::Dimm->new(
            runtime => $he_dimm->{runtime},
            cartridge => $he_dimm->{cartridge},
            module => $he_dimm->{module},
            size => $he_dimm->{size},
            status => $he_dimm->{status},
            condition => $he_dimm->{condition},
    ));
  }
  return @dimms;
}

sub update_h2_with_h2 {
  my $self = shift;
  my @dimms = ();
  foreach my $h2_dimm (@{$self->{h2_dimms}}) {
    push(@dimms,
        HP::Proliant::Component::MemorySubsystem::Dimm->new(
            runtime => $h2_dimm->{runtime},
            cartridge => $h2_dimm->{cartridge},
            module => $h2_dimm->{module},
            size => $h2_dimm->{size},
            status => $h2_dimm->{status},
            condition => $h2_dimm->{condition},
    ));
  }
  return @dimms;
}

sub is_faulty {
  my $self = shift;
  if (scalar(@{$self->{si_dimms}}) > 0 && 
      scalar(@{$self->{he_dimms}}) > 0) {
    return $self->si_is_faulty() || $self->he_is_faulty();
  } elsif (scalar(@{$self->{si_dimms}}) > 0 &&
        scalar(@{$self->{he_dimms}}) == 0) {
    return $self->si_is_faulty();
  } elsif (scalar(@{$self->{si_dimms}}) == 0 &&
        scalar(@{$self->{he_dimms}}) > 0) {
    return $self->he_is_faulty();
  } else {
    return 0;
  }
}

sub si_is_faulty {
  my $self = shift;
  return ! defined $self->{si_overall_condition} ? 0 :
      $self->{si_overall_condition} eq 'degraded' ? 1 : 0;
}

sub si_is_ok {
  my $self = shift;
  return ! defined $self->{si_overall_condition} ? 1 :
      $self->{si_overall_condition} eq 'ok' ? 1 : 0;
}

sub he_is_faulty {
  my $self = shift;
  return ! defined $self->{he_overall_condition} ? 0 :
      $self->{he_overall_condition} eq 'degraded' ? 1 : 0;
}

sub he_is_ok {
  my $self = shift;
  return ! defined $self->{he_overall_condition} ? 1 :
      $self->{he_overall_condition} eq 'ok' ? 1 : 0;
}

sub get_si_boards {
  my $self = shift;
  my %found = ();
  foreach (@{$self->{si_dimms}}) {
    $found{$_->{cartridge}} = 1;
  }
  return sort { $a <=> $b } keys %found;
}

sub get_si_modules {
  my $self = shift;
  my $board = shift;
  my %found = ();
  foreach (grep { $_->{cartridge} == $board } @{$self->{si_dimms}}) {
    $found{$_->{module}} = 1;
  }
  return sort { $a <=> $b } keys %found;
}

sub get_he_boards {
  my $self = shift;
  my %found = ();
  foreach (@{$self->{he_dimms}}) {
    $found{$_->{cartridge}} = 1;
  }
  return sort { $a <=> $b } keys %found;
}

sub get_he_modules {
  my $self = shift;
  my $board = shift;
  my %found = ();
  foreach (grep { $_->{cartridge} == $board } @{$self->{he_dimms}}) {
    $found{$_->{module}} = 1;
  }
  return sort { $a <=> $b } keys %found;
}

sub get_he_module {
  my $self = shift;
  my $board = shift;
  my $module = shift;
  my $found = (grep { $_->{cartridge} == $board && $_->{module} == $module } 
      @{$self->{he_dimms}})[0];
  return $found;
}

sub get_h2_boards {
  my $self = shift;
  my %found = ();
  # 
  foreach (@{$self->{h2_dimms}}) {
    $found{$_->{cartridge}} = 1;
  }
  return sort { $a <=> $b } keys %found;
}

sub get_h2_modules {
  my $self = shift;
  my $board = shift;
  my %found = ();
  foreach (grep { $_->{cartridge} == $board } @{$self->{h2_dimms}}) {
    $found{$_->{module}} = 1;
  }
  return sort { $a <=> $b } keys %found;
}

sub get_h2_module {
  my $self = shift;
  my $board = shift;
  my $module = shift;
  my $found = (grep { $_->{cartridge} == $board && $_->{module} == $module } 
      @{$self->{h2_dimms}})[0];
  return $found;
}


