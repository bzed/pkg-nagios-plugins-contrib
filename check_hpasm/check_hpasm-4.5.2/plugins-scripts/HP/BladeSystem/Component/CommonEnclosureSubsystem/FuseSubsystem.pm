package HP::BladeSystem::Component::CommonEnclosureSubsystem::FuseSubsystem;
our @ISA = qw(HP::BladeSystem::Component::CommonEnclosureSubsystem);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    method => $params{method},
    blacklisted => 0,
    fuses => [],
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  $self->init();
  return $self;
}

sub init {
  my $self = shift;
  my $oids = {
      cpqRackCommonEnclosureFuseEntry => '1.3.6.1.4.1.232.22.2.3.1.4.1',
      cpqRackCommonEnclosureFuseRack => '1.3.6.1.4.1.232.22.2.3.1.4.1.1',
      cpqRackCommonEnclosureFuseChassis => '1.3.6.1.4.1.232.22.2.3.1.4.1.2',
      cpqRackCommonEnclosureFuseIndex => '1.3.6.1.4.1.232.22.2.3.1.4.1.3',
      cpqRackCommonEnclosureFuseEnclosureName => '1.3.6.1.4.1.232.22.2.3.1.4.1.4',
      cpqRackCommonEnclosureFuseLocation => '1.3.6.1.4.1.232.22.2.3.1.4.1.5',
      cpqRackCommonEnclosureFusePresent => '1.3.6.1.4.1.232.22.2.3.1.4.1.8',
      cpqRackCommonEnclosureFuseCondition => '1.3.6.1.4.1.232.22.2.3.1.4.1.11',
      cpqRackCommonEnclosureFusePresentValue => {
          1 => 'other',
          2 => 'absent',
          3 => 'present',
      },
      cpqRackCommonEnclosureFuseConditionValue => {
          1 => 'other',
          2 => 'ok',
          4 => 'failed',
      }
  };
  # INDEX { cpqRackCommonEnclosureFuseRack, cpqRackCommonEnclosureFuseChassis, cpqRackCommonEnclosureFuseIndex }
  foreach ($self->get_entries($oids, 'cpqRackCommonEnclosureFuseEntry')) {
    push(@{$self->{fuses}},
        HP::BladeSystem::Component::CommonEnclosureSubsystem::FuseSubsystem::Fuse->new(%{$_}));
  }

}

sub check {
  my $self = shift;
  foreach (@{$self->{fuses}}) {
    $_->check() if $_->{cpqRackCommonEnclosureFusePresent} eq 'present' ||
        $self->{runtime}->{options}->{verbose} >= 3; # absent nur bei -vvv
  }
}

sub dump {
  my $self = shift;
  foreach (@{$self->{fuses}}) {
    $_->dump() if $_->{cpqRackCommonEnclosureFusePresent} eq 'present' ||
        $self->{runtime}->{options}->{verbose} >= 3; # absent nur bei -vvv
  }
}


package HP::BladeSystem::Component::CommonEnclosureSubsystem::FuseSubsystem::Fuse;

our @ISA = qw(HP::BladeSystem::Component::CommonEnclosureSubsystem::FuseSubsystem);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    method => $params{method},
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  map { $self->{$_} = $params{$_} } grep /cpqRackCommonEnclosureFuse/, keys %params;
  $self->{name} = $self->{cpqRackCommonEnclosureFuseRack}.':'.$self->{cpqRackCommonEnclosureFuseChassis}.':'.$self->{cpqRackCommonEnclosureFuseIndex};
  bless $self, $class;
  return $self;
}

sub check {
  my $self = shift;
  $self->blacklist('fu', $self->{name});
  $self->add_info(sprintf 'fuse %s is %s, location is %s, condition is %s',
      $self->{name}, $self->{cpqRackCommonEnclosureFusePresent},
      $self->{cpqRackCommonEnclosureFuseLocation}, $self->{cpqRackCommonEnclosureFuseCondition});
  if ($self->{cpqRackCommonEnclosureFuseCondition} eq 'failed') {
    $self->add_message(CRITICAL, $self->{info});
  } elsif ($self->{cpqRackCommonEnclosureFuseCondition} ne 'ok') {
    $self->add_message(WARNING, $self->{info});
  }
}

sub dump {
  my $self = shift;
  printf "[FUSE_%s]\n", $self->{name};
  foreach (qw(cpqRackCommonEnclosureFuseRack cpqRackCommonEnclosureFuseChassis 
      cpqRackCommonEnclosureFuseIndex cpqRackCommonEnclosureFuseEnclosureName 
      cpqRackCommonEnclosureFuseLocation cpqRackCommonEnclosureFusePresent 
      cpqRackCommonEnclosureFuseCondition)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}

1;
