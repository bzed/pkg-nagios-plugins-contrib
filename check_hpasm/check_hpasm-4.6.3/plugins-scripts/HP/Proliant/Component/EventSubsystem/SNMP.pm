package HP::Proliant::Component::EventSubsystem::SNMP;
our @ISA = qw(HP::Proliant::Component::EventSubsystem
    HP::Proliant::Component::SNMP);

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
  $self->overall_init(%params);
  $self->init(%params);
  return $self;
}

sub overall_init {
  my $self = shift;
  my %params = @_;
  my $snmpwalk = $params{rawdata};
  # overall
  my $cpqHeEventLogSupported  = '1.3.6.1.4.1.232.6.2.11.1.0';
  my $cpqHeEventLogSupportedValue = {
    1 => 'other',
    2 => 'notSupported',
    3 => 'supported',
    4 => 'clear',
  };
  my $cpqHeEventLogCondition  = '1.3.6.1.4.1.232.6.2.11.2.0';
  my $cpqHeEventLogConditionValue = {
    1 => 'other',
    2 => 'ok',
    3 => 'degraded',
    4 => 'failed',
  };
  $self->{eventsupp} = SNMP::Utils::get_object_value(
      $snmpwalk, $cpqHeEventLogSupported,
      $cpqHeEventLogSupportedValue);
  $self->{eventstatus} = SNMP::Utils::get_object_value(
      $snmpwalk, $cpqHeEventLogCondition,
      $cpqHeEventLogConditionValue);
  $self->{eventsupp} |= lc $self->{eventsupp};
  $self->{eventstatus} |= lc $self->{eventstatus};
}

