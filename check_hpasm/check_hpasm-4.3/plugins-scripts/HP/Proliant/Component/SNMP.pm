package HP::Proliant::Component::SNMP;

sub get_entries {
  my $self = shift;
  my $oids = shift;
  my $entry = shift;
  my $snmpwalk = $self->{rawdata};
  my @params = ();
  my @indices = SNMP::Utils::get_indices($snmpwalk, $oids->{$entry});
  foreach (@indices) {
    my @idx = @{$_};
    my %params = ( 
      runtime => $self->{runtime},
    );
    my $maxdimension = scalar(@idx) - 1;
    foreach my $idxnr (1..scalar(@idx)) {
      $params{'index'.$idxnr} = $_->[$idxnr - 1];
    }
    foreach my $oid (keys %{$oids}) {
      next if $oid =~ /Entry$/;
      next if $oid =~ /Value$/;
      if (exists $oids->{$oid.'Value'}) {
        $params{$oid} = SNMP::Utils::get_object_value(
            $snmpwalk, $oids->{$oid}, $oids->{$oid.'Value'}, @idx);
        if (! defined  $params{$oid}) {
          my $numerical_value = SNMP::Utils::get_object(
              $snmpwalk, $oids->{$oid}, @idx);
          if (! defined $numerical_value) {
            # maschine liefert schrott
            $params{$oid} = 'value_unknown';
          } else {
            $params{$oid} = 'value_'.SNMP::Utils::get_object(
                $snmpwalk, $oids->{$oid}, @idx);
          }
        }
      } else {  
        $params{$oid} = SNMP::Utils::get_object(
            $snmpwalk, $oids->{$oid}, @idx);
      }         
    }     
    push(@params, \%params);
  }
  return @params;
}

sub mib {
  my $self = shift;
  my $mib = shift;
  my $condition = {
      0 => 'other',
      1 => 'ok',
      2 => 'degraded',
      3 => 'failed',
  };
  my $MibRevMajor = $mib.'.1.0';
  my $MibRevMinor = $mib.'.2.0';
  my $MibRevCondition = $mib.'.3.0';
  return (
      $self->SNMP::Utils::get_object($self->{rawdata},
          $MibRevMajor),
      $self->SNMP::Utils::get_object($self->{rawdata},
          $MibRevMinor),
      $self->SNMP::Utils::get_object_value($self->{rawdata},
          $MibRevCondition, $condition));
};

1;
