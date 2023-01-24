package Monitoring::GLPlugin::TableItem;
our @ISA = qw(Monitoring::GLPlugin::Item);

use strict;

sub new {
  my ($class, %params) = @_;
  my $self = {};
  bless $self, $class;
  foreach (keys %params) {
    $self->{$_} = $params{$_};
  }
  if ($self->can("finish")) {
    $self->finish(%params);
  }
  return $self;
}

sub check {
  my ($self) = @_;
  # some tableitems are not checkable, they are only used to enhance other
  # items (e.g. sensorthresholds enhance sensors)
  # normal tableitems should have their own check-method
}

1;

__END__
