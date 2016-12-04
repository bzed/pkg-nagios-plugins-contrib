package HP::Proliant::Component::AsrSubsystem::SNMP;
our @ISA = qw(HP::Proliant::Component::AsrSubsystem
    HP::Proliant::Component::SNMP);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  $self->overall_init(%params);
  return $self;
}

sub overall_init {
  my $self = shift;
  my %params = @_;
  my $snmpwalk = $params{rawdata};
  my $cpqHeAsrStatus = "1.3.6.1.4.1.232.6.2.5.1.0";
  my $cpqHeAsrStatusValue = {
    1 => "other",
    2 => "notAvailable",
    3 => "disabled",
    4 => "enabled",
  };
  my $cpqHeAsrCondition = "1.3.6.1.4.1.232.6.2.5.17.0";
  my $cpqHeAsrConditionValue = {
    1 => "other",
    2 => "ok",
    3 => "degraded",
    4 => "failed",
  };
  $self->{asrcondition} = SNMP::Utils::get_object_value(
      $snmpwalk, $cpqHeAsrCondition,
      $cpqHeAsrConditionValue);
  $self->{asrstatus} = SNMP::Utils::get_object_value(
      $snmpwalk, $cpqHeAsrStatus,
      $cpqHeAsrStatusValue);
  $self->{asrcondition} |= lc $self->{asrcondition};
  $self->{asrstatus} |= lc $self->{asrstatus};
}

sub overall_check {
  my $self = shift;
  my $result = 0;
  $self->blacklist('asr', '');
  if ($self->{asrstatus} and $self->{asrstatus} eq "enabled") {
    my $info = sprintf 'ASR overall condition is %s', $self->{asrcondition};
    if ($self->{asrcondition} eq "degraded") {
      $self->add_message(WARNING, $info);
    } elsif ($self->{asrcondition} eq "failed") {
      $self->add_message(CRITICAL, $info);
    }
    $self->add_info($info);
  } else {
    $self->add_info('This system does not have ASR.');
  }
}

1;
