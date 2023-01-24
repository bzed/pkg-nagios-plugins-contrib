package Classes::Device;
our @ISA = qw(Monitoring::GLPlugin::SNMP);
use strict;

sub classify {
  my $self = shift;
  if (! ($self->opts->hostname || $self->opts->snmpwalk)) {
    $self->add_unknown('either specify a hostname or a snmpwalk file');
  } else {
    $self->check_snmp_and_model();
    if (! $self->check_messages()) {
      if ($self->opts->verbose && $self->opts->verbose) {
        printf "I am a %s\n", $self->{productname};
      }
      if ($self->opts->mode =~ /^my-/) {
        $self->load_my_extension();
      } elsif ($self->implements_mib('LEXMARK-PVT-MIB')) {
        bless $self, 'Classes::Lexmark';
        $self->debug('using Classes::Lexmark');
      } elsif ($self->implements_mib('PRINTER-MIB')) {
        bless $self, 'Classes::PRINTERMIB';
        $self->debug('using Classes::PRINTERMIB');
      } elsif ($self->implements_mib('HOST-RESOURCES-MIB')) {
        bless $self, 'Classes::HOSTRESOURCESMIB';
        $self->debug('using Classes::HOSTRESOURCESMIB');
      } elsif ($self->implements_mib('KYOCERA-Private-MIB')) {
        bless $self, 'Classes::Kyocera';
        $self->debug('using Classes::Kyocera');
      } elsif ($self->implements_mib('BROTHER-MIB')) {
        bless $self, 'Classes::Brother';
        $self->debug('using Classes::Brother');
      } else {
        if (my $class = $self->discover_suitable_class()) {
          bless $self, $class;
          $self->debug('using '.$class);
        } else {
          bless $self, 'Classes::Generic';
          $self->debug('using Classes::Generic');
        }
      }
    }
  }
  return $self;
}


package Classes::Generic;
our @ISA = qw(Classes::Device);
use strict;

sub init {
  my $self = shift;
  if ($self->mode =~ /something specific/) {
  } else {
    bless $self, 'Monitoring::GLPlugin::SNMP';
    $self->no_such_mode();
  }
}
