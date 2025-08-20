package Genesis::Hook::Addon::Logsearch::Visit_kibana;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'./.genesis/lib'}

use parent qw(Genesis::Hook::Addon);
use Genesis qw/bail info warning run/;

# addon-visit-kibana - Open Kibana in browser {{{
sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub cmd_details {
  return "Open Kibana web interface in your default browser.\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Get base domain for constructing URL
  my $base_domain = $env->lookup('params.base_domain', '');
  bail("Missing base_domain parameter") unless $base_domain;

  my $kibana_url = "https://kibana.$base_domain";

  info("");
  info("Opening Kibana in your default browser...");
  info("URL: %s", $kibana_url);
  info("");

  # Try to detect the platform and open the appropriate browser
  my $open_cmd;

  if ($^O eq 'darwin') {
    # macOS
    $open_cmd = "open '$kibana_url'";
  } elsif ($^O eq 'linux') {
    # Linux
    $open_cmd = "xdg-open '$kibana_url'";
  } elsif ($^O eq 'MSWin32' || $^O eq 'cygwin') {
    # Windows
    $open_cmd = "start '$kibana_url'";
  } else {
    warning("Unable to detect platform to open browser automatically");
    info("Please manually open: %s", $kibana_url);
    return $self->done();
  }

  my ($output, $rc) = run({interactive => 0}, $open_cmd);

  if ($rc == 0) {
    info("Successfully opened Kibana in browser");
    info("");
    info("First-time setup:");
    info("  1. Create an index pattern (e.g., 'logs-*')");
    info("  2. Set @timestamp as the time field");
    info("  3. Start exploring your logs!");
    info("");
    info("Credentials are stored in Vault at:");
    info("  %s/elasticsearch:admin_username", $env->lookup('params.vault', 'secret/logsearch'));
    info("  %s/elasticsearch:admin_password", $env->lookup('params.vault', 'secret/logsearch'));
    info("");
  } else {
    warning("Failed to open browser automatically");
    info("Please manually open: %s", $kibana_url);
    info("");
  }

  return $self->done();
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
