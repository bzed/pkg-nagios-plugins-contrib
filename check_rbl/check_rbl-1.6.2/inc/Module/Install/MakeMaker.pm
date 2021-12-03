#line 1
package Module::Install::MakeMaker;

use strict;
use ExtUtils::MakeMaker   ();
use Module::Install::Base ();

use vars qw{$VERSION @ISA $ISCORE};
BEGIN {
	$VERSION = '1.18';
	@ISA     = 'Module::Install::Base';
	$ISCORE  = 1;
}

my $makefile = undef;

sub WriteMakefile {
    my ($self, %args) = @_;
    $makefile = $self->load('Makefile');

    # mapping between MakeMaker and META.yml keys
    $args{MODULE_NAME} = $args{NAME};
    unless ( $args{NAME} = $args{DISTNAME} or ! $args{MODULE_NAME} ) {
        $args{NAME} = $args{MODULE_NAME};
        $args{NAME} =~ s/::/-/g;
    }

    foreach my $key ( qw{name module_name version version_from abstract author installdirs} ) {
        my $value = delete($args{uc($key)}) or next;
        $self->$key($value);
    }

    if (my $prereq = delete($args{PREREQ_PM})) {
        while (my($k,$v) = each %$prereq) {
            $self->requires($k,$v);
        }
    }

    if (my $prereq = delete($args{BUILD_REQUIRES})) {
        while (my($k,$v) = each %$prereq) {
            $self->build_requires($k,$v);
        }
    }

    # put the remaining args to makemaker_args
    $self->makemaker_args(%args);
}

END {
    if ( $makefile ) {
        $makefile->write;
        $makefile->Meta->write;
    }
}

1;
