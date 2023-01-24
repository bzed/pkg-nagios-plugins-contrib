package Monitoring::GLPlugin;

=head1 Monitoring::GLPlugin

Monitoring::GLPlugin - infrastructure functions to build a monitoring plugin

=cut

use strict;
use IO::File;
use File::Basename;
use Digest::MD5 qw(md5_hex);
use Errno;
use JSON;
use File::Slurp qw(read_file);
use Data::Dumper;
$Data::Dumper::Indent = 1;
eval {
  # avoid "used only once" because older Data::Dumper don't have this
  # use OMD please because OMD has everything!
  no warnings 'all';
  $Data::Dumper::Sparseseen = 1;
};
our $AUTOLOAD;
*VERSION = \'5.5';

use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

{
  our $mode = undef;
  our $plugin = undef;
  our $pluginname = basename($ENV{'NAGIOS_PLUGIN'} || $0);
  our $blacklist = undef;
  our $info = [];
  our $extendedinfo = [];
  our $summary = [];
  our $variables = {};
  our $survive_sudo_env = ["LD_LIBRARY_PATH", "SHLIB_PATH"];
}

sub new {
  my ($class, %params) = @_;
  my $self = {};
  bless $self, $class;
  require Monitoring::GLPlugin::Commandline
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::Commandline::;
  require Monitoring::GLPlugin::Item
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::Item::;
  require Monitoring::GLPlugin::TableItem
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::TableItem::;
  $Monitoring::GLPlugin::plugin = Monitoring::GLPlugin::Commandline->new(%params);
  return $self;
}

sub rebless {
  my ($self, $class) = @_;
  bless $self, $class;
  $self->debug('using '.$class);
  # gilt nur fuer "echte" Fabrikate mit "Classes::" vorndran
  $self->{classified_as} = ref($self) if $class !~ /^Monitoring::GLPlugin/;
}

sub init {
  my ($self) = @_;
  if ($self->opts->can("blacklist") && $self->opts->blacklist &&
      -f $self->opts->blacklist) {
    $self->opts->blacklist = do {
        local (@ARGV, $/) = $self->opts->blacklist; <> };
  }
}

sub dumper {
  my ($self, $object) = @_;
  my $run = $object->{runtime};
  delete $object->{runtime};
  printf STDERR "%s\n", Data::Dumper::Dumper($object);
  $object->{runtime} = $run;
}

sub no_such_mode {
  my ($self) = @_;
  $self->nagios_exit(3,
      sprintf "Mode %s is not implemented for this type of device",
      $self->opts->mode
  );
  exit 3;
}

#########################################################
# framework-related. setup, options
#
sub add_default_args {
  my ($self) = @_;
  $self->add_arg(
      spec => 'mode=s',
      help => "--mode
   A keyword which tells the plugin what to do",
      required => 1,
  );
  $self->add_arg(
      spec => 'regexp',
      help => "--regexp
   Parameter name/name2/name3 will be interpreted as (perl) regular expression",
      required => 0,);
  $self->add_arg(
      spec => 'warning=s',
      help => "--warning
   The warning threshold",
      required => 0,);
  $self->add_arg(
      spec => 'critical=s',
      help => "--critical
   The critical threshold",
      required => 0,);
  $self->add_arg(
      spec => 'warningx=s%',
      help => '--warningx
   The extended warning thresholds
   e.g. --warningx db_msdb_free_pct=6: to override the threshold for a
   specific item ',
      required => 0,
  );
  $self->add_arg(
      spec => 'criticalx=s%',
      help => '--criticalx
   The extended critical thresholds',
      required => 0,
  );
  $self->add_arg(
      spec => 'units=s',
      help => "--units
   One of %, B, KB, MB, GB, Bit, KBi, MBi, GBi. (used for e.g. mode interface-usage)",
      required => 0,
  );
  $self->add_arg(
      spec => 'name=s',
      help => "--name
   The name of a specific component to check",
      required => 0,
      decode => "rfc3986",
  );
  $self->add_arg(
      spec => 'name2=s',
      help => "--name2
   The secondary name of a component",
      required => 0,
      decode => "rfc3986",
  );
  $self->add_arg(
      spec => 'name3=s',
      help => "--name3
   The tertiary name of a component",
      required => 0,
      decode => "rfc3986",
  );
  $self->add_arg(
      spec => 'extra-opts=s',
      help => "--extra-opts
   read command line arguments from an external file",
      required => 0,
  );
  $self->add_arg(
      spec => 'blacklist|b=s',
      help => '--blacklist
   Blacklist some (missing/failed) components',
      required => 0,
      default => '',
  );
  $self->add_arg(
      spec => 'mitigation=s',
      help => "--mitigation
   The parameter allows you to change a critical error to a warning.
   It works only for specific checks. Which ones? Try it out or look in the code.
   --mitigation warning ranks an error as warning which by default would be critical.",
      required => 0,
  );
  $self->add_arg(
      spec => 'lookback=s',
      help => "--lookback
   The amount of time you want to look back when calculating average rates.
   Use it for mode interface-errors or interface-usage. Without --lookback
   the time between two runs of check_nwc_health is the base for calculations.
   If you want your checkresult to be based for example on the past hour,
   use --lookback 3600. ",
      required => 0,
  );
  $self->add_arg(
      spec => 'environment|e=s%',
      help => "--environment
   Add a variable to the plugin's environment",
      required => 0,
  );
  $self->add_arg(
      spec => 'negate=s%',
      help => "--negate
   Emulate the negate plugin. --negate warning=critical --negate unknown=critical",
      required => 0,
  );
  $self->add_arg(
      spec => 'morphmessage=s%',
      help => '--morphmessage
   Modify the final output message',
      required => 0,
      decode => "rfc3986",
  );
  $self->add_arg(
      spec => 'morphperfdata=s%',
      help => "--morphperfdata
   The parameter allows you to change performance data labels.
   It's a perl regexp and a substitution.
   Example: --morphperfdata '(.*)ISATAP(.*)'='\$1patasi\$2'",
      required => 0,
      decode => "rfc3986",
  );
  $self->add_arg(
      spec => 'selectedperfdata=s',
      help => "--selectedperfdata
   The parameter allows you to limit the list of performance data. It's a perl regexp.
   Only matching perfdata show up in the output",
      required => 0,
  );
  $self->add_arg(
      spec => 'report=s',
      help => "--report
   Can be used to shorten the output",
      required => 0,
      default => 'long',
  );
  $self->add_arg(
      spec => 'multiline',
      help => '--multiline
   Multiline output',
      required => 0,
  );
  $self->add_arg(
      spec => 'with-mymodules-dyn-dir=s',
      help => "--with-mymodules-dyn-dir
   Add-on modules for the my-modes will be searched in this directory",
      required => 0,
  );
  $self->add_arg(
      spec => 'statefilesdir=s',
      help => '--statefilesdir
   An alternate directory where the plugin can save files',
      required => 0,
      env => 'STATEFILESDIR',
  );
  $self->add_arg(
      spec => 'isvalidtime=i',
      help => '--isvalidtime
   Signals the plugin to return OK if now is not a valid check time',
      required => 0,
      default => 1,
  );
  $self->add_arg(
      spec => 'reset',
      help => "--reset
   remove the state file",
      required => 0,
      hidden => 1,
  );
  $self->add_arg(
      spec => 'runas=s',
      help => "--runas
   run as a different user",
      required => 0,
      hidden => 1,
  );
  $self->add_arg(
      spec => 'shell',
      help => "--shell
   forget what you see",
      required => 0,
      hidden => 1,
  );
  $self->add_arg(
      spec => 'drecksptkdb=s',
      help => "--drecksptkdb
   This parameter must be used instead of --name, because Devel::ptkdb is stealing the latter from the command line",
      aliasfor => "name",
      required => 0,
      hidden => 1,
  );
  $self->add_arg(
      spec => 'tracefile=s',
      help => "--tracefile
   Write debugging-info to this file (if it exists)",
      required => 0,
      hidden => 1,
  );
}

sub add_default_modes {
  my ($self) = @_;
  $self->add_mode(
      internal => 'encode',
      spec => 'encode',
      alias => undef,
      help => 'encode stdin',
      hidden => 1,
  );
  $self->add_mode(
      internal => 'decode',
      spec => 'decode',
      alias => undef,
      help => 'decode stdin or --name',
      hidden => 1,
  );
}

