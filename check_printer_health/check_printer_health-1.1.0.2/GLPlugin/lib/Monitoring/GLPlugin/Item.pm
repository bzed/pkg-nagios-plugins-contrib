package Monitoring::GLPlugin::Item;
our @ISA = qw(Monitoring::GLPlugin);

use strict;

sub new {
  my ($class, %params) = @_;
  my $self = {
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  $self->init(%params);
  return $self;
}

sub check {
  my ($self, $lists) = @_;
  my @lists = $lists ? @{$lists} : grep { ref($self->{$_}) eq "ARRAY" } keys %{$self};
  foreach my $list (@lists) {
    $self->add_info('checking '.$list);
    foreach my $element (@{$self->{$list}}) {
      $element->blacklist() if $self->is_blacklisted();
      $element->check();
    }
  }
}

sub init_subsystems {
  my ($self, $subsysref) = @_;
  foreach (@{$subsysref}) {
    my ($subsys, $class) = @{$_};
    $self->{$subsys} = $class->new()
        if (! $self->opts->subsystem || grep {
            $_ eq $subsys;
        } map {
            s/^\s+|\s+$//g;
            $_;
        } split /,/, $self->opts->subsystem);
  }
}

sub check_subsystems {
  my ($self) = @_;
  my @subsystems = grep { $_ =~ /.*_subsystem$/ } keys %{$self};
  foreach (@subsystems) {
    $self->{$_}->check();
  }
  $self->reduce_messages_short(join(", ",
      map {
          sprintf "%s working fine", $_;
      } map {
          s/^\s+|\s+$//g;
          $_;
      } split /,/, $self->opts->subsystem
  )) if $self->opts->subsystem;
}

sub dump_subsystems {
  my ($self) = @_;
  my @subsystems = grep { $_ =~ /.*_subsystem$/ } keys %{$self};
  foreach (@subsystems) {
    $self->{$_}->dump();
  }
}

1;

__END__
