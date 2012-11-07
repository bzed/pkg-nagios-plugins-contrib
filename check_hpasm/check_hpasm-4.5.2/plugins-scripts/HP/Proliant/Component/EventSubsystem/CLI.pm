package HP::Proliant::Component::EventSubsystem::CLI;
our @ISA = qw(HP::Proliant::Component::EventSubsystem);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };
use Time::Local;

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    events => [],
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  $self->init(%params);
  return $self;
}


sub init {
  my $self = shift;
  my %params = @_;
  my %tmpevent = (
    runtime => $params{runtime},
  );
  my $inblock = 0;
  foreach (grep(/^iml/, split(/\n/, $self->{rawdata}))) {
    s/^iml\s*//g;
    if (/^Event:\s+(\d+)\s+[\w]+:\s+(\d+)\/(\d+)\/(\d+)\s+(\d+):(\d+)/) {
      # Event: 31 Added: 09/22/2011 05:11
      #         1         2  3    4  5  6
      $tmpevent{cpqHeEventLogEntryNumber} = $1;
      if ($4 == 0) {
        # Event: 29 Added: 00/00/0000 00:00
        $tmpevent{cpqHeEventLogUpdateTime} = 0;
      } else {
        eval {
          $tmpevent{cpqHeEventLogUpdateTime} = timelocal(0, $6, $5, $3, $2 - 1, $4);
        };
        if ($@) {
          # Event: 10 Added: 27/27/2027 27:27
          $tmpevent{cpqHeEventLogUpdateTime} = 0;
        }
      }
      $inblock = 1;
    } elsif (/^(\w+):\s+(.*?)\s+\-\s+(.*)/) {
      $tmpevent{cpqHeEventLogEntrySeverity} = $1;
      $tmpevent{cpqHeEventLogEntryClass} = $2;
      $tmpevent{cpqHeEventLogErrorDesc} = $3;
      if ($tmpevent{cpqHeEventLogErrorDesc} =~ /.*?:\s+(\d+)/) {
          $tmpevent{cpqHeEventLogEntryCode} = $1;
      } else {
          $tmpevent{cpqHeEventLogEntryCode} = 0;
      }
    } elsif (/^\s*$/) {
      if ($inblock) {
        $inblock = 0;
        push(@{$self->{events}},
            HP::Proliant::Component::EventSubsystem::Event->new(%tmpevent));
        %tmpevent = (
          runtime => $params{runtime},
        );
      }
    }
  }
  if ($inblock) {
    push(@{$self->{events}},
        HP::Proliant::Component::EventSubsystem::Event->new(%tmpevent));
  }
}

1;

