package HP::Proliant::Component::FanSubsystem;
our @ISA = qw(HP::Proliant::Component);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
################################## fan_redundancy ##########
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    method => $params{method},
    condition => $params{condition},
    status => $params{status},
    fans => [],
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  if ($self->{method} eq 'snmp') {
    return HP::Proliant::Component::FanSubsystem::SNMP->new(%params);
  } elsif ($self->{method} eq 'cli') {
    return HP::Proliant::Component::FanSubsystem::CLI->new(%params);
  } else {
    die 'unknown method';
  }
  return $self;
}

sub check {
  my $self = shift;
  my $errorfound = 0;
  $self->add_info('checking fans');
  $self->blacklist('ff', '');
  if (scalar (@{$self->{fans}}) == 0) {
    $self->overall_check(); # sowas ist mir nur einmal untergekommen
    # die maschine hatte alles in allem nur 2 oids (cpqHeFltTolFanChassis)
    # SNMPv2-SMI::enterprises.232.6.2.6.7.1.1.0.1 = INTEGER: 0
    # SNMPv2-SMI::enterprises.232.6.2.6.7.1.1.0.2 = INTEGER: 0
  } else {
    my $overallhealth = $self->overall_check(); 
    foreach (@{$self->{fans}}) {
      $_->{overallhealth} = $overallhealth;
      $_->check();
    }
  }
}

sub dump {
  my $self = shift;
  foreach (@{$self->{fans}}) {
    $_->dump();
  }
}

sub get_fan_by_index {
  my $self = shift;
  my $index;
  foreach (@{$self->{fans}}) {
    return $_ if exists $_->{cpqHeFltTolFanIndex} && 
        $_->{cpqHeFltTolFanIndex} == $index;
  }
  return undef;
}


package HP::Proliant::Component::FanSubsystem::Fan;
our @ISA = qw(HP::Proliant::Component::FanSubsystem);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  if (exists $params{cpqHeFltTolFanRedundant}) {
    return HP::Proliant::Component::FanSubsystem::Fan::FTol->new(%params);
  } else {
    return HP::Proliant::Component::FanSubsystem::Fan::Thermal->new(%params);
  }
}


package HP::Proliant::Component::FanSubsystem::Fan::FTol;
our @ISA = qw(HP::Proliant::Component::FanSubsystem::Fan);


use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    cpqHeFltTolFanChassis => $params{cpqHeFltTolFanChassis},
    cpqHeFltTolFanIndex => $params{cpqHeFltTolFanIndex},
    cpqHeFltTolFanLocale => $params{cpqHeFltTolFanLocale},
    cpqHeFltTolFanPresent => $params{cpqHeFltTolFanPresent},
    cpqHeFltTolFanType => $params{cpqHeFltTolFanType},
    cpqHeFltTolFanSpeed => $params{cpqHeFltTolFanSpeed},
    cpqHeFltTolFanRedundant => $params{cpqHeFltTolFanRedundant},
    cpqHeFltTolFanRedundantPartner => $params{cpqHeFltTolFanRedundantPartner},
    cpqHeFltTolFanCondition => $params{cpqHeFltTolFanCondition},
    cpqHeFltTolFanPctMax => $params{cpqHeFltTolFanPctMax}, #!!!
    cpqHeFltTolFanHotPlug => $params{cpqHeFltTolFanHotPlug}, #!!!
    partner => $params{partner},
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  if (($self->{cpqHeFltTolFanRedundant} eq 'redundant') &&
     ((! defined $self->{cpqHeFltTolFanRedundantPartner}) ||
     (! $self->{cpqHeFltTolFanRedundantPartner}))) {
    $self->{cpqHeFltTolFanRedundant} = 'notRedundant';
      # cpqHeFltTolFanRedundantPartner=0: partner not avail
  }
  return $self;
} 