sub add_modes {
  my ($self, $modes) = @_;
  my $modestring = "";
  my @modes = @{$modes};
  my $longest = length ((reverse sort {length $a <=> length $b} map { $_->[1] } @modes)[0]);
  my $format = "       %-".
      (length ((reverse sort {length $a <=> length $b} map { $_->[1] } @modes)[0])).
      "s\t(%s)\n";
  foreach (@modes) {
    $modestring .= sprintf $format, $_->[1], $_->[3];
  }
  $modestring .= sprintf "\n";
  $Monitoring::GLPlugin::plugin->{modestring} = $modestring;
}

sub add_arg {
  my ($self, %args) = @_;
  if ($args{help} =~ /^--mode/) {
    $args{help} .= "\n".$Monitoring::GLPlugin::plugin->{modestring};
  }
  $Monitoring::GLPlugin::plugin->{opts}->add_arg(%args);
}

sub mod_arg {
  my ($self, @arg) = @_;
  $Monitoring::GLPlugin::plugin->{opts}->mod_arg(@arg);
}

sub add_mode {
  my ($self, %args) = @_;
  push(@{$Monitoring::GLPlugin::plugin->{modes}}, \%args);
  my $longest = length ((reverse sort {length $a <=> length $b} map { $_->{spec} } @{$Monitoring::GLPlugin::plugin->{modes}})[0]);
  my $format = "       %-".
      (length ((reverse sort {length $a <=> length $b} map { $_->{spec} } @{$Monitoring::GLPlugin::plugin->{modes}})[0])).
      "s\t(%s)\n";
  $Monitoring::GLPlugin::plugin->{modestring} = "";
  foreach (@{$Monitoring::GLPlugin::plugin->{modes}}) {
    $Monitoring::GLPlugin::plugin->{modestring} .= sprintf $format, $_->{spec}, $_->{help};
  }
  $Monitoring::GLPlugin::plugin->{modestring} .= "\n";
}

sub validate_args {
  my ($self) = @_;
  if ($self->opts->mode =~ /^my-([^\-.]+)/) {
    my $param = $self->opts->mode;
    $param =~ s/\-/::/g;
    $self->add_mode(
        internal => $param,
        spec => $self->opts->mode,
        alias => undef,
        help => 'my extension',
    );
  } elsif ($self->opts->mode eq 'encode') {
    my $input = <>;
    chomp $input;
    $input =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
    printf "%s\n", $input;
    exit 0;
  } elsif ($self->opts->mode eq 'decode') {
    if (! -t STDIN) {
      my $input = <>;
      chomp $input;
      $input =~ s/%([A-Za-z0-9]{2})/chr(hex($1))/seg;
      printf "%s\n", $input;
      exit OK;
    } else {
      if ($self->opts->name) {
        my $input = $self->opts->name;
        $input =~ s/%([A-Za-z0-9]{2})/chr(hex($1))/seg;
        printf "%s\n", $input;
        exit OK;
      } else {
        printf "i can't find your encoded statement. use --name or pipe it in my stdin\n";
        exit UNKNOWN;
      }
    }
  } elsif ((! grep { $self->opts->mode eq $_ } map { $_->{spec} } @{$Monitoring::GLPlugin::plugin->{modes}}) &&
      (! grep { $self->opts->mode eq $_ } map { defined $_->{alias} ? @{$_->{alias}} : () } @{$Monitoring::GLPlugin::plugin->{modes}})) {
    printf "UNKNOWN - mode %s\n", $self->opts->mode;
    $self->opts->print_help();
    exit 3;
  }
  if ($self->opts->name && $self->opts->name =~ /(%22)|(%27)/) {
    my $name = $self->opts->name;
    $name =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
    $self->override_opt('name', $name);
  }
  $Monitoring::GLPlugin::mode = (
      map { $_->{internal} }
      grep {
         ($self->opts->mode eq $_->{spec}) ||
         ( defined $_->{alias} && grep { $self->opts->mode eq $_ } @{$_->{alias}})
      } @{$Monitoring::GLPlugin::plugin->{modes}}
  )[0];
  if ($self->opts->multiline) {
    $ENV{NRPE_MULTILINESUPPORT} = 1;
  } else {
    $ENV{NRPE_MULTILINESUPPORT} = 0;
  }
  if ($self->opts->can("statefilesdir") && ! $self->opts->statefilesdir) {
    if ($^O =~ /MSWin/) {
      if (defined $ENV{TEMP}) {
        $self->override_opt('statefilesdir', $ENV{TEMP}."/".$Monitoring::GLPlugin::plugin->{name});
      } elsif (defined $ENV{TMP}) {
        $self->override_opt('statefilesdir', $ENV{TMP}."/".$Monitoring::GLPlugin::plugin->{name});
      } elsif (defined $ENV{windir}) {
        $self->override_opt('statefilesdir', File::Spec->catfile($ENV{windir}, 'Temp')."/".$Monitoring::GLPlugin::plugin->{name});
      } else {
        $self->override_opt('statefilesdir', "C:/".$Monitoring::GLPlugin::plugin->{name});
      }
    } elsif (exists $ENV{OMD_ROOT}) {
      $self->override_opt('statefilesdir', $ENV{OMD_ROOT}."/var/tmp/".$Monitoring::GLPlugin::plugin->{name});
    } else {
      $self->override_opt('statefilesdir', "/var/tmp/".$Monitoring::GLPlugin::plugin->{name});
    }
  }
  $Monitoring::GLPlugin::plugin->{statefilesdir} = $self->opts->statefilesdir
      if $self->opts->can("statefilesdir");
  if ($self->opts->can("warningx") && $self->opts->warningx) {
    foreach my $key (keys %{$self->opts->warningx}) {
      $self->set_thresholds(metric => $key,
          warning => $self->opts->warningx->{$key});
    }
  }
  if ($self->opts->can("criticalx") && $self->opts->criticalx) {
    foreach my $key (keys %{$self->opts->criticalx}) {
      $self->set_thresholds(metric => $key,
          critical => $self->opts->criticalx->{$key});
    }
  }
  $self->set_timeout_alarm() if ! $SIG{'ALRM'};
}

sub set_timeout_alarm {
  my ($self, $timeout, $handler) = @_;
  $timeout ||= $self->opts->timeout;
  $handler ||= sub {
    $self->nagios_exit(UNKNOWN,
        sprintf("%s timed out after %d seconds\n",
            $Monitoring::GLPlugin::plugin->{name}, $self->opts->timeout)
    );
  };
  use POSIX ':signal_h';
  if ($^O =~ /MSWin/) {
    local $SIG{'ALRM'} = $handler;
  } else {
    my $mask = POSIX::SigSet->new( SIGALRM );
    my $action = POSIX::SigAction->new(
        $handler, $mask
    );   
    my $oldaction = POSIX::SigAction->new();
    sigaction(SIGALRM ,$action ,$oldaction );
  }    
  alarm(int($timeout)); # 1 second before the global unknown timeout
}

#########################################################
# global helpers
#
sub set_variable {
  my ($self, $key, $value) = @_;
  $Monitoring::GLPlugin::variables->{$key} = $value;
}

sub get_variable {
  my ($self, $key, $fallback) = @_;
  return exists $Monitoring::GLPlugin::variables->{$key} ?
      $Monitoring::GLPlugin::variables->{$key} : $fallback;
}

sub debug {
  my ($self, $format, @message) = @_;
  if ($self->get_variable("verbose") &&
      $self->get_variable("verbose") > $self->get_variable("verbosity", 10)) {
    printf("%s: ", scalar localtime);
    printf($format, @message);
    printf "\n";
  }
  if ($Monitoring::GLPlugin::tracefile) {
    my $logfh = IO::File->new();
    $logfh->autoflush(1);
    if ($logfh->open($Monitoring::GLPlugin::tracefile, "a")) {
      $logfh->printf("%s: ", scalar localtime);
      $logfh->printf($format, @message);
      $logfh->printf("\n");
      $logfh->close();
    }
  }
}

sub filter_namex {
  my ($self, $opt, $name) = @_;
  if ($opt) {
    if ($self->opts->regexp) {
      if ($name =~ /$opt/i) {
        return 1;
      }
    } else {
      if (lc $opt eq lc $name) {
        return 1;
      }
    }
  } else {
    return 1;
  }
  return 0;
}

sub filter_name {
  my ($self, $name) = @_;
  return $self->filter_namex($self->opts->name, $name);
}

sub filter_name2 {
  my ($self, $name) = @_;
  return $self->filter_namex($self->opts->name2, $name);
}

sub filter_name3 {
  my ($self, $name) = @_;
  return $self->filter_namex($self->opts->name3, $name);
}

sub version_is_minimum {
  my ($self, $version) = @_;
  my $installed_version;
  my $newer = 1;
  if ($self->get_variable("version")) {
    $installed_version = $self->get_variable("version");
  } elsif (exists $self->{version}) {
    $installed_version = $self->{version};
  } else {
    return 0;
  }
  my @v1 = map { $_ eq "x" ? 0 : $_ } split(/\./, $version);
  my @v2 = split(/\./, $installed_version);
  if (scalar(@v1) > scalar(@v2)) {
    push(@v2, (0) x (scalar(@v1) - scalar(@v2)));
  } elsif (scalar(@v2) > scalar(@v1)) {
    push(@v1, (0) x (scalar(@v2) - scalar(@v1)));
  }
  foreach my $pos (0..$#v1) {
    if ($v2[$pos] > $v1[$pos]) {
      $newer = 1;
      last;
    } elsif ($v2[$pos] < $v1[$pos]) {
      $newer = 0;
      last;
    }
  }
  return $newer;
}

sub accentfree {
  my ($self, $text) = @_;
  # thanks mycoyne who posted this accent-remove-algorithm
  # http://www.experts-exchange.com/Programming/Languages/Scripting/Perl/Q_23275533.html#a21234612
  my @transformed;
  my %replace = (
    '9a' => 's', '9c' => 'oe', '9e' => 'z', '9f' => 'Y', 'c0' => 'A', 'c1' => 'A',
    'c2' => 'A', 'c3' => 'A', 'c4' => 'A', 'c5' => 'A', 'c6' => 'AE', 'c7' => 'C',
    'c8' => 'E', 'c9' => 'E', 'ca' => 'E', 'cb' => 'E', 'cc' => 'I', 'cd' => 'I',
    'ce' => 'I', 'cf' => 'I', 'd0' => 'D', 'd1' => 'N', 'd2' => 'O', 'd3' => 'O',
    'd4' => 'O', 'd5' => 'O', 'd6' => 'O', 'd8' => 'O', 'd9' => 'U', 'da' => 'U',
    'db' => 'U', 'dc' => 'U', 'dd' => 'Y', 'e0' => 'a', 'e1' => 'a', 'e2' => 'a',
    'e3' => 'a', 'e4' => 'a', 'e5' => 'a', 'e6' => 'ae', 'e7' => 'c', 'e8' => 'e',
    'e9' => 'e', 'ea' => 'e', 'eb' => 'e', 'ec' => 'i', 'ed' => 'i', 'ee' => 'i',
    'ef' => 'i', 'f0' => 'o', 'f1' => 'n', 'f2' => 'o', 'f3' => 'o', 'f4' => 'o',
    'f5' => 'o', 'f6' => 'o', 'f8' => 'o', 'f9' => 'u', 'fa' => 'u', 'fb' => 'u',
    'fc' => 'u', 'fd' => 'y', 'ff' => 'y',
    '8a' => 'S', '8c' => 'CE', '9a' => 's', '9c' => 'oe', '9f' => 'Y', 'a2' => 'o', 'aa' => 'a',
    'b2' => '2', 'b3' => '3', 'b9' => '1', 'bc' => '1/4', 'bd' => '1/2', 'be' => '3/4',
    'c0' => 'A', 'c1' => 'A', 'c2' => 'A', 'c3' => 'A', 'c4' => 'A', 'c5' => 'A', 'c6' => 'AE',
    'c7' => 'C', 'c8' => 'E', 'c9' => 'E', 'ca' => 'E', 'cb' => 'E',
    'cc' => 'I', 'cd' => 'I', 'ce' => 'I', 'cf' => 'I', 'd0' => 'D', 'd1' => 'N',
    'd2' => 'O', 'd3' => 'O', 'd4' => 'O', 'd5' => 'O', 'd6' => 'O',
    'd8' => 'O', 'd9' => 'U', 'da' => 'U', 'db' => 'U', 'dc' => 'U', 'dd' => 'Y',
    'df' => 'ss', 'e0' => 'a', 'e1' => 'a', 'e2' => 'a', 'e3' => 'a', 'e4' => 'a', 'e5' => 'a',
    'e6' => 'ae', 'e7' => 'c', 'e8' => 'e', 'e9' => 'e', 'ea' => 'e', 'eb' => 'e',
    'ec' => 'i', 'ed' => 'i', 'ee' => 'i', 'ef' => 'i', 'f1' => 'n',
    'f2' => 'o', 'f3' => 'o', 'f4' => 'o', 'f5' => 'o', 'f6' => 'o', 'f8' => 'o',
    'f9' => 'u', 'fa' => 'u', 'fb' => 'u', 'fc' => 'u', 'fd' => 'y', 'ff' => 'yy',
  );
  my @letters = split //, $text;;
  for (my $i = 0; $i <= $#letters; $i++) {
    my $hex = sprintf "%x", ord($letters[$i]);
    $letters[$i] = $replace{$hex} if (exists $replace{$hex});
  }
  push @transformed, @letters;
  $text = join '', @transformed;
  $text =~ s/[[:^ascii:]]//g;
  return $text;
}

sub dump {
  my ($self, $indent) = @_;
  $indent = $indent ? " " x $indent : "";
  if ($self->can("internal_name")) {
    printf "%s[%s]\n", $indent, $self->internal_name();
  } else {
    my $class = ref($self);
    $class =~ s/^.*:://;
    printf "%s[%s]\n", $indent, uc $class;
  }
  foreach (grep !/^(info|trace|warning|critical|blacklisted|extendedinfo|flat_indices|indices)$/, sort keys %{$self}) {
    printf "%s%s: %s\n", $indent, $_, $self->{$_} if defined $self->{$_} && ref($self->{$_}) ne "ARRAY";
  }
  if ($self->{info}) {
    printf "%sinfo: %s\n", $indent, $self->{info};
  }
  foreach (grep !/^(info|trace|warning|critical|blacklisted|extendedinfo|flat_indices|indices)$/, sort keys %{$self}) {
    if (defined $self->{$_} && ref($self->{$_}) eq "ARRAY") {
      my $have_flat_indices = 1;
      foreach my $obj (@{$self->{$_}}) {
        $have_flat_indices = 0 if (ref($obj) ne "HASH" || ! exists $obj->{flat_indices});
      }
      if ($have_flat_indices) {
        foreach my $obj (sort {
            join('', map { sprintf("%30d",$_) } split( /\./, $a->{flat_indices})) cmp
            join('', map { sprintf("%30d",$_) } split( /\./, $b->{flat_indices}))
        } @{$self->{$_}}) {
          $obj->dump();
        }
      } else {
        foreach my $obj (@{$self->{$_}}) {
          $obj->dump() if UNIVERSAL::can($obj, "isa") && $obj->can("dump");
        }
      }
    } elsif (defined $self->{$_} && ref($self->{$_}) =~ /^Classes::/) {
      $self->{$_}->dump(2) if UNIVERSAL::can($self->{$_}, "isa") && $self->{$_}->can("dump");
    }
  }
  printf "\n";
}

sub table_ascii {
  my ($self, $table, $titles) = @_;
  my $text = "";
  my $column_length = {};
  my $column = 0;
  foreach (@{$titles}) {
    $column_length->{$column++} = length($_);
  }
  foreach my $tr (@{$table}) {
    @{$tr} = map { ref($_) eq "ARRAY" ? $_->[0] : $_; } @{$tr};
    $column = 0;
    foreach my $td (@{$tr}) {
      if (length($td) > $column_length->{$column}) {
        $column_length->{$column} = length($td);
      }
      $column++;
    }
  }
  $column = 0;
  foreach (@{$titles}) {
    $column_length->{$column} = "%".($column_length->{$column} + 3)."s";
    $column++;
  }
  $column = 0;
  foreach (@{$titles}) {
    $text .= sprintf $column_length->{$column++}, $_;
  }
  $text .= "\n";
  foreach my $tr (@{$table}) {
    $column = 0;
    foreach my $td (@{$tr}) {
      $text .= sprintf $column_length->{$column++}, $td;
    }
    $text .= "\n";
  }
  return $text;
}

