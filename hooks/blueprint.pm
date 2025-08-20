package Genesis::Hook::Blueprint::Logsearch;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/
  info warning error bail new_enough debug trace
  in_array uniq compare_arrays
  mkfile_or_fail count_nouns
/;

# blueprint.pm - Generate manifest file list and validate configuration {{{
sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('2.8.12');
  return $obj;
}

sub perform {
  my ($self) = @_;
  return 1 if $self->completed;

  # Always include base manifest
  $self->add_files('manifests/base.yml');

  # Validate and process features
  my @invalid_features = ();
  my @storage_features = ();
  my $has_external_es = 0;

  for my $feature ($self->features) {
    if ($feature eq 'small-footprint') {
      $self->add_files('manifests/features/small-footprint.yml');
      
    } elsif ($feature eq 's3-blobstore') {
      push @storage_features, $feature;
      $self->add_files('manifests/features/s3-blobstore.yml');
      $self->validate_s3_params();
      
    } elsif ($feature eq 'azure-blobstore') {
      push @storage_features, $feature;
      $self->add_files('manifests/features/azure-blobstore.yml');
      $self->validate_azure_params();
      
    } elsif ($feature eq 'gcs-blobstore') {
      push @storage_features, $feature;
      $self->add_files('manifests/features/gcs-blobstore.yml');
      $self->validate_gcs_params();
      
    } elsif ($feature eq 'external-elasticsearch') {
      $has_external_es = 1;
      $self->add_files('manifests/features/external-elasticsearch.yml');
      $self->validate_external_es_params();
      
    } elsif ($feature eq 'prometheus-monitoring') {
      $self->add_files('manifests/features/prometheus-monitoring.yml');
      
    } elsif ($feature eq 'cf-integration') {
      $self->add_files('manifests/features/cf-integration.yml');
      
    } elsif ($feature eq 'custom-parsers') {
      $self->add_files('manifests/addons/custom-parsers.yml');
      
    } elsif ($feature eq 'enhanced-curator') {
      $self->add_files('manifests/addons/curator.yml');
      
    } elsif ($feature eq 'alerting') {
      $self->add_files('manifests/addons/alerting.yml');
      $self->validate_alerting_params();
      
    } else {
      push @invalid_features, $feature;
    }
  }

  # Validate feature combinations
  if (scalar(@storage_features) > 1) {
    bail(
      "Only one storage backend feature can be enabled at a time. Found: %s",
      join(', ', @storage_features)
    );
  }

  if ($has_external_es && @storage_features) {
    warning(
      "Storage backend features (%s) have no effect when using external-elasticsearch",
      join(', ', @storage_features)
    );
  }

  # Report invalid features
  bail(
    "Invalid %s encountered: %s",
    count_nouns(scalar(@invalid_features), 'feature', suppress_count => 1),
    join(', ', @invalid_features)
  ) if @invalid_features;

  # Validate required base parameters
  $self->validate_base_params();

  return $self->done(1);
}

# validate_base_params - Validate required base parameters {{{
sub validate_base_params {
  my ($self) = @_;
  
  my $base_domain = $self->env->lookup('params.base_domain', '');
  bail("Missing required parameter 'params.base_domain'") unless $base_domain;
  
  # Validate base_domain format
  bail("Invalid base_domain format: '%s'", $base_domain) 
    unless $base_domain =~ /^[a-zA-Z0-9]([a-zA-Z0-9\-\.]*[a-zA-Z0-9])?$/;
    
  # Validate instance counts
  my $es_instances = $self->env->lookup('params.elasticsearch_instances', 3);
  bail("elasticsearch_instances must be a positive integer, got: %s", $es_instances)
    unless $es_instances =~ /^\d+$/ && $es_instances > 0;
    
  my $logstash_instances = $self->env->lookup('params.logstash_instances', 2);
  bail("logstash_instances must be a positive integer, got: %s", $logstash_instances)
    unless $logstash_instances =~ /^\d+$/ && $logstash_instances > 0;
    
  my $kibana_instances = $self->env->lookup('params.kibana_instances', 1);
  bail("kibana_instances must be a positive integer, got: %s", $kibana_instances)
    unless $kibana_instances =~ /^\d+$/ && $kibana_instances > 0;

  # Validate heap sizes
  my $es_heap = $self->env->lookup('params.elasticsearch_heap_size', '2g');
  bail("Invalid elasticsearch_heap_size format: '%s' (expected format: 2g, 512m)", $es_heap)
    unless $es_heap =~ /^\d+[gGmM]$/;
    
  my $logstash_heap = $self->env->lookup('params.logstash_heap_size', '1g');
  bail("Invalid logstash_heap_size format: '%s' (expected format: 2g, 512m)", $logstash_heap)
    unless $logstash_heap =~ /^\d+[gGmM]$/;
}
# }}}

# validate_s3_params - Validate S3 blobstore parameters {{{
sub validate_s3_params {
  my ($self) = @_;
  
  my $bucket = $self->env->lookup('params.s3_bucket', '');
  bail("Missing required parameter 'params.s3_bucket' for s3-blobstore feature") unless $bucket;
  
  my $region = $self->env->lookup('params.s3_region', 'us-east-1');
  info("Using S3 region: %s", $region);
}
# }}}

# validate_azure_params - Validate Azure blobstore parameters {{{
sub validate_azure_params {
  my ($self) = @_;
  
  my $account = $self->env->lookup('params.azure_storage_account', '');
  bail("Missing required parameter 'params.azure_storage_account' for azure-blobstore feature") unless $account;
  
  my $container = $self->env->lookup('params.azure_container', 'elasticsearch-snapshots');
  info("Using Azure container: %s", $container);
}
# }}}

# validate_gcs_params - Validate GCS blobstore parameters {{{
sub validate_gcs_params {
  my ($self) = @_;
  
  my $bucket = $self->env->lookup('params.gcs_bucket', '');
  bail("Missing required parameter 'params.gcs_bucket' for gcs-blobstore feature") unless $bucket;
  
  my $project = $self->env->lookup('params.gcp_project_id', '');
  bail("Missing required parameter 'params.gcp_project_id' for gcs-blobstore feature") unless $project;
}
# }}}

# validate_external_es_params - Validate external Elasticsearch parameters {{{
sub validate_external_es_params {
  my ($self) = @_;
  
  my $hosts = $self->env->lookup('params.external_elasticsearch_hosts', []);
  bail("Missing required parameter 'params.external_elasticsearch_hosts' for external-elasticsearch feature") 
    unless ref($hosts) eq 'ARRAY' && @$hosts > 0;
    
  for my $host (@$hosts) {
    bail("Invalid external_elasticsearch_hosts entry: '%s' (expected format: host:port)", $host)
      unless $host =~ /^[a-zA-Z0-9\-\.]+:\d+$/;
  }
  
  info("Using external Elasticsearch cluster with %d hosts", scalar(@$hosts));
}
# }}}

# validate_alerting_params - Validate alerting parameters {{{
sub validate_alerting_params {
  my ($self) = @_;
  
  my $email = $self->env->lookup('params.alert_email', '');
  if ($email) {
    bail("Invalid alert_email format: '%s'", $email)
      unless $email =~ /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  } else {
    warning("No alert_email configured - alerts will not be sent via email");
  }
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1: