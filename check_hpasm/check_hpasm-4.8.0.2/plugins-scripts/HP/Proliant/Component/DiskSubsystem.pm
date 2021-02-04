package HP::Proliant::Component::DiskSubsystem;
our @ISA = qw(HP::Proliant::Component);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    rawdata => $params{rawdata},
    method => $params{method},
    da_subsystem => undef,
    sas_da_subsystem => undef,
    ide_da_subsystem => undef,
    fca_da_subsystem => undef,
    scsi_da_subsystem => undef,
    condition => $params{condition},
    blacklisted => 0,
  };
  bless $self, $class;
  $self->init();
  return $self;
}

sub init {
  my $self = shift;
  $self->{da_subsystem} = HP::Proliant::Component::DiskSubsystem::Da->new(
    runtime => $self->{runtime},
    rawdata => $self->{rawdata},
    method => $self->{method},
  );
  $self->{sas_subsystem} = HP::Proliant::Component::DiskSubsystem::Sas->new(
    runtime => $self->{runtime},
    rawdata => $self->{rawdata},
    method => $self->{method},
  );
  $self->{scsi_subsystem} = HP::Proliant::Component::DiskSubsystem::Scsi->new(
    runtime => $self->{runtime},
    rawdata => $self->{rawdata},
    method => $self->{method},
  );
  $self->{ide_subsystem} = HP::Proliant::Component::DiskSubsystem::Ide->new(
    runtime => $self->{runtime},
    rawdata => $self->{rawdata},
    method => $self->{method},
  );
  $self->{fca_subsystem} = HP::Proliant::Component::DiskSubsystem::Fca->new(
    runtime => $self->{runtime},
    rawdata => $self->{rawdata},
    method => $self->{method},
  );
}

sub check {
  my $self = shift;
  $self->add_info('checking disk subsystem');
  $self->{da_subsystem}->check();
  $self->{sas_subsystem}->check();
  $self->{scsi_subsystem}->check();
  $self->{ide_subsystem}->check();
  $self->{fca_subsystem}->check();
  $self->disk_summary();
}

sub dump {
  my $self = shift;
  $self->{da_subsystem}->dump();
  $self->{sas_subsystem}->dump();
  $self->{scsi_subsystem}->dump();
  $self->{ide_subsystem}->dump();
  $self->{fca_subsystem}->dump();
}

sub disk_summary {
  my $self = shift;
  foreach my $subsys (qw(da sas scsi ide fca)) {
    if (my $pd = $self->{$subsys.'_subsystem'}->has_physical_drives()) {
      my $ld = $self->{$subsys.'_subsystem'}->has_logical_drives();
      $self->add_summary(sprintf '%s: %d logical drives, %d physical drives',
          $subsys, $ld, $pd);
    }
  }
}

sub assemble {
  my $self = shift;
  $self->trace(3, sprintf "%s controllers und platten zusammenfuehren",
      ref($self));
  $self->trace(3, sprintf "has %d controllers",
      scalar(@{$self->{controllers}}));
  $self->trace(3, sprintf "has %d accelerators",
      scalar(@{$self->{accelerators}})) if exists $self->{accelerators};
  $self->trace(3, sprintf "has %d enclosures",
      scalar(@{$self->{enclosures}}));
  $self->trace(3, sprintf "has %d physical_drives",
      scalar(@{$self->{physical_drives}}));
  $self->trace(3, sprintf "has %d logical_drives",
      scalar(@{$self->{logical_drives}}));
  $self->trace(3, sprintf "has %d spare_drives",
      scalar(@{$self->{spare_drives}}));
  my $found = {
      accelerators => {},
      enclosures => {},
      logical_drives => {},
      physical_drives => {},
      spare_drives => {},
  };
  # found->{komponente}->{controllerindex} ist ein array
  # von teilen, die zu einem controller gehoeren
  foreach my $item (qw(accelerators enclosures logical_drives physical_drives spare_drives)) {
    next if ($item eq "enclosures" && ! exists $self->{$item});
    foreach (@{$self->{$item}}) {
      $found->{item}->{$_->{controllerindex}} = []
          unless exists $found->{$item}->{$_->{controllerindex}};
      push(@{$found->{$item}->{$_->{controllerindex}}}, $_);
    }
  }
  foreach my $item (qw(accelerators enclosures logical_drives physical_drives spare_drives)) {
    foreach (@{$self->{controllers}}) {
      if (exists $found->{$item}->{$_->{controllerindex}}) {
        $_->{$item} = $found->{$item}->{$_->{controllerindex}};
        delete $found->{$item}->{$_->{controllerindex}};
      } else {
        $_->{$item} = []; # z.b. ein leerer controller: physical_drives = []
      }
    }
  }
  # was jetzt noch in $found uebrig ist, gehoert zu keinem controller
  # d.h. komponenten mit ungueltigen cnrtlindex wurden gefunden
}

sub has_controllers {
  my $self = shift;
  return scalar(@{$self->{controllers}});
}

sub has_accelerators {
  my $self = shift;
  return exists $self->{accelerators} ? scalar(@{$self->{accelerators}}) : 0;
}

sub has_physical_drives {
  my $self = shift;
  return scalar(@{$self->{physical_drives}});
}

sub has_logical_drives {
  my $self = shift;
  return scalar(@{$self->{logical_drives}});
}

sub has_enclosures {
  my $self = shift;
  return scalar(@{$self->{enclosures}});
}

1;