sub table_html {
  my ($self, $table, $titles) = @_;
  my $text = "";
  $text .= "<table style=\"border-collapse:collapse; border: 1px solid black;\">";
  $text .= "<tr>";
  foreach (@{$titles}) {
    $text .= sprintf "<th style=\"text-align: left; padding-left: 4px; padding-right: 6px;\">%s</th>", $_;
  }
  $text .= "</tr>";
  foreach my $tr (@{$table}) {
    $text .= "<tr>";
    foreach my $td (@{$tr}) {
      my $class = "statusOK";
      if (ref($td) eq "ARRAY") {
        $class = {
          0 => "statusOK",
          1 => "statusWARNING",
          2 => "statusCRITICAL",
          3 => "statusUNKNOWN",
        }->{$td->[1]};
        $td = $td->[0];
      }
      $text .= sprintf "<td style=\"text-align: left; padding-left: 4px; padding-right: 6px;\" class=\"%s\">%s</td>", $class, $td;
    }
    $text .= "</tr>";
  }
  $text .= "</table>";
  return $text;
}

sub load_my_extension {
  my ($self) = @_;
  if ($self->opts->mode =~ /^my-([^-.]+)/) {
    my $class = $1;
    my $loaderror = undef;
    substr($class, 0, 1) = uc substr($class, 0, 1);
    if (! $self->opts->get("with-mymodules-dyn-dir")) {
      $self->override_opt("with-mymodules-dyn-dir", "");
    }
    my $plugin_name = $Monitoring::GLPlugin::pluginname;
    $plugin_name =~ /check_(.*?)_health/;
    my $deprecated_class = "DBD::".(uc $1)."::Server";
    $plugin_name = "Check".uc(substr($1, 0, 1)).substr($1, 1)."Health";
    foreach my $libpath (split(":", $self->opts->get("with-mymodules-dyn-dir"))) {
      foreach my $extmod (glob $libpath."/".$plugin_name."*.pm") {
        my $stderrvar;
        *SAVEERR = *STDERR;
        open OUT ,'>',\$stderrvar;
        *STDERR = *OUT;
        eval {
          $self->debug(sprintf "loading module %s", $extmod);
          require $extmod;
        };
        *STDERR = *SAVEERR;
        if ($@) {
          $loaderror = $extmod;
          $self->debug(sprintf "failed loading module %s: %s", $extmod, $@);
        }
      }
    }
    my $original_class = ref($self);
    my $original_init = $self->can("init");
    $self->compatibility_class() if $self->can('compatibility_class');
    bless $self, "My$class";
    $self->compatibility_methods() if $self->can('compatibility_methods') &&
        $self->isa($deprecated_class);
    if ($self->isa("Monitoring::GLPlugin")) {
      my $new_init = $self->can("init");
      if ($new_init == $original_init) {
          $self->add_unknown(
              sprintf "Class %s needs an init() method", ref($self));
      } else {
        # now go back to check_*_health.pl where init() will be called
      }
    } else {
      bless $self, $original_class;
      $self->add_unknown(
          sprintf "Class %s is not a subclass of Monitoring::GLPlugin%s",
              "My$class",
              $loaderror ? sprintf " (syntax error in %s?)", $loaderror : "" );
      my ($code, $message) = $self->check_messages(join => ', ', join_all => ', ');
      $self->nagios_exit($code, $message);
    }
  }
}

sub number_of_bits {
  my ($self, $unit) = @_;
  # https://en.wikipedia.org/wiki/Data_rate_units
  my $bits = {
    'bit' => 1,			# Bit per second
    'B' => 8,			# Byte per second, 8 bits per second
    'kbit' => 1000,		# Kilobit per second, 1,000 bits per second
    'kb' => 1000,		# Kilobit per second, 1,000 bits per second
    'Kibit' => 1024,		# Kibibit per second, 1,024 bits per second
    'kB' => 8000,		# Kilobyte per second, 8,000 bits per second
    'KiB' => 8192,		# Kibibyte per second, 1,024 bytes per second
    'Mbit' => 1000000,		# Megabit per second, 1,000,000 bits per second
    'Mb' => 1000000,		# Megabit per second, 1,000,000 bits per second
    'Mibit' => 1048576,		# Mebibit per second, 1,024 kibibits per second
    'MB' => 8000000,		# Megabyte per second, 1,000 kilobytes per second
    'MiB' => 8388608,		# Mebibyte per second, 1,024 kibibytes per second
    'Gbit' => 1000000000,	# Gigabit per second, 1,000 megabits per second
    'Gb' => 1000000000,		# Gigabit per second, 1,000 megabits per second
    'Gibit' => 1073741824,	# Gibibit per second, 1,024 mebibits per second
    'GB' => 8000000000,		# Gigabyte per second, 1,000 megabytes per second
    'GiB' => 8589934592,	# Gibibyte per second, 8192 mebibits per second
    'Tbit' => 1000000000000,	# Terabit per second, 1,000 gigabits per second
    'Tb' => 1000000000000,	# Terabit per second, 1,000 gigabits per second
    'Tibit' => 1099511627776,	# Tebibit per second, 1,024 gibibits per second
    'TB' => 8000000000000,	# Terabyte per second, 1,000 gigabytes per second
    # eigene kreationen
    'Bits' => 1,
    'Bit' => 1,			# Bit per second
    'KB' => 1024,		# Kilobyte (like disk kilobyte)
    'KBi' => 1024,		# -"-
    'MBi' => 1024 * 1024,	# Megabyte (like disk megabyte)
    'GBi' => 1024 * 1024 * 1024, # Gigybate (like disk gigybyte)
  };
  if (exists $bits->{$unit}) {
    return $bits->{$unit};
  } else {
    return 0;
  }
}


#########################################################
# runtime methods
#
sub mode : lvalue {
  my ($self) = @_;
  $Monitoring::GLPlugin::mode;
}

sub statefilesdir {
  my ($self) = @_;
  return $Monitoring::GLPlugin::plugin->{statefilesdir};
}

sub opts { # die beiden _nicht_ in AUTOLOAD schieben, das kracht!
  my ($self) = @_;
  return $Monitoring::GLPlugin::plugin->opts();
}

