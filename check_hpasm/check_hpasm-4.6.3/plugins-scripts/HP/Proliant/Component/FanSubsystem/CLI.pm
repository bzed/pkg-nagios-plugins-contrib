package HP::Proliant::Component::FanSubsystem::CLI;
our @ISA = qw(HP::Proliant::Component::FanSubsystem);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    fans => [],
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  $self->init(%params);
  return $self;
}

# partner not available = cpqHeFltTolFanRedundantPartner=0
# cpqHeFltTolFanTypeValue = other
sub init {
  my $self = shift;
  my %params = @_;
  my %tmpfan = ();
  foreach (grep(/^fans/, split(/\n/, $self->{rawdata}))) {
    s/^fans //g;
    if (/^#(\d+)\s+([\w#_\/\-]+)\s+(\w+)\s+(\w+)\s+(FAILED|[N\/A\d]+)%*\s+([\w\/]+)\s+(FAILED|[N\/A\d]+)\s+(\w+)/) {
      %tmpfan = (
          cpqHeFltTolFanIndex => $1, 
          cpqHeFltTolFanLocale => lc $2,
          cpqHeFltTolFanPresent => lc $3,
          cpqHeFltTolFanSpeed => lc $4,
          cpqHeFltTolFanPctMax => lc $5,                 # (FAILED|[N\/A\d]+)
          cpqHeFltTolFanRedundant => lc $6,
          cpqHeFltTolFanRedundantPartner => lc $7,       # (FAILED|[N\/A\d]+)
          cpqHeFltTolFanHotPlug => lc $8,
      ); 
    } elsif (/^#(\d+)\s+([\w#_\/\-]+?)(Yes|No|N\/A)\s+(\w+)\s+(FAILED|[N\/A\d]+)%*\s+([\w\/]+)\s+(FAILED|[N\/A\d]+)\s+(\w+)/) { 
      # #5   SCSI_BACKPLANE_ZONEYes     NORMAL N/A  .... 
      %tmpfan = (
          cpqHeFltTolFanIndex => $1,
          cpqHeFltTolFanLocale => lc $2,
          cpqHeFltTolFanPresent => lc $3,
          cpqHeFltTolFanSpeed => lc $4, 
          cpqHeFltTolFanPctMax => lc $5,
          cpqHeFltTolFanRedundant => lc $6,
          cpqHeFltTolFanRedundantPartner => lc $7,
          cpqHeFltTolFanHotPlug => lc $8,
      );
    } elsif (/^#(\d+)\s+([\w#_\/\-]+)\s+[NOno]+\s/) {
      # Fan is not installed. #2   CPU#2   No   -   -    No      N/A      -
    } elsif (/^#(\d+)/) {
      main::contact_author("FAN", $_); 
    }
    if (%tmpfan) {
      $tmpfan{runtime} = $params{runtime};
      $tmpfan{cpqHeFltTolFanChassis} = 1; # geht aus hpasmcli nicht hervor
      $tmpfan{cpqHeFltTolFanType} = 'other';
      if ($tmpfan{cpqHeFltTolFanPctMax} !~ /^\d+$/) {
        if ($tmpfan{cpqHeFltTolFanSpeed} eq 'normal') {
          $tmpfan{cpqHeFltTolFanPctMax} = 50;
        } elsif ($tmpfan{cpqHeFltTolFanSpeed} eq 'high') {
          $tmpfan{cpqHeFltTolFanPctMax} = 100;
        } else {
          $tmpfan{cpqHeFltTolFanPctMax} = 0;
        }
      }
      if($tmpfan{cpqHeFltTolFanSpeed} eq 'failed') {
        $tmpfan{cpqHeFltTolFanCondition} = 'failed';
      } elsif($tmpfan{cpqHeFltTolFanSpeed} eq 'n/a') {
        $tmpfan{cpqHeFltTolFanCondition} = 'other';
      } else {
        $tmpfan{cpqHeFltTolFanCondition} = 'ok';
      }
      $tmpfan{cpqHeFltTolFanRedundant} = 
          $tmpfan{cpqHeFltTolFanRedundant} eq 'yes' ? 'redundant' :
          $tmpfan{cpqHeFltTolFanRedundant} eq 'no' ? 'notRedundant' : 'other';
      $tmpfan{cpqHeFltTolFanPresent} = 
          $tmpfan{cpqHeFltTolFanPresent} eq 'yes' ? 'present' :
          $tmpfan{cpqHeFltTolFanPresent} eq 'failed' ? 'present' :
          $tmpfan{cpqHeFltTolFanPresent} eq 'no' ? 'absent' : 'other';
      $tmpfan{cpqHeFltTolFanHotPlug} = 
          $tmpfan{cpqHeFltTolFanHotPlug} eq 'yes' ? 'hotPluggable' :
          $tmpfan{cpqHeFltTolFanHotPlug} eq 'no' ? 'nonHotPluggable' : 'other';
      push(@{$self->{fans}},
          HP::Proliant::Component::FanSubsystem::Fan->new(%tmpfan));
      %tmpfan = ();
    }
  }
}

sub overall_check {
  my $self = shift;
  # nix. nur wegen der gleichheit mit snmp
  return 0;
}
1;
