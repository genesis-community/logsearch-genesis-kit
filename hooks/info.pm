package Genesis::Hook::Info::Logsearch;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook);

use Genesis qw/bail info warning run read_json_from/;
use JSON::PP;

# info.pm - Display deployment information and service endpoints {{{
sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Get deployment information
  my ($data, $rc, $stderr) = read_json_from($self->env->bosh->execute(
    {interactive => 0}, 'bosh', 'vms', '--json'
  ));
  bail("Failed to get VMs: $stderr") if $rc;

  # Get base domain and build URLs
  my $base_domain = $self->env->lookup('params.base_domain', 'unknown');

  info("");
  info("====================================================================");
  info("Logsearch Deployment Information");
  info("====================================================================");
  info("");

  # Display service endpoints
  info("Service Endpoints:");
  info("  Kibana:        https://kibana.%s", $base_domain);
  info("  Elasticsearch: https://elasticsearch.%s:9200", $base_domain);
  info("  Logstash:      syslog://logstash.%s:5514", $base_domain);
  info("");

  # Display enabled features
  my @features = $self->features;
  if (@features) {
    info("Enabled Features:");
    for my $feature (@features) {
      info("  - %s", $feature);
    }
    info("");
  }

  # Display instance information
  $self->display_instance_info($data);

  # Display cluster sizing information
  $self->display_cluster_info();

  # Display storage backend information
  $self->display_storage_info();

  # Display monitoring information
  $self->display_monitoring_info();

  # Display credential information
  $self->display_credential_info();

  # Display next steps
  $self->display_next_steps();

  return $self->done(1);
}

# display_instance_info - Show instance group details {{{
sub display_instance_info {
  my ($self, $data) = @_;

  info("Instance Groups:");

  my %instance_groups;
  for my $row ($data->{Tables}[0]{Rows}->@*) {
    next unless $row->{instance};
    my $instance_name = $row->{instance};
    my $process_state = $row->{process_state} || 'unknown';
    my $ips = $row->{ips} || 'no-ip';

    # Group by instance type
    if ($instance_name =~ /^(elasticsearch-master|elasticsearch-data|logstash|kibana|maintenance)\//) {
      my $group = $1;
      push @{$instance_groups{$group}}, {
        name => $instance_name,
        state => $process_state,
        ips => $ips
      };
    }
  }

  for my $group (sort keys %instance_groups) {
    info("  %s:", $group);
    for my $instance (@{$instance_groups{$group}}) {
      my $status_indicator = $instance->{state} eq 'running' ? '✓' : '✗';
      info("    %s %s (%s) - %s",
        $status_indicator,
        $instance->{name},
        $instance->{ips},
        $instance->{state}
      );
    }
  }
  info("");
}
# }}}

# display_cluster_info - Show cluster sizing information {{{
sub display_cluster_info {
  my ($self) = @_;

  info("Cluster Configuration:");
  info("  Elasticsearch Instances: %s", $self->env->lookup('params.elasticsearch_instances', 3));
  info("  Logstash Instances:      %s", $self->env->lookup('params.logstash_instances', 2));
  info("  Kibana Instances:        %s", $self->env->lookup('params.kibana_instances', 1));
  info("  Elasticsearch Heap Size: %s", $self->env->lookup('params.elasticsearch_heap_size', '2g'));
  info("  Logstash Heap Size:      %s", $self->env->lookup('params.logstash_heap_size', '1g'));
  info("");
}
# }}}

