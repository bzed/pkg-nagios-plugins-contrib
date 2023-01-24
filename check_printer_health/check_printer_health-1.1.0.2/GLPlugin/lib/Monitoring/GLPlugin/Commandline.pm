package Monitoring::GLPlugin::Commandline;
use strict;
use IO::File;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3, DEPENDENT => 4 };
our %ERRORS = (
    'OK'        => OK,
    'WARNING'   => WARNING,
    'CRITICAL'  => CRITICAL,
    'UNKNOWN'   => UNKNOWN,
    'DEPENDENT' => DEPENDENT,
);

our %STATUS_TEXT = reverse %ERRORS;
our $AUTOLOAD;


sub new {
  my ($class, %params) = @_;
  require Monitoring::GLPlugin::Commandline::Getopt
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::Commandline::Getopt::;
  my $self = {
       perfdata => [],
       messages => {
         ok => [],
         warning => [],
         critical => [],
         unknown => [],
       },
       args => [],
       opts => Monitoring::GLPlugin::Commandline::Getopt->new(%params),
       modes => [],
       statefilesdir => undef,
  };
  foreach (qw(shortname usage version url plugin blurb extra
      license timeout)) {
    $self->{$_} = $params{$_};
  }
  bless $self, $class;
  $self->{plugin} ||= $Monitoring::GLPlugin::pluginname;
  $self->{name} = $self->{plugin};
  $Monitoring::GLPlugin::plugin = $self;
}

sub AUTOLOAD {
  my ($self, @params) = @_;
  return if ($AUTOLOAD =~ /DESTROY/);
  $self->debug("AUTOLOAD %s\n", $AUTOLOAD)
        if $self->{opts}->verbose >= 2;
  if ($AUTOLOAD =~ /^.*::(add_arg|override_opt|create_opt)$/) {
    $self->{opts}->$1(@params);
  }
}

sub DESTROY {
  my ($self) = @_;
  # ohne dieses DESTROY rennt nagios_exit in obiges AUTOLOAD rein
  # und fliegt aufs Maul, weil {opts} bereits nicht mehr existiert.
  # Unerklaerliches Verhalten.
}