sub getopts {
  my ($self, $envparams) = @_;
  $envparams ||= [];
  my $needs_restart = 0;
  my @restart_opts = ();
  $Monitoring::GLPlugin::plugin->getopts();
  # es kann sein, dass beim aufraeumen zum schluss als erstes objekt
  # das $Monitoring::GLPlugin::plugin geloescht wird. in anderen destruktoren
  # (insb. fuer dbi disconnect) steht dann $self->opts->verbose
  # nicht mehr zur verfuegung bzw. $Monitoring::GLPlugin::plugin->opts ist undef.
  $self->set_variable("verbose", $self->opts->verbose);
  $Monitoring::GLPlugin::tracefile = $self->opts->tracefile ?
      $self->opts->tracefile :
      $self->system_tmpdir()."/".$Monitoring::GLPlugin::pluginname.".trace";
  if (! -f $Monitoring::GLPlugin::tracefile) {
    $Monitoring::GLPlugin::tracefile = undef;
  }
  #
  # die gueltigkeit von modes wird bereits hier geprueft und nicht danach
  # in validate_args. (zwischen getopts und validate_args wird
  # normalerweise classify aufgerufen, welches bereits eine verbindung
  # zum endgeraet herstellt. bei falschem mode waere das eine verschwendung
  # bzw. durch den exit3 ein evt. unsauberes beenden der verbindung.
  if ((! grep { $self->opts->mode eq $_ } map { $_->{spec} } @{$Monitoring::GLPlugin::plugin->{modes}}) &&
      (! grep { $self->opts->mode eq $_ } map { defined $_->{alias} ? @{$_->{alias}} : () } @{$Monitoring::GLPlugin::plugin->{modes}})) {
    if ($self->opts->mode !~ /^my-/) {
      printf "UNKNOWN - mode %s\n", $self->opts->mode;
      $self->opts->print_help();
      exit 3;
    }
  }
  if ($self->opts->environment) {
    # wenn die gewuenschten Environmentvariablen sich von den derzeit
    # gesetzten unterscheiden, dann restart. Denn $ENV aendert
    # _nicht_ das Environment des laufenden Prozesses. 
    # $ENV{ZEUGS} = 1 bedeutet lediglich, dass $ENV{ZEUGS} bei weiterer
    # Verwendung 1 ist, bedeutet aber _nicht_, dass diese Variable 
    # im Environment des laufenden Prozesses existiert.
    foreach (keys %{$self->opts->environment}) {
      if ((! $ENV{$_}) || ($ENV{$_} ne $self->opts->environment->{$_})) {
        $needs_restart = 1;
        $ENV{$_} = $self->opts->environment->{$_};
        $self->debug(sprintf "new %s=%s forces restart\n", $_, $ENV{$_});
      }
    }
  }
  if ($self->opts->runas) {
    # exec sudo $0 ... und dann ohne --runas
    $needs_restart = 1;
    # wenn wir environmentvariablen haben, die laut survive_sudo_env als
    # wichtig erachtet werden, dann muessen wir die ueber einen moeglichen
    # sudo-aufruf rueberretten, also in zusaetzliche --environment umwandenln.
    # sudo putzt das Environment naemlich aus.
    foreach my $survive_env (@{$Monitoring::GLPlugin::survive_sudo_env}) {
      if ($ENV{$survive_env} && ! scalar(grep { /^$survive_env=/ }
          keys %{$self->opts->environment})) {
        $self->opts->environment->{$survive_env} = $ENV{$survive_env};
        printf STDERR "add important --environment %s=%s\n",
            $survive_env, $ENV{$survive_env} if $self->opts->verbose >= 2;
        push(@restart_opts, '--environment');
        push(@restart_opts, sprintf '%s=%s',
            $survive_env, $ENV{$survive_env});
      }
    }
  }
  if ($needs_restart) {
    foreach my $option (keys %{$self->opts->all_my_opts}) {
      # der fliegt raus, sonst gehts gleich wieder in needs_restart rein
      next if $option eq "runas";
      foreach my $spec (map { $_->{spec} } @{$Monitoring::GLPlugin::plugin->opts->{_args}}) {
        if ($spec =~ /^([\-\w]+)[\?\+:\|\w+]*=(.*)/) {
          if ($1 eq $option && $2 =~ /s%/) {
            foreach (keys %{$self->opts->$option()}) {
              push(@restart_opts, sprintf "--%s", $option);
              push(@restart_opts, sprintf "%s=%s", $_, $self->opts->$option()->{$_});
            }
          } elsif ($1 eq $option) {
            push(@restart_opts, sprintf "--%s", $option);
            push(@restart_opts, sprintf "%s", $self->opts->$option());
          }
        } elsif ($spec eq $option) {
          push(@restart_opts, sprintf "--%s", $option);
        }
      }
    }
    if ($self->opts->runas && ($> == 0)) {
      # Ja, es gibt so Narrische, die gehen mit check_by_ssh als root
      # auf Datenbankmaschinen drauf und lassen dann dort check_oracle_health
      # laufen. Damit OPS$-Anmeldung dann funktioniert, wird mit --runas
      # auf eine andere Kennung umgeschwenkt. Diese Kennung gleich fuer
      # ssh zu verwenden geht aus Sicherheitsgruenden nicht. Narrische halt.
      exec "su", "-c", sprintf("%s %s", $0, join(" ", @restart_opts)), "-", $self->opts->runas;
    } elsif ($self->opts->runas) {
      exec "sudo", "-S", "-u", $self->opts->runas, $0, @restart_opts;
    } else {
      exec $0, @restart_opts;
      # dadurch werden SHLIB oder LD_LIBRARY_PATH sauber gesetzt, damit beim
      # erneuten Start libclntsh.so etc. gefunden werden.
    }
    exit;
  }
  if ($self->opts->shell) {
    # So komme ich bei den Narrischen zu einer root-Shell.
    system("/bin/sh");
  }
}


sub add_ok {
  my ($self, $message) = @_;
  $message ||= $self->{info};
  $self->add_message(OK, $message);
}

sub add_warning {
  my ($self, $message) = @_;
  $message ||= $self->{info};
  $self->add_message(WARNING, $message);
}

sub add_critical {
  my ($self, $message) = @_;
  $message ||= $self->{info};
  $self->add_message(CRITICAL, $message);
}

sub add_unknown {
  my ($self, $message) = @_;
  $message ||= $self->{info};
  $self->add_message(UNKNOWN, $message);
}

sub add_ok_mitigation {
  my ($self, $message) = @_;
  if (defined $self->opts->mitigation()) {
    $self->add_message($self->opts->mitigation(), $message);
  } else {
    $self->add_ok($message);
  }
}

sub add_warning_mitigation {
  my ($self, $message) = @_;
  if (defined $self->opts->mitigation()) {
    $self->add_message($self->opts->mitigation(), $message);
  } else {
    $self->add_warning($message);
  }
}

sub add_critical_mitigation {
  my ($self, $message) = @_;
  if (defined $self->opts->mitigation()) {
    $self->add_message($self->opts->mitigation(), $message);
  } else {
    $self->add_critical($message);
  }
}

sub add_unknown_mitigation {
  my ($self, $message) = @_;
  if (defined $self->opts->mitigation()) {
    $self->add_message($self->opts->mitigation(), $message);
  } else {
    $self->add_unknown($message);
  }
}

sub add_message {
  my ($self, $level, $message) = @_;
  $message ||= $self->{info};
  $Monitoring::GLPlugin::plugin->add_message($level, $message)
      unless $self->is_blacklisted();
  if (exists $self->{failed}) {
    if ($level == UNKNOWN && $self->{failed} == OK) {
      $self->{failed} = $level;
    } elsif ($level > $self->{failed}) {
      $self->{failed} = $level;
    }
  }
}

sub clear_ok {
  my ($self) = @_;
  $self->clear_messages(OK);
}

sub clear_warning {
  my ($self) = @_;
  $self->clear_messages(WARNING);
}

sub clear_critical {
  my ($self) = @_;
  $self->clear_messages(CRITICAL);
}

sub clear_unknown {
  my ($self) = @_;
  $self->clear_messages(UNKNOWN);
}

sub clear_all { # deprecated, use clear_messages
  my ($self) = @_;
  $self->clear_ok();
  $self->clear_warning();
  $self->clear_critical();
  $self->clear_unknown();
}

sub set_level {
  my ($self, $code) = @_;
  $code = (qw(ok warning critical unknown))[$code] if $code =~ /^\d+$/;
  $code = lc $code;
  if (! exists $self->{tmp_level}) {
    $self->{tmp_level} = {
      ok => 0,
      warning => 0,
      critical => 0,
      unknown => 0,
    };
  }
  $self->{tmp_level}->{$code}++;
}

sub get_level {
  my ($self) = @_;
  return OK if ! exists $self->{tmp_level};
  my $code = OK;
  return CRITICAL if $self->{tmp_level}->{critical};
  return WARNING  if $self->{tmp_level}->{warning};
  return UNKNOWN  if $self->{tmp_level}->{unknown};
  return $code;
}

#########################################################
# blacklisting
#
sub blacklist {
  my ($self) = @_;
  $self->{blacklisted} = 1;
}

sub add_blacklist {
  my ($self, $list) = @_;
  $Monitoring::GLPlugin::blacklist = join('/',
      (split('/', $self->opts->blacklist), $list));
}

