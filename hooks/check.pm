package Genesis::Hook::Check::Logsearch;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::Check);

use Genesis qw/info warning/;

# check.pm - Validate cloud-config and environment configuration {{{
sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->check_minimum_genesis_version('2.8.12');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $ok = 1;

  # Skip cloud config checks for OCFP
  if ($self->want_feature('ocfp')) {
    return $self->check_result('cloud-config', 'skipped', "OCFP env manages its own cloud-config");
  }

  # Cloud Config checks
  if ($ENV{GENESIS_CLOUD_CONFIG}) {
    $ok = 0 unless $self->check_cloud_config();
  }

  # Environment parameter checks
  $ok = 0 unless $self->check_environment_params();

  # Feature-specific checks
  $ok = 0 unless $self->check_feature_requirements();

  # Vault connectivity checks
  $ok = 0 unless $self->check_vault_connectivity();

  return $self->done($ok);
}

# check_cloud_config - Validate cloud config resources {{{
sub check_cloud_config {
  my ($self) = @_;
  
  $self->start_check("Checking cloud config for Logsearch requirements");
  
  my @errors;
  my $ok = 1;
  
  # Get configured resource types
  my $es_master_vm = $self->env->lookup('params.elasticsearch_master_vm_type', 'medium');
  my $es_data_vm = $self->env->lookup('params.elasticsearch_data_vm_type', 'large');
  my $logstash_vm = $self->env->lookup('params.logstash_vm_type', 'medium');
  my $kibana_vm = $self->env->lookup('params.kibana_vm_type', 'small');
  my $maintenance_vm = $self->env->lookup('params.maintenance_vm_type', 'small');
  
  my $es_master_disk = $self->env->lookup('params.elasticsearch_master_disk_type', 'default');
  my $es_data_disk = $self->env->lookup('params.elasticsearch_data_disk_type', 'large');
  
  my $network = $self->env->lookup('params.logsearch_network', 'logsearch');
  
  # Check VM types exist
  push @errors, $self->env->missing_cloud_config_keys(
    vm_type => [
      $es_master_vm,
      $es_data_vm,
      $logstash_vm,
      $kibana_vm,
      $maintenance_vm
    ]
  );
  
  # Check disk types exist
  push @errors, $self->env->missing_cloud_config_keys(
    disk_type => [
      $es_master_disk,
      $es_data_disk
    ]
  );
  
  # Check network exists
  push @errors, $self->env->missing_cloud_config_keys(
    network => [$network]
  );
  
  # Check availability zones
  my $azs = $self->env->lookup('params.availability_zones', ['z1', 'z2', 'z3']);
  if (ref($azs) eq 'ARRAY') {
    push @errors, $self->env->missing_cloud_config_keys(
      az => $azs
    );
  }
  
  # IaaS-specific checks
  my $iaas = $self->env->cpi;
  if ($iaas eq 'azure') {
    # Azure-specific resource checks
    if ($self->want_feature('azure-blobstore')) {
      # Azure blobstore doesn't require additional cloud-config resources
      info("Azure blobstore feature detected - ensure storage account is configured");
    }
  } elsif ($iaas eq 'aws') {
    # AWS-specific resource checks
    if ($self->want_feature('s3-blobstore')) {
      info("S3 blobstore feature detected - ensure IAM permissions are configured");
    }
  } elsif ($iaas eq 'gcp') {
    # GCP-specific resource checks  
    if ($self->want_feature('gcs-blobstore')) {
      info("GCS blobstore feature detected - ensure service account has storage permissions");
    }
  }
  
  if (@errors) {
    $self->check_result(0, join("\n", @errors));
    $ok = 0;
  } else {
    $self->check_result(1);
  }
  
  return $ok;
}
# }}}

# check_environment_params - Validate environment parameters {{{
sub check_environment_params {
  my ($self) = @_;
  
  $self->start_check("Checking environment parameters");
  
  my @errors;
  my $ok = 1;
  
  # Check required base domain
  my $base_domain = $self->env->lookup('params.base_domain', '');
  if (!$base_domain) {
    push @errors, "Missing required parameter: params.base_domain";
  } elsif ($base_domain !~ /^[a-zA-Z0-9]([a-zA-Z0-9\-\.]*[a-zA-Z0-9])?$/) {
    push @errors, "Invalid base_domain format: '$base_domain'";
  }
  
  # Check instance counts
  my $es_instances = $self->env->lookup('params.elasticsearch_instances', 3);
  if ($es_instances !~ /^\d+$/ || $es_instances < 1) {
    push @errors, "elasticsearch_instances must be a positive integer, got: $es_instances";
  } elsif ($es_instances < 3 && !$self->want_feature('small-footprint')) {
    push @errors, "elasticsearch_instances should be at least 3 for production deployments (or use small-footprint feature)";
  }
  
  my $logstash_instances = $self->env->lookup('params.logstash_instances', 2);
  if ($logstash_instances !~ /^\d+$/ || $logstash_instances < 1) {
    push @errors, "logstash_instances must be a positive integer, got: $logstash_instances";
  }
  
  my $kibana_instances = $self->env->lookup('params.kibana_instances', 1);
  if ($kibana_instances !~ /^\d+$/ || $kibana_instances < 1) {
    push @errors, "kibana_instances must be a positive integer, got: $kibana_instances";
  }
  
  # Check heap sizes
  my $es_heap = $self->env->lookup('params.elasticsearch_heap_size', '2g');
  if ($es_heap !~ /^\d+[gGmM]$/) {
    push @errors, "Invalid elasticsearch_heap_size format: '$es_heap' (expected: 2g, 512m, etc.)";
  }
  
  my $logstash_heap = $self->env->lookup('params.logstash_heap_size', '1g');
  if ($logstash_heap !~ /^\d+[gGmM]$/) {
    push @errors, "Invalid logstash_heap_size format: '$logstash_heap' (expected: 2g, 512m, etc.)";
  }
  
  if (@errors) {
    $self->check_result(0, join("\n", @errors));
    $ok = 0;
  } else {
    $self->check_result(1);
  }
  
  return $ok;
}
# }}}