sub debug {
  my ($self, $format, @message) = @_;
  if ($self->opts->verbose && $self->opts->verbose > 10) {
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

sub opts {
  my ($self) = @_;
  return $self->{opts};
}

sub getopts {
  my ($self) = @_;
  $self->opts->getopts();
}

sub add_message {
  my ($self, $code, @messages) = @_;
  $code = (qw(ok warning critical unknown))[$code] if $code =~ /^\d+$/;
  $code = lc $code;
  push @{$self->{messages}->{$code}}, @messages;
}

sub selected_perfdata {
  my ($self, $label) = @_;
  if ($self->opts->can("selectedperfdata") && $self->opts->selectedperfdata) {
    my $pattern = $self->opts->selectedperfdata;
    return ($label =~ /$pattern/i) ? 1 : 0;
  } else {
    return 1;
  }
}

sub add_perfdata {
  my ($self, %args) = @_;
#printf "add_perfdata %s\n", Data::Dumper::Dumper(\%args);
#printf "add_perfdata %s\n", Data::Dumper::Dumper($self->{thresholds});
#
# wenn warning, critical, dann wird von oben ein expliziter wert mitgegeben
# wenn thresholds
#  wenn label in 
#    warningx $self->{thresholds}->{$label}->{warning} existiert
#  dann nimm $self->{thresholds}->{$label}->{warning}
#  ansonsten thresholds->default->warning
#

  my $label = $args{label};
  my $value = $args{value};
  my $uom = $args{uom} || "";
  my $format = '%d';

  if ($self->opts->can("morphperfdata") && $self->opts->morphperfdata) {
    # 'Intel [R] Interface (\d+) usage'='nic$1'
    foreach my $key (keys %{$self->opts->morphperfdata}) {
      if ($label =~ /$key/) {
        my $replacement = '"'.$self->opts->morphperfdata->{$key}.'"';
        my $oldlabel = $label;
        $label =~ s/$key/$replacement/ee;
        if (exists $self->{thresholds}->{$oldlabel}) {
          %{$self->{thresholds}->{$label}} = %{$self->{thresholds}->{$oldlabel}};
        }
      }
    }
  }
  if ($value =~ /\./) {
    if (defined $args{places}) {
      $value = sprintf '%.'.$args{places}.'f', $value;
    } else {
      $value = sprintf "%.2f", $value;
    }
  } else {
    $value = sprintf "%d", $value;
  }
  my $warn = "";
  my $crit = "";
  my $min = defined $args{min} ? $args{min} : "";
  my $max = defined $args{max} ? $args{max} : "";
  if ($args{thresholds} || (! exists $args{warning} && ! exists $args{critical})) {
    if (exists $self->{thresholds}->{$label}->{warning}) {
      $warn = $self->{thresholds}->{$label}->{warning};
    } elsif (exists $self->{thresholds}->{default}->{warning}) {
      $warn = $self->{thresholds}->{default}->{warning};
    }
    if (exists $self->{thresholds}->{$label}->{critical}) {
      $crit = $self->{thresholds}->{$label}->{critical};
    } elsif (exists $self->{thresholds}->{default}->{critical}) {
      $crit = $self->{thresholds}->{default}->{critical};
    }
  } else {
    if ($args{warning}) {
      $warn = $args{warning};
    }
    if ($args{critical}) {
      $crit = $args{critical};
    }
  }
  if ($uom eq "%") {
    $min = 0;
    $max = 100;
  }
  if (defined $args{places}) {
    # cut off excessive decimals which may be the result of a division
    # length = places*2, no trailing zeroes
    if ($warn ne "") {
      $warn = join("", map {
          s/\.0+$//; $_
      } map {
          s/(\.[1-9]+)0+$/$1/; $_
      } map {
          /[\+\-\d\.]+/ ? sprintf '%.'.2*$args{places}.'f', $_ : $_;
      } split(/([\+\-\d\.]+)/, $warn));
    }
    if ($crit ne "") {
      $crit = join("", map {
          s/\.0+$//; $_
      } map {
          s/(\.[1-9]+)0+$/$1/; $_
      } map {
          /[\+\-\d\.]+/ ? sprintf '%.'.2*$args{places}.'f', $_ : $_;
      } split(/([\+\-\d\.]+)/, $crit));
    }
    if ($min ne "") {
      $min = join("", map {
          s/\.0+$//; $_
      } map {
          s/(\.[1-9]+)0+$/$1/; $_
      } map {
          /[\+\-\d\.]+/ ? sprintf '%.'.2*$args{places}.'f', $_ : $_;
      } split(/([\+\-\d\.]+)/, $min));
    }
    if ($max ne "") {
      $max = join("", map {
          s/\.0+$//; $_
      } map {
          s/(\.[1-9]+)0+$/$1/; $_
      } map {
          /[\+\-\d\.]+/ ? sprintf '%.'.2*$args{places}.'f', $_ : $_;
      } split(/([\+\-\d\.]+)/, $max));
    }
  }
  push @{$self->{perfdata}}, sprintf("'%s'=%s%s;%s;%s;%s;%s",
      $label, $value, $uom, $warn, $crit, $min, $max)
      if $self->selected_perfdata($label);
}

sub add_pandora {
  my ($self, %args) = @_;
  my $label = $args{label};
  my $value = $args{value};

  if ($args{help}) {
    push @{$self->{pandora}}, sprintf("# HELP %s %s", $label, $args{help});
  }
  if ($args{type}) {
    push @{$self->{pandora}}, sprintf("# TYPE %s %s", $label, $args{type});
  }
  if ($args{labels}) {
    push @{$self->{pandora}}, sprintf("%s{%s} %s", $label,
        join(",", map {
            sprintf '%s="%s"', $_, $args{labels}->{$_};
        } keys %{$args{labels}}),
        $value);
  } else {
    push @{$self->{pandora}}, sprintf("%s %s", $label, $value);
  }
}

sub add_html {
  my ($self, $line) = @_;
  push @{$self->{html}}, $line;
}

sub suppress_messages {
  my ($self) = @_;
  $self->{suppress_messages} = 1;
}

sub clear_messages {
  my ($self, $code) = @_;
  $code = (qw(ok warning critical unknown))[$code] if $code =~ /^\d+$/;
  $code = lc $code;
  $self->{messages}->{$code} = [];
}

sub reduce_messages_short {
  my ($self, $message) = @_;
  $message ||= "no problems";
  if ($self->opts->report && $self->opts->report eq "short") {
    $self->clear_messages(OK);
    $self->add_message(OK, $message) if ! $self->check_messages();
  }
}

sub reduce_messages {
  my ($self, $message) = @_;
  $message ||= "no problems";
  $self->clear_messages(OK);
  $self->add_message(OK, $message) if ! $self->check_messages();
}

sub check_messages {
  my ($self, %args) = @_;

  # Add object messages to any passed in as args
  for my $code (qw(critical warning unknown ok)) {
    my $messages = $self->{messages}->{$code} || [];
    if ($args{$code}) {
      unless (ref $args{$code} eq 'ARRAY') {
        if ($code eq 'ok') {
          $args{$code} = [ $args{$code} ];
        }
      }
      push @{$args{$code}}, @$messages;
    } else {
      $args{$code} = $messages;
    }
  }
  my %arg = %args;
  $arg{join} = ' ' unless defined $arg{join};

  # Decide $code
  my $code = OK;
  $code ||= CRITICAL  if @{$arg{critical}};
  $code ||= WARNING   if @{$arg{warning}};
  $code ||= UNKNOWN   if @{$arg{unknown}};
  return $code unless wantarray;

  # Compose message
  my $message = '';
  if ($arg{join_all}) {
      $message = join( $arg{join_all},
          map { @$_ ? join( $arg{'join'}, @$_) : () }
              $arg{critical},
              $arg{warning},
              $arg{unknown},
              $arg{ok} ? (ref $arg{ok} ? $arg{ok} : [ $arg{ok} ]) : []
      );
  }

  else {
      $message ||= join( $arg{'join'}, @{$arg{critical}} )
          if $code == CRITICAL;
      $message ||= join( $arg{'join'}, @{$arg{warning}} )
          if $code == WARNING;
      $message ||= join( $arg{'join'}, @{$arg{unknown}} )
          if $code == UNKNOWN;
      $message ||= ref $arg{ok} ? join( $arg{'join'}, @{$arg{ok}} ) : $arg{ok}
          if $arg{ok};
  }

  return ($code, $message);
}

sub status_code {
  my ($self, $code) = @_;
  $code = (qw(ok warning critical unknown))[$code] if $code =~ /^\d+$/;
  $code = uc $code;
  $code = $ERRORS{$code} if defined $code && exists $ERRORS{$code};
  $code = UNKNOWN unless defined $code && exists $STATUS_TEXT{$code};
  return "$STATUS_TEXT{$code}";
}

sub perfdata_string {
  my ($self) = @_;
  if (scalar (@{$self->{perfdata}})) {
    return join(" ", @{$self->{perfdata}});
  } else {
    return "";
  }
}

sub metrics_string {
  my ($self) = @_;
  if (scalar (@{$self->{metrics}})) {
    return join("\n", @{$self->{metrics}});
  } else {
    return "";
  }
}

sub html_string {
  my ($self) = @_;
  if (scalar (@{$self->{html}})) {
    return join(" ", @{$self->{html}});
  } else {
    return "";
  }
}

sub nagios_exit {
  my ($self, $code, $message, $arg) = @_;
  $code = $ERRORS{$code} if defined $code && exists $ERRORS{$code};
  $code = UNKNOWN unless defined $code && exists $STATUS_TEXT{$code};
  $message = '' unless defined $message;
  if (ref $message && ref $message eq 'ARRAY') {
      $message = join(' ', map { chomp; $_ } @$message);
  } else {
      chomp $message;
  }
  if ($self->opts->negate) {
    my $original_code = $code;
    foreach my $from (keys %{$self->opts->negate}) {
      if ((uc $from) =~ /^(OK|WARNING|CRITICAL|UNKNOWN)$/ &&
          (uc $self->opts->negate->{$from}) =~ /^(OK|WARNING|CRITICAL|UNKNOWN)$/) {
        if ($original_code == $ERRORS{uc $from}) {
          $code = $ERRORS{uc $self->opts->negate->{$from}};
        }
      }
    }
  }
  my $output = "$STATUS_TEXT{$code}";
  $output .= " - $message" if defined $message && $message ne '';
  if ($self->opts->can("morphmessage") && $self->opts->morphmessage) {
    # 'Intel [R] Interface (\d+) usage'='nic$1'
    # '^OK.*'="alles klar"   '^CRITICAL.*'="alles hi"
    foreach my $key (keys %{$self->opts->morphmessage}) {
      if ($output =~ /$key/) {
        my $replacement = '"'.$self->opts->morphmessage->{$key}.'"';
        $output =~ s/$key/$replacement/ee;
      }
    }
  }
  if ($self->opts->negate) {
    # negate again: --negate "UNKNOWN - no peers"=ok
    my $original_code = $code;
    foreach my $from (keys %{$self->opts->negate}) {
      if ((uc $from) !~ /^(OK|WARNING|CRITICAL|UNKNOWN)$/ &&
          (uc $self->opts->negate->{$from}) =~ /^(OK|WARNING|CRITICAL|UNKNOWN)$/) {
        if ($output =~ /$from/) {
          $code = $ERRORS{uc $self->opts->negate->{$from}};
          $output =~ s/^.*? -/$STATUS_TEXT{$code} -/;
        }
      }
    }
  }
  $output =~ s/\|/!/g if $output;
  if (scalar (@{$self->{perfdata}})) {
    $output .= " | ".$self->perfdata_string();
  }
  $output .= "\n";
  if ($self->opts->can("isvalidtime") && ! $self->opts->isvalidtime) {
    $code = OK;
    $output = "OK - outside valid timerange. check results are not relevant now. original message was: ".
        $output;
  }
  if (! exists $self->{suppress_messages}) {
    $output =~ s/[^[:ascii:]]//g;
    print $output;
  }
  exit $code;
}

sub set_thresholds {
  my ($self, %params) = @_;
  if (exists $params{metric}) {
    my $metric = $params{metric};
    # erst die hartcodierten defaultschwellwerte
    $self->{thresholds}->{$metric}->{warning} = $params{warning};
    $self->{thresholds}->{$metric}->{critical} = $params{critical};
    # dann die defaultschwellwerte von der kommandozeile
    if (defined $self->opts->warning) {
      $self->{thresholds}->{$metric}->{warning} = $self->opts->warning;
    }
    if (defined $self->opts->critical) {
      $self->{thresholds}->{$metric}->{critical} = $self->opts->critical;
    }
    # dann die ganz spezifischen schwellwerte von der kommandozeile
    if ($self->opts->warningx) { # muss nicht auf defined geprueft werden, weils ein hash ist
      # Erst schauen, ob einer * beinhaltet. Von denen wird vom Laengsten
      # bis zum Kuerzesten probiert, ob die matchen. Der laengste Match
      # gewinnt.
      my @keys = keys %{$self->opts->warningx};
      my @stringkeys = ();
      my @regexkeys = ();
      foreach my $key (sort { length($b) > length($a) } @keys) {
        if ($key =~ /\*/) {
          push(@regexkeys, $key);
        } else {
          push(@stringkeys, $key);
        }
      }
      foreach my $key (@regexkeys) {
        next if $metric !~ /$key/;
        $self->{thresholds}->{$metric}->{warning} = $self->opts->warningx->{$key};
        last;
      }
      # Anschliessend nochmal schauen, ob es einen nicht-Regex-Volltreffer gibt
      foreach my $key (@stringkeys) {
        next if $key ne $metric;
        $self->{thresholds}->{$metric}->{warning} = $self->opts->warningx->{$key};
        last;
      }
    }
    if ($self->opts->criticalx) {
      my @keys = keys %{$self->opts->criticalx};
      my @stringkeys = ();
      my @regexkeys = ();
      foreach my $key (sort { length($b) > length($a) } @keys) {
        if ($key =~ /\*/) {
          push(@regexkeys, $key);
        } else {
          push(@stringkeys, $key);
        }
      }
      foreach my $key (@regexkeys) {
        next if $metric !~ /$key/;
        $self->{thresholds}->{$metric}->{critical} = $self->opts->criticalx->{$key};
        last;
      }
      # Anschliessend nochmal schauen, ob es einen nicht-Regex-Volltreffer gibt
      foreach my $key (@stringkeys) {
        next if $key ne $metric;
        $self->{thresholds}->{$metric}->{critical} = $self->opts->criticalx->{$key};
        last;
      }
    }
  } else {
    $self->{thresholds}->{default}->{warning} =
        defined $self->opts->warning ? $self->opts->warning : defined $params{warning} ? $params{warning} : 0;
    $self->{thresholds}->{default}->{critical} =
        defined $self->opts->critical ? $self->opts->critical : defined $params{critical} ? $params{critical} : 0;
  }
}

sub force_thresholds {
  my ($self, %params) = @_;
  if (exists $params{metric}) {
    my $metric = $params{metric};
    $self->{thresholds}->{$metric}->{warning} = $params{warning} || 0;
    $self->{thresholds}->{$metric}->{critical} = $params{critical} || 0;
  } else {
    $self->{thresholds}->{default}->{warning} = $params{warning} || 0;
    $self->{thresholds}->{default}->{critical} = $params{critical} || 0;
  }
}

sub get_thresholds {
  my ($self, @params) = @_;
  if (scalar(@params) > 1) {
    my %params = @params;
    my $metric = $params{metric};
    return ($self->{thresholds}->{$metric}->{warning},
        $self->{thresholds}->{$metric}->{critical});
  } else {
    return ($self->{thresholds}->{default}->{warning},
        $self->{thresholds}->{default}->{critical});
  }
}

sub check_thresholds {
  my ($self, @params) = @_;
  my $level = $ERRORS{OK};
  my $warningrange;
  my $criticalrange;
  my $value;
  if (scalar(@params) > 1) {
    my %params = @params;
    $value = $params{value};
    my $metric = $params{metric};
    if ($metric ne 'default') {
      $warningrange = defined $params{warning} ? $params{warning} :
          (exists $self->{thresholds}->{$metric}->{warning} ?
              $self->{thresholds}->{$metric}->{warning} :
              $self->{thresholds}->{default}->{warning});
      $criticalrange = defined $params{critical} ? $params{critical} :
          (exists $self->{thresholds}->{$metric}->{critical} ?
              $self->{thresholds}->{$metric}->{critical} :
              $self->{thresholds}->{default}->{critical});
    } else {
      $warningrange = (defined $params{warning}) ?
          $params{warning} : $self->{thresholds}->{default}->{warning};
      $criticalrange = (defined $params{critical}) ?
          $params{critical} : $self->{thresholds}->{default}->{critical};
    }
  } else {
    $value = $params[0];
    $warningrange = $self->{thresholds}->{default}->{warning};
    $criticalrange = $self->{thresholds}->{default}->{critical};
  }
  if (! defined $warningrange) {
    # there was no set_thresholds for defaults, no --warning, no --warningx
  } elsif ($warningrange =~ /^([-+]?[0-9]*\.?[0-9]+)$/) {
    # warning = 10, warn if > 10 or < 0
    $level = $ERRORS{WARNING}
        if ($value > $1 || $value < 0);
  } elsif ($warningrange =~ /^([-+]?[0-9]*\.?[0-9]+):$/) {
    # warning = 10:, warn if < 10
    $level = $ERRORS{WARNING}
        if ($value < $1);
  } elsif ($warningrange =~ /^~:([-+]?[0-9]*\.?[0-9]+)$/) {
    # warning = ~:10, warn if > 10
    $level = $ERRORS{WARNING}
        if ($value > $1);
  } elsif ($warningrange =~ /^([-+]?[0-9]*\.?[0-9]+):([-+]?[0-9]*\.?[0-9]+)$/) {
    # warning = 10:20, warn if < 10 or > 20
    $level = $ERRORS{WARNING}
        if ($value < $1 || $value > $2);
  } elsif ($warningrange =~ /^@([-+]?[0-9]*\.?[0-9]+):([-+]?[0-9]*\.?[0-9]+)$/) {
    # warning = @10:20, warn if >= 10 and <= 20
    $level = $ERRORS{WARNING}
        if ($value >= $1 && $value <= $2);
  }
  if (! defined $criticalrange) {
    # there was no set_thresholds for defaults, no --critical, no --criticalx
  } elsif ($criticalrange =~ /^([-+]?[0-9]*\.?[0-9]+)$/) {
    # critical = 10, crit if > 10 or < 0
    $level = $ERRORS{CRITICAL}
        if ($value > $1 || $value < 0);
  } elsif ($criticalrange =~ /^([-+]?[0-9]*\.?[0-9]+):$/) {
    # critical = 10:, crit if < 10
    $level = $ERRORS{CRITICAL}
        if ($value < $1);
  } elsif ($criticalrange =~ /^~:([-+]?[0-9]*\.?[0-9]+)$/) {
    # critical = ~:10, crit if > 10
    $level = $ERRORS{CRITICAL}
        if ($value > $1);
  } elsif ($criticalrange =~ /^([-+]?[0-9]*\.?[0-9]+):([-+]?[0-9]*\.?[0-9]+)$/) {
    # critical = 10:20, crit if < 10 or > 20
    $level = $ERRORS{CRITICAL}
        if ($value < $1 || $value > $2);
  } elsif ($criticalrange =~ /^@([-+]?[0-9]*\.?[0-9]+):([-+]?[0-9]*\.?[0-9]+)$/) {
    # critical = @10:20, crit if >= 10 and <= 20
    $level = $ERRORS{CRITICAL}
        if ($value >= $1 && $value <= $2);
  }
  return $level;
}

sub strequal {
  my($self, $str1, $str2) = @_;
  return 1 if ! defined $str1 && ! defined $str2;
  return 0 if ! defined $str1 && defined $str2;
  return 0 if defined $str1 && ! defined $str2;
  return 1 if $str1 eq $str2;
  return 0;
}

1;

__END__
