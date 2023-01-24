package Monitoring::GLPlugin::SNMP::TableItem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::CSF Monitoring::GLPlugin::TableItem Monitoring::GLPlugin::SNMP);
use strict;

sub ensure_index {
  my ($self, $key) = @_;
  $self->{$key} ||= $self->{flat_indices};
}

sub unhex_ip {
  my ($self, $value) = @_;
  if ($value && $value =~ /^0x(\w{8})/) {
    $value = join(".", unpack "C*", pack "H*", $1);
  } elsif ($value && $value =~ /^0x(\w{2} \w{2} \w{2} \w{2})/) {
    $value = $1;
    $value =~ s/ //g;
    $value = join(".", unpack "C*", pack "H*", $value);
  } elsif ($value && $value =~ /^([A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2})/i) {
    $value = $1;
    $value =~ s/ //g;
    $value = join(".", unpack "C*", pack "H*", $value);
  } elsif ($value && unpack("H8", $value) =~ /(\w{2})(\w{2})(\w{2})(\w{2})/) {
    $value = join(".", map { hex($_) } ($1, $2, $3, $4));
  }
  return $value;
}

sub compact_v6 {
  my ($self, $addr) = @_;

  my @o = split /:/, $addr;
  return $addr unless @o and grep { $_ =~ m/^0+$/ } @o;

  my @candidates	= ();
  my $start		= undef;

  for my $i (0 .. $#o) {
    if (defined $start) {
      if ($o[$i] !~ m/^0+$/) {
        push @candidates, [ $start, $i - $start ];
        $start = undef;
      }
    } else {
      $start = $i if $o[$i] =~ m/^0+$/;
    }
  }

  push @candidates, [$start, 8 - $start] if defined $start;

  my $l = (sort { $b->[1] <=> $a->[1] } @candidates)[0];

  return $addr unless defined $l;

  $addr = $l->[0] == 0 ? '' : join ':', @o[0 .. $l->[0] - 1];
  $addr .= '::';
  $addr .= join ':', @o[$l->[0] + $l->[1] .. $#o];
  $addr =~ s/(^|:)0{1,3}/$1/g;

  return $addr;
}

sub old_unhex_ipv6 {
  my ($self, $value) = @_;
  if (! defined $value) {
    return $value; # tut mir leid
  } elsif ($value =~ /^0x(\w{32})/) {
    $value = join(":", unpack "C*", pack "H*", $1);
  } elsif ($value && $value =~ /^0x(\w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2})/) {
    $value = $1;
    $value =~ s/ //g;
    $value = join(":", unpack "C*", pack "H*", $value);
  } elsif ($value =~ /^([A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2})/i) {
    $value = $1;
    $value =~ s/ //g;
    $value = join(":", unpack "C*", pack "H*", $value);
  } elsif (unpack("H*", $value) =~ /^([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})/i) {
	  #$value = join(":", unpack "C*", pack "H*", $value);
    $value = join(":", ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16));
  }
  return $self->compact_v6($value);
}

sub unhex_ipv6 {
  my ($self, $value) = @_;
  my @octets = ();
  if (! defined $value) {
    return $value; # tut mir leid
  } elsif ($value =~ /^0x(\w{32})/) {
    @octets = unpack "H2" x 16, pack "H*", $1;
  } elsif ($value && $value =~ /^0x(\w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2} \w{2})/) {
    $value = $1;
    @octets = split(" ", $value);
  } elsif ($value =~ /^([A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2} [A-Z0-9]{2})/i) {
    $value = $1;
    $value =~ s/ //g;
    @octets = unpack "H2" x 16, pack "H*", $value;
  } elsif (unpack("H*", $value) =~ /^([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})/i) {
    @octets = ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16);
  }
  $value = join(":",
      map { my $idx = 2*$_; $octets[$idx].$octets[$idx+1] } (0..7)
  );
  return $value;
  return $self->compact_v6($value);
}

sub unhex_mac {
  my ($self, $value) = @_;
  if ($value && $value =~ /^0x(\w{12})/) {
    $value = join(".", unpack "C*", pack "H*", $1);
  } elsif ($value && $value =~ /^0x(\w{2}\s*\w{2}\s*\w{2}\s*\w{2}\s*\w{2}\s*\w{2})/) {
    $value = $1;
    $value =~ s/ //g;
    $value = join(":", unpack "C*", pack "H*", $value);
  } elsif ($value && unpack("H12", $value) =~ /(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})/) {
    $value = join(":", ($1, $2, $3, $4, $5, $6));
  }
  return $value;
}

sub unhex_octet_string {
  my ($self, $value) = @_;
  my $original = $value;
  $value =~ s/ //g;
  if ($value && $value =~ /^0x([0-9a-zA-Z]+)$/) {
    $value = join("", unpack "A*", pack "H*", $1);
  } elsif ($value && $value =~ /^([0-9a-zA-Z]+)$/) {
    $value = join("", unpack "A*", pack "H*", $1);
  } else {
    $value = $original;
  }
  return $value;
}

1;

__END__