sub init {
  my $self = shift;
  my %params = @_;
  my $snmpwalk = $self->{rawdata};
  my $oids = {
      cpqHeEventLogEntry => "1.3.6.1.4.1.232.6.2.11.3.1",
      cpqHeEventLogEntryNumber => "1.3.6.1.4.1.232.6.2.11.3.1.1",
      cpqHeEventLogEntrySeverity => "1.3.6.1.4.1.232.6.2.11.3.1.2",
      cpqHeEventLogEntryClass => "1.3.6.1.4.1.232.6.2.11.3.1.3",
      cpqHeEventLogEntryCode => "1.3.6.1.4.1.232.6.2.11.3.1.4",
      cpqHeEventLogEntryCount => "1.3.6.1.4.1.232.6.2.11.3.1.5",
      cpqHeEventLogInitialTime => "1.3.6.1.4.1.232.6.2.11.3.1.6",
      cpqHeEventLogUpdateTime => "1.3.6.1.4.1.232.6.2.11.3.1.7",
      cpqHeEventLogErrorDesc => "1.3.6.1.4.1.232.6.2.11.3.1.8",

      cpqHeEventLogEntryClassValue => {
          #  2 Fan Failure (Fan 1, Location I/O Board)
          #    Internal Storage System Overheating (Slot 0, Zone 1, Location Storage, Temperature Unknown)
          #    System Fans Not Redundant (Location I/O Board)
          #  MY MUSTARD: only critical events should lead to an alert, if at all. The caution events mean "loss of redundancy".
          #              We monitor temperatures and fan status anyway.
          #2 => "",
          #  3 Corrected Memory Error threshold exceeded (System Memory, Memory Module 1)
          #    Uncorrectable Memory Error detected by ROM-based memory validation (Board 1, Memory Module 4)
          #  MY MUSTARD: threshold exceeded is caution. Uncorrectable errors are critical. Both should be detected anyway.
          3 => "Main Memory",
          #  4 Accelerator Cache Memory Parity Error (Socket 1)
          #4 => "",
          #  5 Processor Correctable error threshold exceeded (Board 0, Processor 2)
          #5 => "",
          #  6 Unrecoverable Intermodule Bus error (Error code 0x00000000)
          #6 => "",
          #  8 PCI Bus Error (Slot 0, Bus 0, Device 0, Function 0)
          8 => "PCI Bus",
          # 10 1720-S.M.A.R.T. Hard Drive Detects Imminent Failure
          #    POST Error: 201-Memory Error Multi-bit error occurred during memory initialization, Board 1, Bank B. Bank containing DIMM(s) has been disabled..
          #    POST Error: 201-Memory Error Single-bit error occured during memory initialization, Board 1, DIMM 1. Bank containing DIMM(s) has been disabled..
          #    POST Error: 207-Memory Configuration Warning - memory boards should be installed sequentially.
          #    POST Error: 210-Memory Board Failure on board 4.
          #    POST Error: 210-Memory Board Power Fault on board 3.
          #    POST Error: 207-Memory initialization error on Memory Board 5 DIMM 7. The operating system may not have access to all of the memory installed in the system..         
          #    POST Error: 207-Invalid Memory Configuration-Mismatched DIMMs within DIMM Bank Memory in Bank A Not Utilized..
          10 => "POST Messages",
          11 => "Power Subsystem",
          13 => "ASR",
          # 14 Automatic Operating System Shutdown Initiated Due to Overheat Condition
          #    Automatic Operating System Shutdown Initiated Due to Fan Failure
          #    Blue Screen Trap (BugCheck, STOP: 0x00000050 (0x9CB2C5B4, 0x00000001, 0x00000004, 0x00000000))
          #    Operating System failure (BugCheck, STOP: 0x000000AB (0x00000005, 0x00000488, 0x00000000, 0x00000002))
          14 => "OS Class",
          # 15 Unknown Event (Class 15, Code 255)
          #15 => "",
          # 17 Network Adapter Link Down (Slot 0, Port 4)
          #    Network Adapters Redundancy Reduced (Slot 0, Port 1)
          17 => "Network Adapter",
          # 19 Drive Array Device Failure (Slot 0, Bus 2, Bay 4)
          #    Internal SAS Enclosure Device Failure (Bay 1, Box 1, Port 2I, Slot 1)
          #19 => "",
          # 20 An Unrecoverable System Error (NMI) has occurred
          #    Unrecoverable System Error has occurred (Error code 0x01AE0E2F, 0x00000000)
          20 => "Unrecoverable System Error",
          # 32 ROM flashed (New version: 01/09/2008)
          32 => "System Revision",
          # 33 IML Cleared (Administrator)
          #    IML cleared through HP ProLiant Health Agent (cmahealthd)
          #    Insight Diagnostics Note: Physisches Festplattenlaufwerk 5, Controller Steckplatz 0-Diagnosis: Fehlgeschlagen
          33 => "Maintenance Note",
          # 34 New Chassis Connected (Enclosure Address 27AC)
          #    Loss Of Chassis Connectivity (Enclosure Serial Number 8004******)
          #    Server Blade Enclosure Server Blade Inserted (Slot 16, Enclosure Address 0000)
          #34 => "",
      },
      cpqHeEventLogEntrySeverityValue => {
          2 => "informational",
          3 => "infoWithAlert",
          6 => "repaired",
          9 => "caution",
          15 => "critical",
      },
      # Time 
      # 07 D8 09 02 11 11
  };
  # INDEX { cpqHeEventLogEntryNumber }
  foreach ($self->get_entries($oids, 'cpqHeEventLogEntry')) {
    if ($_->{cpqHeEventLogInitialTime} =~ /^(([0-9a-fA-F]{2})( [0-9a-fA-F]{2})*)\s*$/) {
      $_->{cpqHeEventLogInitialTime} =~ s/ //;
      my  ($year, $month, $day, $hour, $min) = map { hex($_) } split(/\s+/, $_->{cpqHeEventLogInitialTime});
      if ($year == 0) {
        $_->{cpqHeEventLogInitialTime} = 0;
      } else {
        eval {
          $_->{cpqHeEventLogInitialTime} = timelocal(0, $min, $hour, $day, $month - 1, $year);
        };
        if ($@) {
          $_->{cpqHeEventLogInitialTime} = 0;
        }
      }
    } elsif ($_->{cpqHeEventLogInitialTime} =~ /^0x([0-9a-fA-F]{4})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})/) {
      my  ($year, $month, $day, $hour, $min) = map { hex($_) } ($1, $2, $3, $4, $5);
      if ($year == 0) {
        $_->{cpqHeEventLogInitialTime} = 0;
      } else {
        eval {
          $_->{cpqHeEventLogInitialTime} = timelocal(0, $min, $hour, $day, $month - 1, $year);
        };
        if ($@) {
          $_->{cpqHeEventLogInitialTime} = 0;
        }
      }
    } elsif ($_->{cpqHeEventLogInitialTime} =~ /^\0\0\0\0\0\0/) {
      $_->{cpqHeEventLogInitialTime} = 0;
    }
    if ($_->{cpqHeEventLogUpdateTime} =~ /^(([0-9a-fA-F]{2})( [0-9a-fA-F]{2})*)\s*$/) {
      $_->{cpqHeEventLogUpdateTime} =~ s/ //;
      my  ($year, $month, $day, $hour, $min) = map { hex($_) } split(/\s+/, $_->{cpqHeEventLogUpdateTime});
      if ($year == 0) {
        $_->{cpqHeEventLogUpdateTime} = 0;
      } else {
        eval {
          $_->{cpqHeEventLogUpdateTime} = timelocal(0, $min, $hour, $day, $month - 1, $year);
        };
        if ($@) {
          $_->{cpqHeEventLogUpdateTime} = 0;
        }
      }
    } elsif ($_->{cpqHeEventLogUpdateTime} =~ /^0x([0-9a-fA-F]{4})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})/) {
      my  ($year, $month, $day, $hour, $min) = map { hex($_) } ($1, $2, $3, $4, $5);
      if ($year == 0) {
        $_->{cpqHeEventLogUpdateTime} = 0;
      } else {
        eval {
          $_->{cpqHeEventLogUpdateTime} = timelocal(0, $min, $hour, $day, $month - 1, $year);
        };
        if ($@) {
          $_->{cpqHeEventLogUpdateTime} = 0;
        }
      }
    } elsif ($_->{cpqHeEventLogUpdateTime} =~ /^\0\0\0\0\0\0/) {
      $_->{cpqHeEventLogUpdateTime} = 0;
    }
    if ($_->{cpqHeEventLogErrorDesc} =~ /^(([0-9a-fA-F]{2})(\s+[0-9a-fA-F]{2})*)\s*$/) {
      $_->{cpqHeEventLogErrorDesc} = join "", map { chr($_) } map { if (hex($_) > 127) { 20; } else { hex($_) } } split(/\s+/, $_->{cpqHeEventLogErrorDesc});
    }
    push(@{$self->{events}},
        HP::Proliant::Component::EventSubsystem::Event->new(%{$_}));
  }
}

sub overall_check {
  my $self = shift;
  my $result = 0;
  $self->blacklist('oe', '');
  if ($self->{eventsupp} && $self->{eventsupp} eq "supported") {
    if ($self->{eventstatus} eq "ok") {
      $result = 0;
      $self->add_info('eventlog system is ok');
    } else {
      $result = 0;
      $self->add_info(sprintf "eventlog system is %s", $self->{eventstatus});
    }
  } else {
    $result = 0;
    $self->add_info('no event status found');
  }
}

1;