sub is_blacklisted {
  my ($self) = @_;
  if (! $self->opts->can("blacklist")) {
    return 0;
  }
  if (! exists $self->{blacklisted}) {
    $self->{blacklisted} = 0;
  }
  if (exists $self->{blacklisted} && $self->{blacklisted}) {
    return $self->{blacklisted};
  }
  # FAN:459,203/TEMP:102229/ENVSUBSYSTEM
  # FAN_459,FAN_203,TEMP_102229,ENVSUBSYSTEM
  # ALERT:(The Storage Center is not able to access Tiebreaker)/TEMP:102229
  if ($self->opts->blacklist =~ /_/) {
    foreach my $bl_item (split(/,/, $self->opts->blacklist)) {
      if ($bl_item eq $self->internal_name()) {
        $self->{blacklisted} = 1;
      }
    }
  } else {
    foreach my $bl_items (split(/\//, $self->opts->blacklist)) {
      if ($bl_items =~ /^(\w+):([\:\d\-\.,]+)$/) {
        my $bl_type = $1;
        my $bl_names = $2;
        foreach my $bl_name (split(/,/, $bl_names)) {
          if ($bl_type."_".$bl_name eq $self->internal_name()) {
            $self->{blacklisted} = 1;
          }
        }
      } elsif ($bl_items =~ /^(\w+):\((.*)\)$/ and $self->can("internal_content")) {
        my $bl_type = $1;
        my $bl_pattern = qr/$2/;
        if ($self->internal_name() =~ /^${bl_type}_/) {
          if ($self->internal_content() =~ /$bl_pattern/) {
            $self->{blacklisted} = 1;
          }
        }
      } elsif ($bl_items =~ /^(\w+)$/) {
        if ($bl_items eq $self->internal_name()) {
          $self->{blacklisted} = 1;
        }
      }
    }
  }
  return $self->{blacklisted};
}

#########################################################
# additional info
#
sub add_info {
  my ($self, $info) = @_;
  $info = $self->is_blacklisted() ? $info.' (blacklisted)' : $info;
  $self->{info} = $info;
  push(@{$Monitoring::GLPlugin::info}, $info);
}

sub annotate_info {
  my ($self, $annotation) = @_;
  my $lastinfo = pop(@{$Monitoring::GLPlugin::info});
  $lastinfo .= sprintf ' (%s)', $annotation;
  $self->{info} = $lastinfo;
  push(@{$Monitoring::GLPlugin::info}, $lastinfo);
}

sub add_extendedinfo {  # deprecated
  my ($self, $info) = @_;
  $self->{extendedinfo} = $info;
  return if ! $self->opts->extendedinfo;
  push(@{$Monitoring::GLPlugin::extendedinfo}, $info);
}

sub get_info {
  my ($self, $separator) = @_;
  $separator ||= ' ';
  return join($separator , @{$Monitoring::GLPlugin::info});
}

sub get_last_info {
  my ($self) = @_;
  return pop(@{$Monitoring::GLPlugin::info});
}

sub get_extendedinfo {
  my ($self, $separator) = @_;
  $separator ||= ' ';
  return join($separator, @{$Monitoring::GLPlugin::extendedinfo});
}

sub add_summary {  # deprecated
  my ($self, $summary) = @_;
  push(@{$Monitoring::GLPlugin::summary}, $summary);
}

sub get_summary {
  my ($self) = @_;
  return join(', ', @{$Monitoring::GLPlugin::summary});
}

#########################################################
# persistency
#
sub valdiff {
  my ($self, $pparams, @keys) = @_;
  my %params = %{$pparams};
  my $now = time;
  my $newest_history_set = {};
  $params{freeze} = 0 if ! $params{freeze};
  my $mode = "normal";
  if ($self->opts->lookback && $self->opts->lookback == 99999 && $params{freeze} == 0) {
    $mode = "lookback_freeze_chill";
  } elsif ($self->opts->lookback && $self->opts->lookback == 99999 && $params{freeze} == 1) {
    $mode = "lookback_freeze_shockfrost";
  } elsif ($self->opts->lookback && $self->opts->lookback == 99999 && $params{freeze} == 2) {
    $mode = "lookback_freeze_defrost";
  } elsif ($self->opts->lookback) {
    $mode = "lookback";
  }
  # lookback=99999, freeze=0(default)
  #  nimm den letzten lauf und schreib ihn nach {cold}
  #  vergleich dann
  #    wenn es frozen gibt, vergleich frozen und den letzten lauf
  #    sonst den letzten lauf und den aktuellen lauf
  # lookback=99999, freeze=1
  #  wird dann aufgerufen,wenn nach dem freeze=0 ein problem festgestellt wurde
  #     (also als 2.valdiff hinterher)
  #  schreib cold nach frozen
  # lookback=99999, freeze=2
  #  wird dann aufgerufen,wenn nach dem freeze=0 wieder alles ok ist
  #     (also als 2.valdiff hinterher)
  #  loescht frozen
  #
  my $last_values = $self->load_state(%params) || eval {
    my $empty_events = {};
    foreach (@keys) {
      if (ref($self->{$_}) eq "ARRAY") {
        $empty_events->{$_} = [];
      } else {
        $empty_events->{$_} = 0;
      }
    }
    $empty_events->{timestamp} = 0;
    if ($mode eq "lookback") {
      $empty_events->{lookback_history} = {};
    } elsif ($mode eq "lookback_freeze_chill") {
      $empty_events->{cold} = {};
      $empty_events->{frozen} = {};
    }
    $empty_events;
  };
  $self->{'delta_timestamp'} = $now - $last_values->{timestamp};
  foreach (@keys) {
    if ($mode eq "lookback_freeze_chill") {
      # die werte vom letzten lauf wegsichern.
      # vielleicht gibts gleich einen freeze=1, dann muessen die eingefroren werden
      if (exists $last_values->{$_}) {
        if (ref($self->{$_}) eq "ARRAY") {
          $last_values->{cold}->{$_} = [];
          foreach my $value (@{$last_values->{$_}}) {
            push(@{$last_values->{cold}->{$_}}, $value);
          }
        } else {
          $last_values->{cold}->{$_} = $last_values->{$_};
        }
      } else {
        if (ref($self->{$_}) eq "ARRAY") {
          $last_values->{cold}->{$_} = [];
        } else {
          $last_values->{cold}->{$_} = 0;
        }
      }
      # es wird so getan, als sei der frozen wert vom letzten lauf
      if (exists $last_values->{frozen}->{$_}) {
        if (ref($self->{$_}) eq "ARRAY") {
          $last_values->{$_} = [];
          foreach my $value (@{$last_values->{frozen}->{$_}}) {
            push(@{$last_values->{$_}}, $value);
          }
        } else {
          $last_values->{$_} = $last_values->{frozen}->{$_};
        }
      }
    } elsif ($mode eq "lookback") {
      # find a last_value in the history which fits lookback best
      # and overwrite $last_values->{$_} with historic data
      if (exists $last_values->{lookback_history}->{$_}) {
        foreach my $date (sort {$a <=> $b} keys %{$last_values->{lookback_history}->{$_}}) {
            $newest_history_set->{$_} = $last_values->{lookback_history}->{$_}->{$date};
            $newest_history_set->{timestamp} = $date;
        }
        foreach my $date (sort {$a <=> $b} keys %{$last_values->{lookback_history}->{$_}}) {
          if ($date >= ($now - $self->opts->lookback)) {
            $last_values->{$_} = $last_values->{lookback_history}->{$_}->{$date};
            $last_values->{timestamp} = $date;
            $self->{'delta_timestamp'} = $now - $last_values->{timestamp};
            if (ref($last_values->{$_}) eq "ARRAY") {
              $self->debug(sprintf "oldest value of %s within lookback is size %s (age %d)",
                  $_, scalar(@{$last_values->{$_}}), $now - $date);
            } else {
              $self->debug(sprintf "oldest value of %s within lookback is %s (age %d)",
                  $_, $last_values->{$_}, $now - $date);
            }
            last;
          } else {
            $self->debug(sprintf "deprecate %s of age %d", $_, time - $date);
            delete $last_values->{lookback_history}->{$_}->{$date};
          }
        }
      }
    }
    if ($mode eq "normal" || $mode eq "lookback" || $mode eq "lookback_freeze_chill") {
      if (exists $self->{$_} && defined $self->{$_} && $self->{$_} =~ /^\d+\.*\d*$/) {
        # $VAR1 = { 'sysStatTmSleepCycles' => '',
        # no idea why this happens, but we can repair it.
        $last_values->{$_} = $self->{$_} if ! (exists $last_values->{$_} && defined $last_values->{$_} && $last_values->{$_} ne "");
        if ($self->{$_} >= $last_values->{$_}) {
          $self->{'delta_'.$_} = $self->{$_} - $last_values->{$_};
        } elsif ($self->{$_} eq $last_values->{$_}) {
          # dawischt! in einem fall wurde 131071.999023438 >= 131071.999023438 da oben nicht erkannt
          # subtrahieren ging auch daneben, weil ein winziger negativer wert rauskam.
          $self->{'delta_'.$_} = 0;
        } else {
          if ($mode =~ /lookback_freeze/) {
            # hier koennen delta-werte auch negativ sein, wenn z.b. peers verschwinden
            $self->{'delta_'.$_} = $self->{$_} - $last_values->{$_};
          } elsif (exists $params{lastarray}) {
            $self->{'delta_'.$_} = $self->{$_} - $last_values->{$_};
          } else {
            # vermutlich db restart und zaehler alle auf null
            $self->{'delta_'.$_} = $self->{$_};
          }
        }
        $self->debug(sprintf "delta_%s %f", $_, $self->{'delta_'.$_});
        $self->{$_.'_per_sec'} = $self->{'delta_timestamp'} ?
            $self->{'delta_'.$_} / $self->{'delta_timestamp'} : 0;
      } elsif (ref($self->{$_}) eq "ARRAY") {
        if ((! exists $last_values->{$_} || ! defined $last_values->{$_}) && exists $params{lastarray}) {
          # innerhalb der lookback-zeit wurde nichts in der lookback_history
          # gefunden. allenfalls irgendwas aelteres. normalerweise
          # wuerde jetzt das array als [] initialisiert.
          # d.h. es wuerde ein delta geben, @found s.u.
          # wenn man das nicht will, sondern einfach aktuelles array mit
          # dem array des letzten laufs vergleichen will, setzt man lastarray
          $last_values->{$_} = %{$newest_history_set} ?
              $newest_history_set->{$_} : []
        } elsif ((! exists $last_values->{$_} || ! defined $last_values->{$_}) && ! exists $params{lastarray}) {
          $last_values->{$_} = [] if ! exists $last_values->{$_};
        } elsif (exists $last_values->{$_} && ! defined $last_values->{$_}) {
          # $_ kann es auch ausserhalb des lookback_history-keys als normalen
          # key geben. der zeigt normalerweise auf den entspr. letzten
          # lookback_history eintrag. wurde der wegen ueberalterung abgeschnitten
          # ist der hier auch undef.
          $last_values->{$_} = %{$newest_history_set} ?
              $newest_history_set->{$_} : []
        }
        my %saved = map { $_ => 1 } @{$last_values->{$_}};
        my %current = map { $_ => 1 } @{$self->{$_}};
        my @found = grep(!defined $saved{$_}, @{$self->{$_}});
        my @lost = grep(!defined $current{$_}, @{$last_values->{$_}});
        $self->{'delta_found_'.$_} = \@found;
        $self->{'delta_lost_'.$_} = \@lost;
      } else {
        # nicht ganz sauber, aber das artet aus, wenn man jedem uninitialized hinterherstochert.
        # wem das nicht passt, der kann gerne ein paar tage debugging beauftragen.
        # das kostet aber mehr als drei kugeln eis.
        $last_values->{$_} = 0 if ! (exists $last_values->{$_} && defined $last_values->{$_} && $last_values->{$_} ne "");
        $self->{$_} = 0 if ! (exists $self->{$_} && defined $self->{$_} && $self->{$_} ne "");
        $self->{'delta_'.$_} = 0;
      }
    }
  }
  $params{save} = eval {
    my $empty_events = {};
    foreach (@keys) {
      $empty_events->{$_} = $self->{$_};
      if ($mode =~ /lookback_freeze/) {
        if (exists $last_values->{frozen}->{$_}) {
          if (ref($last_values->{frozen}->{$_}) eq "ARRAY") {
            @{$empty_events->{cold}->{$_}} = @{$last_values->{frozen}->{$_}};
          } else {
            $empty_events->{cold}->{$_} = $last_values->{frozen}->{$_};
          }
        } else {
          if (ref($last_values->{cold}->{$_}) eq "ARRAY") {
            @{$empty_events->{cold}->{$_}} = @{$last_values->{cold}->{$_}};
          } else {
            $empty_events->{cold}->{$_} = $last_values->{cold}->{$_};
          }
        }
        $empty_events->{cold}->{timestamp} = $last_values->{cold}->{timestamp};
      }
      if ($mode eq "lookback_freeze_shockfrost") {
        if (ref($empty_events->{cold}->{$_}) eq "ARRAY") {
          @{$empty_events->{frozen}->{$_}} = @{$empty_events->{cold}->{$_}};
        } else {
          $empty_events->{frozen}->{$_} = $empty_events->{cold}->{$_};
        }
        $empty_events->{frozen}->{timestamp} = $now;
      }
    }
    $empty_events->{timestamp} = $now;
    if ($mode eq "lookback") {
      $empty_events->{lookback_history} = $last_values->{lookback_history};
      foreach (@keys) {
        if (ref($self->{$_}) eq "ARRAY") {
          @{$empty_events->{lookback_history}->{$_}->{$now}} = @{$self->{$_}};
        } else {
          $empty_events->{lookback_history}->{$_}->{$now} = $self->{$_};
        }
      }
    }
    if ($mode eq "lookback_freeze_defrost") {
      delete $empty_events->{freeze};
    }
    $empty_events;
  };
  $self->save_state(%params);
}

sub create_statefilesdir {
  my ($self) = @_;
  if (! -d $self->statefilesdir()) {
    eval {
      use File::Path;
      mkpath $self->statefilesdir();
    };
    if ($@ || ! -w $self->statefilesdir()) {
      $self->add_message(UNKNOWN,
        sprintf "cannot create status dir %s! check your filesystem (permissions/usage/integrity) and disk devices", $self->statefilesdir());
    }
  } elsif (! -w $self->statefilesdir()) {
    $self->add_message(UNKNOWN,
        sprintf "cannot write status dir %s! check your filesystem (permissions/usage/integrity) and disk devices", $self->statefilesdir());
  }
}

sub create_statefile {
  my ($self, %params) = @_;
  my $extension = "";
  $extension .= $params{name} ? '_'.$params{name} : '';
  $extension =~ s/\//_/g;
  $extension =~ s/\(/_/g;
  $extension =~ s/\)/_/g;
  $extension =~ s/\*/_/g;
  $extension =~ s/\s/_/g;
  return sprintf "%s/%s%s", $self->statefilesdir(),
      $self->clean_path($self->mode), $self->clean_path(lc $extension);
}

sub clean_path {
  my ($self, $path) = @_;
  if ($^O =~ /MSWin/) {
    $path =~ s/:/_/g;
  }
  return $path;
}

sub schimpf {
  my ($self) = @_;
  printf "statefilesdir %s is not writable.\nYou didn't run this plugin as root, didn't you?\n", $self->statefilesdir();
}

# $self->protect_value('1.1-flat_index', 'cpu_busy', 'percent');
sub protect_value {
  my ($self, $ident, $key, $validfunc) = @_;
  if (ref($validfunc) ne "CODE" && $validfunc eq "percent") {
    $validfunc = sub {
      my $value = shift;
      return 0 if ! defined $value;
      return 0 if $value !~ /^[-+]?([0-9]+(\.[0-9]+)?|\.[0-9]+)$/;
      return ($value < 0 || $value > 100) ? 0 : 1;
    };
  } elsif (ref($validfunc) ne "CODE" && $validfunc eq "positive") {
    $validfunc = sub {
      my $value = shift;
      return 0 if ! defined $value;
      return 0 if $value !~ /^[-+]?([0-9]+(\.[0-9]+)?|\.[0-9]+)$/;
      return ($value < 0) ? 0 : 1;
    };
  }
  if (&$validfunc($self->{$key})) {
    $self->save_state(name => 'protect_'.$ident.'_'.$key, save => {
        $key => $self->{$key},
        exception => 0,
    });
  } else {
    # if the device gives us an clearly wrong value, simply use the last value.
    my $laststate = $self->load_state(name => 'protect_'.$ident.'_'.$key) || {
        exception => 0,
    };
    $self->debug(sprintf "self->{%s} is %s and invalid for the %dth time",
        $key, defined $self->{$key} ? $self->{$key} : "<undef>",
         $laststate->{exception} + 1);
    if ($laststate->{exception} <= 5) {
      # but only 5 times.
      # if the error persists, somebody has to check the device.
      $self->{$key} = $laststate->{$key};
    }
    $self->save_state(name => 'protect_'.$ident.'_'.$key, save => {
        $key => $laststate->{$key},
        exception => ++$laststate->{exception},
    });
  }
}

sub save_state {
  my ($self, %params) = @_;
  $self->create_statefilesdir();
  my $statefile = $self->create_statefile(%params);
  my $tmpfile = $statefile.$$.rand();
  if ((ref($params{save}) eq "HASH") && exists $params{save}->{timestamp}) {
    $params{save}->{localtime} = scalar localtime $params{save}->{timestamp};
  }
  my $seekfh = IO::File->new();
  if ($seekfh->open($tmpfile, "w")) {
    my $coder = JSON::XS->new->ascii->pretty->allow_nonref;
    my $jsonscalar = $coder->encode($params{save});
    $seekfh->print($jsonscalar);
    # the very time-consuming old way.
    # $seekfh->printf("%s", Data::Dumper::Dumper($params{save}));
    $seekfh->flush();
    $seekfh->close();
    $self->debug(sprintf "saved %s to %s",
        Data::Dumper::Dumper($params{save}), $statefile);
  }
  if (! rename $tmpfile, $statefile) {
    $self->add_message(UNKNOWN,
        sprintf "cannot write status file %s! check your filesystem (permissions/usage/integrity) and disk devices", $statefile);
  }
}

sub load_state {
  my ($self, %params) = @_;
  my $statefile = $self->create_statefile(%params);
  if ( -f $statefile) {
    our $VAR1;
    eval {
      delete $INC{$statefile} if exists $INC{$statefile}; # else unit tests fail
      my $jsonscalar = read_file($statefile);
      my $coder = JSON::XS->new->ascii->pretty->allow_nonref;
      $VAR1 = $coder->decode($jsonscalar);
    };
    if($@) {
      $self->debug(sprintf "json load from %s failed. fallback", $statefile);
      eval {
        require $statefile;
      };
      if($@) {
        printf "FATAL: Could not load old state in perl format!\n";
      }
    }
    $self->debug(sprintf "load %s from %s", Data::Dumper::Dumper($VAR1), $statefile);
    return $VAR1;
  } else {
    return undef;
  }
}

#########################################################
# daemon mode
#
sub check_pidfile {
  my ($self) = @_;
  my $fh = IO::File->new();
  if ($fh->open($self->{pidfile}, "r")) {
    my $pid = $fh->getline();
    $fh->close();
    if (! $pid) {
      $self->debug("Found pidfile %s with no valid pid. Exiting.",
          $self->{pidfile});
      return 0;
    } else {
      $self->debug("Found pidfile %s with pid %d", $self->{pidfile}, $pid);
      kill 0, $pid;
      if ($! == Errno::ESRCH) {
        $self->debug("This pidfile is stale. Writing a new one");
        $self->write_pidfile();
        return 1;
      } else {
        $self->debug("This pidfile is held by a running process. Exiting");
        return 0;
      }
    }
  } else {
    $self->debug("Found no pidfile. Writing a new one");
    $self->write_pidfile();
    return 1;
  }
}

sub write_pidfile {
  my ($self) = @_;
  if (! -d dirname($self->{pidfile})) {
    eval "require File::Path;";
    if (defined(&File::Path::mkpath)) {
      import File::Path;
      eval { mkpath(dirname($self->{pidfile})); };
    } else {
      my @dirs = ();
      map {
          push @dirs, $_;
          mkdir(join('/', @dirs))
              if join('/', @dirs) && ! -d join('/', @dirs);
      } split(/\//, dirname($self->{pidfile}));
    }
  }
  my $fh = IO::File->new();
  $fh->autoflush(1);
  if ($fh->open($self->{pidfile}, "w")) {
    $fh->printf("%s", $$);
    $fh->close();
  } else {
    $self->debug("Could not write pidfile %s", $self->{pidfile});
    die "pid file could not be written";
  }
}

sub system_vartmpdir {
  my ($self) = @_;
  if ($^O =~ /MSWin/) {
    return $self->system_tmpdir();
  } else {
    return "/var/tmp/".$Monitoring::GLPlugin::pluginname;
  }
}

sub system_tmpdir {
  my ($self) = @_;
  if ($^O =~ /MSWin/) {
    return $ENV{TEMP} if defined $ENV{TEMP};
    return $ENV{TMP} if defined $ENV{TMP};
    return File::Spec->catfile($ENV{windir}, 'Temp')
        if defined $ENV{windir};
    return 'C:\Temp';
  } else {
    return "/tmp";
  }
}

sub convert_scientific_numbers {
  my ($self, $n) = @_;
  # mostly used to convert numbers in scientific notation
  if ($n =~ /^\s*\d+\s*$/) {
    return $n;
  } elsif ($n =~ /^\s*([-+]?)(\d*[\.,]*\d*)[eE]{1}([-+]?)(\d+)\s*$/) {
    my ($vor, $num, $sign, $exp) = ($1, $2, $3, $4);
    $n =~ s/E/e/g;
    $n =~ s/,/\./g;
    $num =~ s/,/\./g;
    my $sig = $sign eq '-' ? "." . ($exp - 1 + length $num) : '';
    my $dec = sprintf "%${sig}f", $n;
    $dec =~ s/\.[0]+$//g;
    return $dec;
  } elsif ($n =~ /^\s*([-+]?)(\d+)[\.,]*(\d*)\s*$/) {
    return $1.$2.".".$3;
  } elsif ($n =~ /^\s*(.*?)\s*$/) {
    return $1;
  } else {
    return $n;
  }
}

sub compatibility_methods {
  my ($self) = @_;
  # add_perfdata
  # add_message
  # nagios_exit
  # ->{warningrange}
  # ->{criticalrange}
  # ...
  $self->{warningrange} = ($self->get_thresholds())[0];
  $self->{criticalrange} = ($self->get_thresholds())[1];
  my $old_init = $self->can('init');
  my %params = (
    'mode' => join('::', split(/-/, $self->opts->mode)),
    'name' => $self->opts->name,
    'name2' => $self->opts->name2,
  );
  {
    no strict 'refs';
    no warnings 'redefine';
    *{ref($self).'::init'} = sub {
      $self->$old_init(%params);
      $self->nagios(%params);
    };
    *{ref($self).'::add_nagios'} = \&{"Monitoring::GLPlugin::add_message"};
    *{ref($self).'::add_nagios_ok'} = \&{"Monitoring::GLPlugin::add_ok"};
    *{ref($self).'::add_nagios_warning'} = \&{"Monitoring::GLPlugin::add_warning"};
    *{ref($self).'::add_nagios_critical'} = \&{"Monitoring::GLPlugin::add_critical"};
    *{ref($self).'::add_nagios_unknown'} = \&{"Monitoring::GLPlugin::add_unknown"};
    *{ref($self).'::add_perfdata'} = sub {
      my $self = shift;
      my $message = shift;
      foreach my $perfdata (split(/\s+/, $message)) {
      my ($label, $perfstr) = split(/=/, $perfdata);
      my ($value, $warn, $crit, $min, $max) = split(/;/, $perfstr);
      $value =~ /^([\d\.\-\+]+)(.*)$/;
      $value = $1;
      my $uom = $2;
      $Monitoring::GLPlugin::plugin->add_perfdata(
        label => $label,
        value => $value,
        uom => $uom,
        warn => $warn,
        crit => $crit,
        min => $min,
        max => $max,
      );
      }
    };
    *{ref($self).'::check_thresholds'} = sub {
      my $self = shift;
      my $value = shift;
      my $defaultwarningrange = shift;
      my $defaultcriticalrange = shift;
      $Monitoring::GLPlugin::plugin->set_thresholds(
          metric => 'default',
          warning => $defaultwarningrange,
          critical => $defaultcriticalrange,
      );
      $self->{warningrange} = ($self->get_thresholds())[0];
      $self->{criticalrange} = ($self->get_thresholds())[1];
      return $Monitoring::GLPlugin::plugin->check_thresholds(
          metric => 'default',
          value => $value,
          warning => $defaultwarningrange,
          critical => $defaultcriticalrange,
      );
    };
  }
}

sub AUTOLOAD {
  my ($self, @params) = @_;
  return if ($AUTOLOAD =~ /DESTROY/);
  $self->debug("AUTOLOAD %s\n", $AUTOLOAD)
        if $self->opts->verbose >= 2;
  if ($AUTOLOAD =~ /^(.*)::analyze_and_check_(.*)_subsystem$/) {
    my $class = $1;
    my $subsystem = $2;
    my $analyze = sprintf "analyze_%s_subsystem", $subsystem;
    my $check = sprintf "check_%s_subsystem", $subsystem;
    if (@params) {
      # analyzer class
      my $subsystem_class = shift @params;
      $self->{components}->{$subsystem.'_subsystem'} = $subsystem_class->new();
      $self->debug(sprintf "\$self->{components}->{%s_subsystem} = %s->new()",
          $subsystem, $subsystem_class);
    } else {
      $self->$analyze();
      $self->debug("call %s()", $analyze);
    }
    $self->$check();
  } elsif ($AUTOLOAD =~ /^(.*)::check_(.*)_subsystem$/) {
    my $class = $1;
    my $subsystem = sprintf "%s_subsystem", $2;
    $self->{components}->{$subsystem}->check();
    $self->{components}->{$subsystem}->dump()
        if $self->opts->verbose >= 2;
  } elsif ($AUTOLOAD =~ /^.*::(status_code|check_messages|nagios_exit|html_string|perfdata_string|selected_perfdata|check_thresholds|get_thresholds|opts|pandora_string|strequal)$/) {
    return $Monitoring::GLPlugin::plugin->$1(@params);
  } elsif ($AUTOLOAD =~ /^.*::(reduce_messages|reduce_messages_short|clear_messages|suppress_messages|add_html|add_perfdata|override_opt|create_opt|set_thresholds|force_thresholds|add_pandora)$/) {
    $Monitoring::GLPlugin::plugin->$1(@params);
  } elsif ($AUTOLOAD =~ /^.*::mod_arg_(.*)$/) {
    return $Monitoring::GLPlugin::plugin->mod_arg($1, @params);
  } else {
    $self->debug("AUTOLOAD: class %s has no method %s\n",
        ref($self), $AUTOLOAD);
  }
}

1;

__END__