# display_storage_info - Show storage backend information {{{
sub display_storage_info {
  my ($self) = @_;

  my $storage_configured = 0;

  if ($self->want_feature('s3-blobstore')) {
    info("Storage Backend: Amazon S3");
    info("  Bucket: %s", $self->env->lookup('params.s3_bucket', 'not-configured'));
    info("  Region: %s", $self->env->lookup('params.s3_region', 'us-east-1'));
    $storage_configured = 1;
  } elsif ($self->want_feature('azure-blobstore')) {
    info("Storage Backend: Azure Blob Storage");
    info("  Account: %s", $self->env->lookup('params.azure_storage_account', 'not-configured'));
    info("  Container: %s", $self->env->lookup('params.azure_container', 'elasticsearch-snapshots'));
    $storage_configured = 1;
  } elsif ($self->want_feature('gcs-blobstore')) {
    info("Storage Backend: Google Cloud Storage");
    info("  Bucket: %s", $self->env->lookup('params.gcs_bucket', 'not-configured'));
    info("  Project: %s", $self->env->lookup('params.gcp_project_id', 'not-configured'));
    $storage_configured = 1;
  } elsif ($self->want_feature('external-elasticsearch')) {
    info("Storage Backend: External Elasticsearch");
    my $hosts = $self->env->lookup('params.external_elasticsearch_hosts', []);
    if (ref($hosts) eq 'ARRAY') {
      info("  External Hosts: %s", join(', ', @$hosts));
    }
    $storage_configured = 1;
  }

  if (!$storage_configured) {
    info("Storage Backend: Local persistent disks only");
    warning("  No cloud storage backend configured - snapshots stored locally");
  }
  info("");
}
# }}}

# display_monitoring_info - Show monitoring configuration {{{
sub display_monitoring_info {
  my ($self) = @_;

  if ($self->want_feature('prometheus-monitoring')) {
    info("Monitoring: Prometheus exporters enabled");
    info("  Elasticsearch metrics: :9114/metrics");
    info("  Logstash metrics:      :9198/metrics");
    info("  Node metrics:          :9100/metrics");
  } else {
    info("Monitoring: Basic logging only");
    info("  Consider enabling prometheus-monitoring feature");
  }

  if ($self->want_feature('alerting')) {
    info("  Alerting: Enabled");
    my $email = $self->env->lookup('params.alert_email', 'not-configured');
    info("  Alert Email: %s", $email);
  } else {
    info("  Alerting: Disabled");
  }
  info("");
}
# }}}

# display_credential_info - Show credential location information {{{
sub display_credential_info {
  my ($self) = @_;

  my $vault_path = $self->env->lookup('params.vault', 'secret/logsearch');

  info("Credentials (stored in Vault):");
  info("  Admin Credentials:     %s/elasticsearch:admin_username", $vault_path);
  info("                         %s/elasticsearch:admin_password", $vault_path);
  info("  SSL Certificates:      %s/certs/*", $vault_path);
  info("  System Credentials:    %s/kibana/*", $vault_path);
  info("                         %s/logstash/*", $vault_path);
  info("");
}
# }}}

# display_next_steps - Show operational guidance {{{
sub display_next_steps {
  my ($self) = @_;

  info("Common Operations:");
  info("  Check cluster health:  genesis do %s -- es-health", $self->env->name);
  info("  List indices:          genesis do %s -- es-indices", $self->env->name);
  info("  Open Kibana:           genesis do %s -- visit-kibana", $self->env->name);
  info("  Import dashboards:     genesis do %s -- import-dashboards", $self->env->name);

  if ($self->want_feature('s3-blobstore') || $self->want_feature('azure-blobstore') || $self->want_feature('gcs-blobstore')) {
    info("  Create backup:         genesis do %s -- backup", $self->env->name);
    info("  Restore backup:        genesis do %s -- restore <snapshot>", $self->env->name);
  }

  if ($self->want_feature('custom-parsers')) {
    info("  Setup custom parsers:  genesis do %s -- setup-parsers", $self->env->name);
  }

  info("  Rotate certificates:   genesis do %s -- rotate-certs", $self->env->name);
  info("");

  info("Documentation:");
  info("  Kit Manual:  https://github.com/genesis-community/logsearch-genesis-kit/blob/main/MANUAL.md");
  info("  Kit GitHub:  https://github.com/genesis-community/logsearch-genesis-kit");
  info("");

  info("====================================================================");
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