# check_feature_requirements - Validate feature-specific requirements {{{
sub check_feature_requirements {
  my ($self) = @_;
  
  $self->start_check("Checking feature-specific requirements");
  
  my @errors;
  my $ok = 1;
  
  # Check storage backend features
  my @storage_features = grep { 
    $_ eq 's3-blobstore' || $_ eq 'azure-blobstore' || $_ eq 'gcs-blobstore' 
  } $self->features;
  
  if (scalar(@storage_features) > 1) {
    push @errors, "Only one storage backend feature can be enabled: " . join(', ', @storage_features);
  }
  
  # S3 blobstore checks
  if ($self->want_feature('s3-blobstore')) {
    my $bucket = $self->env->lookup('params.s3_bucket', '');
    if (!$bucket) {
      push @errors, "s3-blobstore feature requires params.s3_bucket";
    }
  }
  
  # Azure blobstore checks
  if ($self->want_feature('azure-blobstore')) {
    my $account = $self->env->lookup('params.azure_storage_account', '');
    if (!$account) {
      push @errors, "azure-blobstore feature requires params.azure_storage_account";
    }
  }
  
  # GCS blobstore checks
  if ($self->want_feature('gcs-blobstore')) {
    my $bucket = $self->env->lookup('params.gcs_bucket', '');
    my $project = $self->env->lookup('params.gcp_project_id', '');
    if (!$bucket) {
      push @errors, "gcs-blobstore feature requires params.gcs_bucket";
    }
    if (!$project) {
      push @errors, "gcs-blobstore feature requires params.gcp_project_id";
    }
  }
  
  # External Elasticsearch checks
  if ($self->want_feature('external-elasticsearch')) {
    my $hosts = $self->env->lookup('params.external_elasticsearch_hosts', []);
    if (!ref($hosts) eq 'ARRAY' || !@$hosts) {
      push @errors, "external-elasticsearch feature requires params.external_elasticsearch_hosts array";
    } else {
      for my $host (@$hosts) {
        if ($host !~ /^[a-zA-Z0-9\-\.]+:\d+$/) {
          push @errors, "Invalid external_elasticsearch_hosts entry: '$host' (expected format: host:port)";
        }
      }
    }
    
    # Warn about conflicting features
    if (@storage_features) {
      warning("Storage backend features have no effect with external-elasticsearch");
    }
  }
  
  # Alerting feature checks
  if ($self->want_feature('alerting')) {
    my $email = $self->env->lookup('params.alert_email', '');
    if ($email && $email !~ /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/) {
      push @errors, "Invalid alert_email format: '$email'";
    }
  }
  
  if (@errors) {
    $self->check_result(0, join("\n", @errors));
    $ok = 0;
  } else {
    $self->check_result(1);
  }
  
  return $ok;
}
# }}}

# check_vault_connectivity - Validate Vault connectivity and secrets {{{
sub check_vault_connectivity {
  my ($self) = @_;
  
  $self->start_check("Checking Vault connectivity and secrets");
  
  my $ok = 1;
  my @warnings;
  
  # Check if Vault is accessible
  if (!$self->env->secrets_found) {
    $self->check_result(0, "Unable to connect to Vault - ensure Vault is running and accessible");
    return 0;
  }
  
  # Check if required secret paths exist (but don't validate contents for security)
  my $vault_path = $self->env->lookup('params.vault', 'secret/logsearch');
  my @required_paths = (
    "$vault_path/certs/ca",
    "$vault_path/certs/elasticsearch", 
    "$vault_path/certs/kibana",
    "$vault_path/certs/logstash",
    "$vault_path/elasticsearch",
    "$vault_path/kibana",
    "$vault_path/logstash"
  );
  
  # Add feature-specific secret paths
  if ($self->want_feature('s3-blobstore')) {
    push @required_paths, "$vault_path/s3";
  }
  
  if ($self->want_feature('azure-blobstore')) {
    push @required_paths, "$vault_path/azure";
  }
  
  if ($self->want_feature('gcs-blobstore')) {
    push @required_paths, "$vault_path/gcp";
  }
  
  if ($self->want_feature('external-elasticsearch')) {
    push @required_paths, "$vault_path/external-elasticsearch";
  }
  
  if ($self->want_feature('alerting')) {
    push @required_paths, "$vault_path/smtp";
  }
  
  # Note: We don't actually check if these paths exist during check phase
  # as they may not be generated yet. This is informational.
  info("Required Vault secret paths (will be generated during deployment):");
  for my $path (@required_paths) {
    info("  - $path");
  }
  
  $self->check_result(1);
  
  return $ok;
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1: