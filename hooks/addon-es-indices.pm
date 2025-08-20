package Genesis::Hook::Addon::Logsearch::Es_indices;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'./.genesis/lib'}

use parent qw(Genesis::Hook::Addon);
use Genesis qw/bail info warning error run/;

# addon-es-indices - List Elasticsearch indices {{{
sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub cmd_details {
  return "List Elasticsearch indices with size and document count information.\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  info("");
  info("Elasticsearch Indices:");
  info("======================");
  info("");

  # Get base domain for constructing URL
  my $base_domain = $env->lookup('params.base_domain', '');
  bail("Missing base_domain parameter") unless $base_domain;

  my $es_url = "https://elasticsearch.$base_domain:9200";

  # List indices with detailed information
  my $indices_cmd = sprintf(
    'curl -sk "%s/_cat/indices?v&s=index&h=index,health,status,pri,rep,docs.count,store.size" -u "elastic:\$(safe read %s/elasticsearch:admin_password)"',
    $es_url,
    $env->lookup('params.vault', 'secret/logsearch')
  );

  my ($output, $rc) = run({interactive => 0}, $indices_cmd);

  if ($rc == 0) {
    info($output);
  } else {
    error("Failed to list indices from Elasticsearch at %s", $es_url);
    error("Command failed with exit code: %d", $rc);
  }

  info("");
  info("Commands:");
  info("  Health status: genesis do %s -- es-health", $env->name);
  info("  Index details: curl -sk '%s/_cat/indices/INDEX_NAME?v' -u 'elastic:\$(safe read %s/elasticsearch:admin_password)'",
    $es_url, $env->lookup('params.vault', 'secret/logsearch'));
  info("");

  return $self->done();
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
