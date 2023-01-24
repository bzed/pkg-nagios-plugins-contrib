package Monitoring::GLPlugin::SNMP::CSF;
#our @ISA = qw(Monitoring::GLPlugin::SNMP);
use Digest::MD5 qw(md5_hex);
use strict;

sub create_statefile {
  my ($self, %params) = @_;
  my $extension = "";
  $extension .= $params{name} ? '_'.$params{name} : '';
  if ($self->opts->community) {
    $extension .= md5_hex($self->opts->community);
  }
  if ($self->opts->contextname) {
    $extension .= $self->opts->contextname;
  }
  $extension =~ s/\//_/g;
  $extension =~ s/\(/_/g;
  $extension =~ s/\)/_/g;
  $extension =~ s/\*/_/g;
  $extension =~ s/\s/_/g;
  if ($self->opts->snmpwalk && ! $self->opts->hostname) {
    return sprintf "%s/%s_%s%s", $self->statefilesdir(),
        'snmpwalk.file'.md5_hex($self->opts->snmpwalk),
        $self->clean_path($self->mode), $self->clean_path(lc $extension);
  } elsif ($self->opts->snmpwalk && $self->opts->hostname eq "walkhost") {
    return sprintf "%s/%s_%s%s", $self->statefilesdir(),
        'snmpwalk.file'.md5_hex($self->opts->snmpwalk),
        $self->clean_path($self->mode), $self->clean_path(lc $extension);
  } else {
    return sprintf "%s/%s_%s%s", $self->statefilesdir(),
        $self->opts->hostname,
        $self->clean_path($self->mode), $self->clean_path(lc $extension);
  }
}

1;

__END__
