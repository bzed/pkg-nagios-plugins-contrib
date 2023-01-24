package Monitoring::GLPlugin::UPNP;
our @ISA = qw(Monitoring::GLPlugin);
# ABSTRACT: helper functions to build a upnp-based monitoring plugin

use strict;
use File::Basename;
use Digest::MD5 qw(md5_hex);
use AutoLoader;
our $AUTOLOAD;

use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

{
  our $mode = undef;
  our $plugin = undef;
  our $blacklist = undef;
  our $session = undef;
  our $rawdata = {};
  our $info = [];
  our $extendedinfo = [];
  our $summary = [];
  our $oidtrace = [];
  our $uptime = 0;
}

sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::walk/) {
  } elsif ($self->mode =~ /device::uptime/) {
    my $info = sprintf 'device is up since %s',
        $self->human_timeticks($self->{uptime});
    $self->add_info($info);
    $self->set_thresholds(warning => '15:', critical => '5:');
    $self->add_message($self->check_thresholds($self->{uptime}), $info);
    $self->add_perfdata(
        label => 'uptime',
        value => $self->{uptime} / 60,
        warning => $self->{warning},
        critical => $self->{critical},
    );
    my ($code, $message) = $self->check_messages(join => ', ', join_all => ', ');
    $Monitoring::GLPlugin::plugin->nagios_exit($code, $message);
  }
}

sub check_upnp_and_model {
  my ($self) = @_;
  if (eval "require SOAP::Lite") {
    require XML::LibXML;
  } else {
    $self->add_critical('could not find SOAP::Lite module');
  }
  $self->{services} = {};
  if (! $self->check_messages()) {
    eval {
      my $igddesc = sprintf "http://%s:%s/igddesc.xml",
          $self->opts->hostname, $self->opts->port;
      my $parser = XML::LibXML->new();
      my $doc = $parser->parse_file($igddesc);
      my $root = $doc->documentElement();
      my $xpc = XML::LibXML::XPathContext->new( $root );
      $xpc->registerNs('n', 'urn:schemas-upnp-org:device-1-0');
      $self->{productname} = $xpc->findvalue('(//n:device)[position()=1]/n:modelName' );
      $self->debug(sprintf "igddesc productname is %s", $self->{productname});
      my @services = ();
      my @servicedescs = $xpc->find('(//n:service)')->get_nodelist;
      foreach my $service (@servicedescs) {
        my $servicetype = undef;
        my $serviceid = undef;
        my $controlurl = undef;
        foreach my $node ($service->nonBlankChildNodes("./*")) {
          $serviceid = $node->textContent if ($node->nodeName eq "serviceId");
          $servicetype = $node->textContent if ($node->nodeName eq "serviceType");
          $controlurl = $node->textContent if ($node->nodeName eq "controlURL");
        }
        if ($serviceid && $controlurl) {
          push(@services, {
              serviceType => $servicetype,
              serviceId => $serviceid,
              controlURL => sprintf('http://%s:%s%s',
                  $self->opts->hostname, $self->opts->port, $controlurl),
          });
          $self->debug(sprintf "found %s service %s",
              $servicetype, $serviceid);
        }
      }
      $self->set_variable('services', \@services);
    };
    if ($@) {
      $self->add_critical($@);
    }
  }
  if (! $self->check_messages()) {
    eval {
      my $service = (grep { $_->{serviceId} =~ /WANIPConn1/ } @{$self->get_variable('services')})[0];
      my $som = SOAP::Lite
          -> proxy($service->{controlURL})
          -> uri($service->{serviceType})
          -> GetStatusInfo();
      $self->{uptime} = $som->valueof("//GetStatusInfoResponse/NewUptime");
      $self->{uptime} /= 1.0;
      $self->debug("WANIPConn1->GetStatusInfo returned uptime");
    };
    if ($@) {
      $self->add_critical("could not get uptime: ".$@);
    }
  }
}

sub create_statefile {
  my ($self, %params) = @_;
  my $extension = "";
  $extension .= $params{name} ? '_'.$params{name} : '';
  if ($self->opts->community) {
    $extension .= md5_hex($self->opts->community);
  }
  $extension =~ s/\//_/g;
  $extension =~ s/\(/_/g;
  $extension =~ s/\)/_/g;
  $extension =~ s/\*/_/g;
  $extension =~ s/\s/_/g;
  if ($^O =~ /MSWin/) {
    $extension =~ s/:/_/g;
  }
  return sprintf "%s/%s_%s%s", $self->statefilesdir(),
      $self->opts->hostname, $self->opts->mode, lc $extension;
}

1;

__END__
