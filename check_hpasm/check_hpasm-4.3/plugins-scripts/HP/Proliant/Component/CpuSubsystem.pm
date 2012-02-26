package HP::Proliant::Component::CpuSubsystem;
our @ISA = qw(HP::Proliant::Component);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
################################## scrapiron ##########
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    method => $params{method},
    condition => $params{condition},
    status => $params{status},
    cpus => [],
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  if ($self->{method} eq 'snmp') {
    return HP::Proliant::Component::CpuSubsystem::SNMP->new(%params);
  } elsif ($self->{method} eq 'cli') {
    return HP::Proliant::Component::CpuSubsystem::CLI->new(%params);
  } else {
    die "unknown method";
  }
  return $self;
}

sub check {
  my $self = shift;
  my $errorfound = 0;
  $self->add_info('checking cpus');
  if (scalar (@{$self->{cpus}}) == 0) {
    # sachen gibts.....
  #  $self->overall_check(); # sowas ist mir nur einmal untergekommen
  } else {
    foreach (@{$self->{cpus}}) {
      $_->check();
    }
  }
}

sub num_cpus {
  my $self = shift;
  return scalar @{$self->{cpus}};
}

sub dump {
  my $self = shift;
  foreach (@{$self->{cpus}}) {
    $_->dump();
  }
}


package HP::Proliant::Component::CpuSubsystem::Cpu;
our @ISA = qw(HP::Proliant::Component::CpuSubsystem);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    cpqSeCpuSlot => $params{cpqSeCpuSlot},
    cpqSeCpuUnitIndex => $params{cpqSeCpuUnitIndex},
    cpqSeCpuName => $params{cpqSeCpuName},
    cpqSeCpuStatus => $params{cpqSeCpuStatus},
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('c', $self->{cpqSeCpuUnitIndex});
  if ($self->{cpqSeCpuStatus} ne "ok") {
    if ($self->{runtime}->{options}{scrapiron} &&
        ($self->{cpqSeCpuStatus} eq "unknown")) {
      $self->add_info(sprintf "cpu %d probably ok (%s)",
          $self->{cpqSeCpuUnitIndex}, $self->{cpqSeCpuStatus});
    } else {
      $self->add_info(sprintf "cpu %d needs attention (%s)",
          $self->{cpqSeCpuUnitIndex}, $self->{cpqSeCpuStatus});
      $self->add_message(CRITICAL, $self->{info});
    }
  } else {
    $self->add_info(sprintf "cpu %d is %s", 
        $self->{cpqSeCpuUnitIndex}, $self->{cpqSeCpuStatus});
  }
  $self->add_extendedinfo(sprintf "cpu_%s=%s",
      $self->{cpqSeCpuUnitIndex}, $self->{cpqSeCpuStatus});
}

sub dump {
  my $self = shift;
  printf "[CPU_%s]\n", $self->{cpqSeCpuUnitIndex};
  foreach (qw(cpqSeCpuSlot cpqSeCpuUnitIndex cpqSeCpuName cpqSeCpuStatus)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}