sub check { 
  my $self = shift;
  $self->blacklist('f', $self->{cpqHeFltTolFanIndex});
  $self->add_info(sprintf 'fan %d is %s, speed is %s, pctmax is %s%%, '.
      'location is %s, redundance is %s, partner is %s',
      $self->{cpqHeFltTolFanIndex}, $self->{cpqHeFltTolFanPresent},
      $self->{cpqHeFltTolFanSpeed}, $self->{cpqHeFltTolFanPctMax},
      $self->{cpqHeFltTolFanLocale}, $self->{cpqHeFltTolFanRedundant},
      $self->{cpqHeFltTolFanRedundantPartner});
  $self->add_extendedinfo(sprintf 'fan_%s=%d%%',
      $self->{cpqHeFltTolFanIndex}, $self->{cpqHeFltTolFanPctMax});
  if ($self->{cpqHeFltTolFanPresent} eq 'present') {
    if ($self->{cpqHeFltTolFanSpeed} eq 'high') { 
      $self->add_info(sprintf 'fan %d (%s) runs at high speed',
          $self->{cpqHeFltTolFanIndex}, $self->{cpqHeFltTolFanLocale});
      $self->add_message(CRITICAL, $self->{info});
    } elsif ($self->{cpqHeFltTolFanSpeed} ne 'normal') {
      $self->add_info(sprintf 'fan %d (%s) needs attention',
          $self->{cpqHeFltTolFanIndex}, $self->{cpqHeFltTolFanLocale});
      $self->add_message(CRITICAL, $self->{info});
    }
    if ($self->{cpqHeFltTolFanCondition} eq 'failed') {
      $self->add_info(sprintf 'fan %d (%s) failed',
          $self->{cpqHeFltTolFanIndex}, $self->{cpqHeFltTolFanLocale});
      $self->add_message(CRITICAL, $self->{info});
    } elsif ($self->{cpqHeFltTolFanCondition} eq 'degraded') {
      $self->add_info(sprintf 'fan %d (%s) degraded',
          $self->{cpqHeFltTolFanIndex}, $self->{cpqHeFltTolFanLocale});
      $self->add_message(WARNING, $self->{info});
    } elsif ($self->{cpqHeFltTolFanCondition} ne 'ok' &&
        $self->{cpqHeFltTolFanCondition} ne 'other') {
      $self->add_info(sprintf 'fan %d (%s) is not ok',
          $self->{cpqHeFltTolFanIndex}, $self->{cpqHeFltTolFanLocale});
      $self->add_message(WARNING, $self->{info});
    }
    if ($self->{cpqHeFltTolFanRedundant} eq 'notRedundant') {
      # sieht so aus, als waere notRedundant und partner=0 normal z.b. dl360
      # das duerfte der fall sein, wenn nur eine cpu verbaut wurde und
      # statt einem redundanten paar nur dummies drinstecken.
      # "This specifies if the fan is in a redundant configuration"
      # notRedundant heisst also sowohl nicht redundant wegen ausfall
      # des partners als auch von haus aus nicht redundant ausgelegt
      if ($self->{cpqHeFltTolFanRedundantPartner}) {
        # nicht redundant, hat aber einen partner. da muss man genauer
        # hinschauen
        #if (my $partner = $self->{partner}) {
        #}
        if ($self->{overallhealth}) {
          # da ist sogar das system der meinung, dass etwas faul ist
          if (! $self->{runtime}->{options}->{ignore_fan_redundancy}) {
            $self->add_info(sprintf 'fan %d (%s) is not redundant',
                $self->{cpqHeFltTolFanIndex}, $self->{cpqHeFltTolFanLocale});
            $self->add_message(WARNING, $self->{info});
          }
        } else {
          # das ist wohl so gewollt, dass einzelne fans eingebaut werden,
          # obwohl redundante paerchen vorgesehen sind.
          # scheint davon abzuhaengen, wieviele cpus geordert wurden.
        }
      }
    } elsif ($self->{cpqHeFltTolFanRedundant} eq 'other') {
      #seen on a dl320 g5p with bios from 2008.
      # maybe redundancy is not supported at all
    }
  } elsif ($self->{cpqHeFltTolFanPresent} eq 'failed') { # from cli
    $self->add_info(sprintf 'fan %d (%s) failed',
        $self->{cpqHeFltTolFanIndex}, $self->{cpqHeFltTolFanLocale});
    $self->add_message(CRITICAL, $self->{info});
  } elsif ($self->{cpqHeFltTolFanPresent} eq 'absent') {
    $self->add_info(sprintf 'fan %d (%s) needs attention (is absent)',
        $self->{cpqHeFltTolFanIndex}, $self->{cpqHeFltTolFanLocale});
    # weiss nicht, ob absent auch kaputt bedeuten kann
    # wenn nicht, dann wuerde man sich hier dumm und daemlich blacklisten
    #$self->add_message(CRITICAL, $self->{info});
    $self->add_message(WARNING, $self->{info}) if $self->{overallhealth};
  }
  if ($self->{runtime}->{options}->{perfdata}) {
    $self->{runtime}->{plugin}->add_perfdata(
        label => sprintf('fan_%s', $self->{cpqHeFltTolFanIndex}),
        value => $self->{cpqHeFltTolFanPctMax},
        uom => '%',
    );
  }
}

sub dump {
  my $self = shift;
  printf "[FAN_%s]\n", $self->{cpqHeFltTolFanIndex};
  foreach (qw(cpqHeFltTolFanChassis cpqHeFltTolFanIndex cpqHeFltTolFanLocale
      cpqHeFltTolFanPresent cpqHeFltTolFanType cpqHeFltTolFanSpeed
      cpqHeFltTolFanRedundant cpqHeFltTolFanRedundantPartner
      cpqHeFltTolFanCondition cpqHeFltTolFanHotPlug)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}


package HP::Proliant::Component::FanSubsystem::Fan::Thermal;
our @ISA = qw(HP::Proliant::Component::FanSubsystem::Fan);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    cpqHeThermalFanIndex => $params{cpqHeThermalFanIndex},
    cpqHeThermalFanRequired => $params{cpqHeThermalFanRequired},
    cpqHeThermalFanPresent => $params{cpqHeThermalFanPresent},
    cpqHeThermalFanCpuFan => $params{cpqHeThermalFanCpuFan},
    cpqHeThermalFanStatus => $params{cpqHeThermalFanStatus},
    cpqHeThermalFanHwLocation => $params{cpqHeThermalFanHwLocation},
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
}

sub dump {
  my $self = shift;
  printf "[FAN_%s]\n", $self->{cpqHeThermalFanIndex};
  foreach (qw(cpqHeThermalFanIndex cpqHeThermalFanRequired 
      cpqHeThermalFanPresent cpqHeThermalFanCpuFan cpqHeThermalFanStatus
      cpqHeThermalFanHwLocation)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}
