package Genesis::Hook::Addon::Logsearch::Es_health;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'./.genesis/lib'}

use parent qw(Genesis::Hook::Addon);
use Genesis qw/bail info warning error run/;
use JSON::PP;

# addon-es-health - Check Elasticsearch cluster health {{{
sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('2.8.12');
  return $obj;
}

sub cmd_details {
  return "Check Elasticsearch cluster health and status.\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;
  
  info("");
  info("Checking Elasticsearch cluster health...");
  info("");
  
  # Get base domain for constructing URL
  my $base_domain = $env->lookup('params.base_domain', '');
  bail("Missing base_domain parameter") unless $base_domain;
  
  my $es_url = "https://elasticsearch.$base_domain:9200";
  
  # Check cluster health
  info("Cluster Health:");
  info("================");
  
  my $health_cmd = sprintf(
    'curl -sk "%s/_cluster/health?pretty" -u "elastic:\$(safe read %s/elasticsearch:admin_password)"',
    $es_url,
    $env->lookup('params.vault', 'secret/logsearch')
  );
  
  my ($health_output, $health_rc) = run({interactive => 0}, $health_cmd);
  
  if ($health_rc == 0) {
    # Parse and display health status
    eval {
      my $health = decode_json($health_output);
      info("Status: %s", $health->{status});
      info("Nodes: %d", $health->{number_of_nodes});
      info("Data Nodes: %d", $health->{number_of_data_nodes});
      info("Active Shards: %d", $health->{active_shards});
      info("Relocating Shards: %d", $health->{relocating_shards});
      info("Initializing Shards: %d", $health->{initializing_shards});
      info("Unassigned Shards: %d", $health->{unassigned_shards});
      
      if ($health->{status} eq 'red') {
        error("Cluster status is RED - immediate attention required!");
      } elsif ($health->{status} eq 'yellow') {
        warning("Cluster status is YELLOW - some replicas may be unassigned");
      } else {
        info("Cluster status is GREEN - all good!");
      }
    };
    if ($@) {
      warning("Failed to parse health response as JSON, raw output:");
      info($health_output);
    }
  } else {
    error("Failed to connect to Elasticsearch at %s", $es_url);
    error("Health check command failed with exit code: %d", $health_rc);
  }
  
  info("");
  
  # Check cluster stats
  info("Cluster Stats:");
  info("==============");
  
  my $stats_cmd = sprintf(
    'curl -sk "%s/_cluster/stats?pretty" -u "elastic:\$(safe read %s/elasticsearch:admin_password)"',
    $es_url,
    $env->lookup('params.vault', 'secret/logsearch')
  );
  
  my ($stats_output, $stats_rc) = run({interactive => 0}, $stats_cmd);
  
  if ($stats_rc == 0) {
    eval {
      my $stats = decode_json($stats_output);
      info("Indices: %d", $stats->{indices}{count});
      info("Documents: %d", $stats->{indices}{docs}{count});
      info("Store Size: %s", format_bytes($stats->{indices}{store}{size_in_bytes}));
      info("JVM Heap Used: %s", format_bytes($stats->{nodes}{jvm}{mem}{heap_used_in_bytes}));
      info("JVM Heap Max: %s", format_bytes($stats->{nodes}{jvm}{mem}{heap_max_in_bytes}));
    };
    if ($@) {
      warning("Failed to parse stats response as JSON");
    }
  } else {
    warning("Failed to get cluster stats");
  }
  
  info("");
  info("Use 'genesis do %s -- es-indices' to list indices", $env->name);
  info("");
  
  return $self->done();
}

# format_bytes - Format bytes into human readable format {{{
sub format_bytes {
  my $bytes = shift || 0;
  my @units = qw(B KB MB GB TB);
  my $unit_index = 0;
  
  while ($bytes >= 1024 && $unit_index < @units - 1) {
    $bytes /= 1024;
    $unit_index++;
  }
  
  return sprintf("%.1f %s", $bytes, $units[$unit_index]);
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1: