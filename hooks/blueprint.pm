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

  # Check for OCFP feature first
  if ($self->want_feature("ocfp")) {
    $self->validate_ocfp_features();
    return $self->process_ocfp_features();
  }

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
      
    } elsif ($feature eq 'oauth-authentication') {
      $self->add_files('manifests/features/oauth-authentication.yml');
      $self->validate_oauth_params();
      
    } elsif ($feature eq 'shield-integration') {
      $self->add_files('manifests/features/shield-integration.yml');
      $self->validate_shield_params();
      
    } elsif ($feature eq 'bosh-integration') {
      $self->add_files('manifests/features/bosh-integration.yml');
      $self->validate_bosh_params();
      
    } elsif ($feature eq 'multi-region') {
      $self->add_files('manifests/features/multi-region.yml');
      $self->validate_multi_region_params();
      
    } elsif ($feature eq 'performance-optimization') {
      $self->add_files('manifests/features/performance-optimization.yml');
      $self->validate_performance_params();
      
    } elsif ($feature =~ /^(ocfp|partitioned-network|\+external-elasticsearch|\+s3-blobstore)$/) {
      # These features are handled by features.pm or process_ocfp_features
      
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

# validate_oauth_params - Validate OAuth authentication parameters {{{
sub validate_oauth_params {
  my ($self) = @_;
  
  my $provider = $self->env->lookup('params.oauth_provider', '');
  bail("Missing required parameter 'params.oauth_provider' for oauth-authentication feature") unless $provider;
  
  my @valid_providers = qw(github google azure okta custom);
  bail("Invalid oauth_provider: '%s' (valid options: %s)", $provider, join(', ', @valid_providers))
    unless grep { $_ eq $provider } @valid_providers;
  
  my $discovery_url = $self->env->lookup('params.oauth_discovery_url', '');
  bail("Missing required parameter 'params.oauth_discovery_url' for oauth-authentication feature") unless $discovery_url;
  
  bail("Invalid oauth_discovery_url format: '%s'", $discovery_url)
    unless $discovery_url =~ /^https?:\/\/.+/;
    
  info("OAuth authentication configured with provider: %s", $provider);
}
# }}}

# validate_shield_params - Validate Shield integration parameters {{{
sub validate_shield_params {
  my ($self) = @_;
  
  my $endpoint = $self->env->lookup('params.shield_endpoint', '');
  bail("Missing required parameter 'params.shield_endpoint' for shield-integration feature") unless $endpoint;
  
  bail("Invalid shield_endpoint format: '%s'", $endpoint)
    unless $endpoint =~ /^https?:\/\/.+/;
    
  my $schedule = $self->env->lookup('params.shield_backup_schedule', 'daily 4am');
  bail("Invalid shield_backup_schedule format: '%s'", $schedule)
    unless $schedule =~ /^(hourly|daily|weekly)(\s+\d+[ap]m)?$/;
    
  info("Shield backup integration configured with endpoint: %s", $endpoint);
}
# }}}

# validate_bosh_params - Validate BOSH integration parameters {{{
sub validate_bosh_params {
  my ($self) = @_;
  
  my $director_url = $self->env->lookup('params.bosh_director_url', '');
  bail("Missing required parameter 'params.bosh_director_url' for bosh-integration feature") unless $director_url;
  
  bail("Invalid bosh_director_url format: '%s'", $director_url)
    unless $director_url =~ /^https?:\/\/.+/;
    
  my $retention = $self->env->lookup('params.bosh_log_retention_days', 30);
  bail("bosh_log_retention_days must be a positive integer, got: %s", $retention)
    unless $retention =~ /^\d+$/ && $retention > 0;
    
  info("BOSH log integration configured with director: %s", $director_url);
}
# }}}

# validate_multi_region_params - Validate multi-region parameters {{{
sub validate_multi_region_params {
  my ($self) = @_;
  
  my $primary_region = $self->env->lookup('params.primary_region', '');
  bail("Missing required parameter 'params.primary_region' for multi-region feature") unless $primary_region;
  
  my $regions = $self->env->lookup('params.regions', []);
  bail("Missing required parameter 'params.regions' for multi-region feature") 
    unless ref($regions) eq 'ARRAY' && @$regions > 0;
    
  bail("Primary region '%s' must be included in regions list", $primary_region)
    unless grep { $_ eq $primary_region } @$regions;
    
  my $azs = $self->env->lookup('params.availability_zones', []);
  bail("Missing required parameter 'params.availability_zones' for multi-region feature") 
    unless ref($azs) eq 'ARRAY' && @$azs > 0;
    
  info("Multi-region cluster configured with primary region: %s", $primary_region);
}
# }}}

# validate_performance_params - Validate performance optimization parameters {{{
sub validate_performance_params {
  my ($self) = @_;
  
  # Validate heap sizes if provided
  my $es_heap = $self->env->lookup('params.elasticsearch_heap_size', '');
  if ($es_heap) {
    bail("Invalid elasticsearch_heap_size format: '%s' (expected format: 2g, 512m)", $es_heap)
      unless $es_heap =~ /^\d+[gGmM]$/;
  }
  
  my $logstash_heap = $self->env->lookup('params.logstash_heap_size', '');
  if ($logstash_heap) {
    bail("Invalid logstash_heap_size format: '%s' (expected format: 2g, 512m)", $logstash_heap)
      unless $logstash_heap =~ /^\d+[gGmM]$/;
  }
  
  my $kibana_memory = $self->env->lookup('params.kibana_memory_limit', '');
  if ($kibana_memory) {
    bail("Invalid kibana_memory_limit format: '%s' (expected format: 2g, 512m)", $kibana_memory)
      unless $kibana_memory =~ /^\d+[gGmM]$/;
  }
  
  # Validate thread pool settings
  my $thread_pool = $self->env->lookup('params.elasticsearch_thread_pool_size', 'auto');
  unless ($thread_pool eq 'auto') {
    bail("elasticsearch_thread_pool_size must be 'auto' or a positive integer, got: %s", $thread_pool)
      unless $thread_pool =~ /^\d+$/ && $thread_pool > 0;
  }
  
  info("Performance optimization feature enabled");
}
# }}}

# process_ocfp_features - Process OCFP-specific features and configuration {{{
sub process_ocfp_features {
  my ($self) = @_;
  
  # Get IaaS type
  my $iaas = $self->env->cpi || 'aws';
  $iaas = 'openstack' if $iaas eq 'stackit';
  
  # Base OCFP files
  $self->add_files(
    'ocfp/meta.yml',
    'ocfp/ocfp.yml'
  );
  
  # IaaS-specific files
  $self->add_files_if_exists(
    "ocfp/${iaas}/ocf.yml",
    "ocfp/${iaas}/azs.yml"
  );
  
  # Storage backend
  if ($self->want_feature('s3-blobstore') || $self->want_feature('+s3-blobstore')) {
    $self->add_files('ocfp/s3-blobstore.yml');
    $self->add_files_if_exists("ocfp/${iaas}/s3-blobstore.yml");
  } elsif ($self->want_feature('azure-blobstore')) {
    $self->add_files('ocfp/azure-blobstore.yml');
  } elsif ($self->want_feature('gcs-blobstore')) {
    $self->add_files('ocfp/gcs-blobstore.yml');
  } else {
    # Default to internal storage
    $self->add_files('ocfp/internal-storage.yml');
  }
  
  # External Elasticsearch if requested
  if ($self->want_feature('external-elasticsearch') || $self->want_feature('+external-elasticsearch')) {
    $self->add_files(
      'ocfp/external-elasticsearch.yml',
      "ocfp/${iaas}/external-elasticsearch.yml"
    );
  } else {
    # Internal Elasticsearch cluster
    $self->add_files('ocfp/internal-elasticsearch.yml');
  }
  
  # Process common OCFP features
  my %feature_map = (
    'prometheus-monitoring' => 'ocfp/prometheus-integration.yml',
    'cf-integration'        => 'ocfp/cf-integration.yml',
    'shield-integration'    => 'ocfp/shield-integration.yml',
    'bosh-integration'      => 'ocfp/bosh-integration.yml',
    'oauth-authentication'  => 'ocfp/oauth.yml',
    'alerting'             => 'ocfp/alerting.yml',
    'enhanced-curator'      => 'ocfp/curator.yml',
    'partitioned-network'   => 'ocfp/partitioned-network.yml'
  );
  
  foreach my $feature ($self->features) {
    if (exists $feature_map{$feature}) {
      $self->add_files($feature_map{$feature});
    }
  }
  
  # Trust certificates
  $self->add_files("ocfp/trust-org-ca.yml");
  $self->add_files("ocfp/trust-blacksmith-ca.yml") if $self->want_feature('blacksmith-integration');
  $self->add_files("ocfp/trusted-certs.yml");
  
  # Validate OCFP parameters
  $self->validate_ocfp_params();
  
  return $self->done(1);
}
# }}}

# validate_ocfp_features - Validate OCFP feature combinations {{{
sub validate_ocfp_features {
  my ($self) = @_;
  
  my @allowed_features = (
    'ocfp', # OCFP is the only feature that is always enabled in OCFP environments
    'external-elasticsearch',
    's3-blobstore',
    'azure-blobstore', 
    'gcs-blobstore',
    'partitioned-network',
    'small-footprint'
  );
  
  my @implicit_features = (
    'prometheus-monitoring',
    'cf-integration',
    'shield-integration',
    'bosh-integration',
    'oauth-authentication',
    'alerting',
    'enhanced-curator'
  );
  
  # Check for conflicting features
  my @explicit_features = $self->features;
  my @invalid = ();
  
  for my $feature (@explicit_features) {
    next if grep { $_ eq $feature } @allowed_features;
    if (grep { $_ eq $feature } @implicit_features) {
      warning("Feature '%s' is implicitly enabled by 'ocfp' and doesn't need to be specified", $feature);
    } else {
      push @invalid, $feature;
    }
  }
  
  if (@invalid) {
    bail("Invalid features for OCFP deployment: %s", join(', ', @invalid));
  }
  
  # Check for conflicting storage features
  my @storage_features = grep { 
    $_ =~ /^(s3-blobstore|azure-blobstore|gcs-blobstore)$/ 
  } @explicit_features;
  
  if (scalar(@storage_features) > 1) {
    bail("Only one storage backend feature can be enabled in OCFP. Found: %s", 
      join(', ', @storage_features));
  }
}
# }}}

# validate_ocfp_params - Validate OCFP-specific parameters {{{
sub validate_ocfp_params {
  my ($self) = @_;
  
  # Check required OCFP parameters
  my $ocfp_env_scale = $self->env->lookup('params.ocfp_env_scale', 'dev');
  unless ($ocfp_env_scale =~ /^(dev|prod)$/) {
    bail("Invalid ocfp_env_scale: '%s' (must be 'dev' or 'prod')", $ocfp_env_scale);
  }
  
  # Vault configuration slug
  my $vault_slug = $self->env->lookup('params.ocfp_vault_config_slug', '');
  if ($vault_slug && $vault_slug !~ /^[a-zA-Z0-9\-_]+$/) {
    bail("Invalid ocfp_vault_config_slug format: '%s'", $vault_slug);
  }
  
  info("OCFP deployment configured with scale: %s", $ocfp_env_scale);
}
# }}}

# add_files_if_exists - Add files only if they exist {{{
sub add_files_if_exists {
  my ($self, @files) = @_;
  
  foreach my $file (@files) {
    my $full_path = $self->kit_path($file);
    if (-f $full_path) {
      $self->add_files($file);
    }
  }
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1: