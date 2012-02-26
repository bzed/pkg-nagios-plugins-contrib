package SNMP::Utils;

use strict;

{
  sub get_indices {
    my $oids = shift;
    my $entry = shift;
    my $numindices = shift;
    # find all oids beginning with $entry
    # then skip one field for the sequence
    # then read the next numindices fields
    my $entrypat = $entry;
    $entrypat =~ s/\./\\\./g;
    my @indices = map {
        /^$entrypat\.\d+\.(.*)/ && $1;
    } grep {
        /^$entrypat/
    } keys %{$oids};
    my %seen = ();
    my @o = map {[split /\./]} sort grep !$seen{$_}++, @indices;
    return @o;
  }

  sub get_size {
    my $oids = shift;
    my $entry = shift;
    my $entrypat = $entry;
    $entrypat =~ s/\./\\\./g;
    my @entries = grep {
        /^$entrypat/
    } keys %{$oids};
    return scalar(@entries);
  }

  sub get_object {
    my $oids = shift;
    my $object = shift;
    my @indices = @_;
    #my $oid = $object.'.'.join('.', @indices);
    my $oid = $object;
    $oid .= '.'.join('.', @indices) if (@indices);
    return $oids->{$oid};
  }

  sub get_object_value {
    my $oids = shift;
    my $object = shift;
    my $values = shift;
    my @indices = @_;
    my $key = get_object($oids, $object, @indices);
    if (defined $key) {
      return $values->{$key};
    } else {
      return undef;
    }
  }

  #SNMP::Utils::counter([$idxs1, $idxs2], $idx1, $idx2),
  # this flattens a n-dimensional array and returns the absolute position
  # of the element at position idx1,idx2,...,idxn
  # element 1,2 in table 0,0 0,1 0,2 1,0 1,1 1,2 2,0 2,1 2,2 is at pos 6
  sub get_number {
    my $indexlists = shift; #, zeiger auf array aus [1, 2]
    my @element = @_;
    my $dimensions = scalar(@{$indexlists->[0]});
    my @sorted = ();
    my $number = 0;
    if ($dimensions == 1) {
      @sorted =
          sort { $a->[0] <=> $b->[0] } @{$indexlists};
    } elsif ($dimensions == 2) {
      @sorted =
          sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } @{$indexlists};
    } elsif ($dimensions == 3) {
      @sorted =
          sort { $a->[0] <=> $b->[0] || 
                 $a->[1] <=> $b->[1] ||
                 $a->[2] <=> $b->[2] } @{$indexlists};
    }
    foreach (@sorted) {
      if ($dimensions == 1) {
        if ($_->[0] == $element[0]) {
          last;
        }
      } elsif ($dimensions == 2) {
        if ($_->[0] == $element[0] && $_->[1] == $element[1]) {
          last;
        }
      } elsif ($dimensions == 3) {
        if ($_->[0] == $element[0] && 
            $_->[1] == $element[1] &&
            $_->[2] == $element[2]) {
          last;
        }
      }
      $number++;
    }
    return ++$number;
  }

}

