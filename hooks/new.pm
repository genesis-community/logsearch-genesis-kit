package Genesis::Hook::New::Logsearch;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::New);

use Genesis qw/bail info warning/;
use Genesis::UI qw/prompt_for prompt_for_boolean/;

# new.pm - Interactive wizard for environment creation {{{
sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->check_minimum_genesis_version('3.1.0');

  # Initialize wizard state
  $obj->{features} = [];
  $obj->{base_domain} = '';
  $obj->{cluster_size} = 'medium';
  $obj->{storage_backend} = 'none';

  return $obj;
}

sub perform {
  my ($self) = @_;

  # Welcome message
  info("");
  info("Welcome to the Logsearch Genesis Kit Environment Creation Wizard");
  info("=========================================================");
  info("");
  info("This wizard will help you configure a new Logsearch environment");
  info("for centralized log aggregation and analytics with the ELK stack.");
  info("");

  # Ask for base domain
  $self->ask_base_domain();

  # Ask for deployment size
  $self->ask_deployment_size();

  # Ask for storage backend
  $self->ask_storage_backend();

  # Ask for monitoring
  $self->ask_monitoring();

  # Ask for log source integration
  $self->ask_log_integration();

  # Ask for additional features
  $self->ask_additional_features();

  # Generate the environment file
  my $file_content = $self->generate_environment_file();

  # Write the environment file
  $self->env->write_manifest($file_content);

  # Provide next steps
  $self->show_next_steps();

  return $self->done();
}

# ask_base_domain - Prompt for base domain {{{
sub ask_base_domain {
  my ($self) = @_;

  info("First, let's configure the base domain for your Logsearch deployment.");
  info("This will be used for Kibana, Elasticsearch, and Logstash endpoints.");
  info("");

  $self->{base_domain} = prompt_for(
    'text',
    'What is your base domain?',
    --valid => sub {
      my $domain = shift;
      return $domain =~ /^[a-zA-Z0-9]([a-zA-Z0-9\-\.]*[a-zA-Z0-9])?$/
        ? undef
        : "Invalid domain format";
    }
  );

  info("");
  info("Your Logsearch endpoints will be:");
  info("  Kibana:        https://kibana.%s", $self->{base_domain});
  info("  Elasticsearch: https://elasticsearch.%s:9200", $self->{base_domain});
  info("  Logstash:      syslog://logstash.%s:5514", $self->{base_domain});
  info("");
}
# }}}

# ask_deployment_size - Prompt for cluster sizing {{{
sub ask_deployment_size {
  my ($self) = @_;

  info("Next, let's determine the size of your Logsearch deployment.");
  info("");

  $self->{cluster_size} = prompt_for(
    'select',
    'What size deployment would you like?',
    -o => '[small]  Development/Testing (1 ES node, minimal resources)',
    -o => '[medium] Standard Production (3 ES nodes, moderate resources)',
    -o => '[large]  High-Volume Production (6+ ES nodes, high resources)',
    --default => 'medium'
  );

  if ($self->{cluster_size} eq 'small') {
    push @{$self->{features}}, 'small-footprint';
    info("");
    info("Selected small deployment:");
    info("  - 1 Elasticsearch node");
    info("  - 1 Logstash instance");
    info("  - 1 Kibana instance");
    info("  - Reduced resource allocation");
  } elsif ($self->{cluster_size} eq 'large') {
    info("");
    info("Selected large deployment:");
    info("  - 6 Elasticsearch nodes (3 master + 3 data)");
    info("  - 4 Logstash instances");
    info("  - 2 Kibana instances");
    info("  - High resource allocation");
  } else {
    info("");
    info("Selected medium deployment:");
    info("  - 3 Elasticsearch nodes");
    info("  - 2 Logstash instances");
    info("  - 1 Kibana instance");
    info("  - Standard resource allocation");
  }
  info("");
}
# }}}

# ask_storage_backend - Prompt for storage backend {{{
sub ask_storage_backend {
  my ($self) = @_;

  info("For Elasticsearch snapshots and backups, you can configure cloud storage.");
  info("");

  my $wants_storage = prompt_for_boolean(
    'Would you like to configure cloud storage for backups?'
  );

  if ($wants_storage) {
    $self->{storage_backend} = prompt_for(
      'select',
      'Which cloud storage provider would you like to use?',
      -o => '[s3]    Amazon S3',
      -o => '[azure] Azure Blob Storage',
      -o => '[gcs]   Google Cloud Storage',
      -o => '[none]  Skip storage configuration',
      --default => 's3'
    );

    if ($self->{storage_backend} ne 'none') {
      push @{$self->{features}}, $self->{storage_backend} . '-blobstore';
      info("");
      info("Selected %s storage backend.", uc($self->{storage_backend}));
      info("Remember to configure the required parameters in your environment file:");

      if ($self->{storage_backend} eq 's3') {
        info("  - params.s3_bucket");
        info("  - params.s3_region");
      } elsif ($self->{storage_backend} eq 'azure') {
        info("  - params.azure_storage_account");
        info("  - params.azure_container");
      } elsif ($self->{storage_backend} eq 'gcs') {
        info("  - params.gcs_bucket");
        info("  - params.gcp_project_id");
      }
      info("");
    }
  }
}
# }}}

# ask_monitoring - Prompt for monitoring features {{{
sub ask_monitoring {
  my ($self) = @_;

  info("Logsearch can be integrated with monitoring systems.");
  info("");

  my $wants_monitoring = prompt_for_boolean(
    'Would you like to enable Prometheus monitoring exporters?'
  );

  if ($wants_monitoring) {
    push @{$self->{features}}, 'prometheus-monitoring';
    info("");
    info("Prometheus monitoring enabled. Metrics will be available at:");
    info("  - Elasticsearch: :9114/metrics");
    info("  - Logstash: :9198/metrics");
    info("  - Node metrics: :9100/metrics");
    info("");
  }

  my $wants_alerting = prompt_for_boolean(
    'Would you like to enable built-in alerting rules?'
  );

  if ($wants_alerting) {
    push @{$self->{features}}, 'alerting';
    info("");
    info("Alerting enabled. Configure alert_email parameter for notifications.");
    info("");
  }
}
# }}}

# ask_log_integration - Prompt for log source integration {{{
sub ask_log_integration {
  my ($self) = @_;

  info("Logsearch can be pre-configured for specific log sources.");
  info("");

  my $wants_cf = prompt_for_boolean(
    'Will you be ingesting CloudFoundry logs?'
  );

  if ($wants_cf) {
    push @{$self->{features}}, 'cf-integration';
    info("");
    info("CloudFoundry integration enabled:");
    info("  - CF log parsing rules");
    info("  - Pre-built CF dashboards");
    info("  - CF-specific retention policies");
    info("");
  }
}
# }}}

# ask_additional_features - Prompt for additional features {{{
sub ask_additional_features {
  my ($self) = @_;

  info("Finally, let's configure some additional features.");
  info("");

  my $wants_custom_parsers = prompt_for_boolean(
    'Would you like to include custom log parsing rules for common formats (nginx, apache, etc.)?'
  );

  if ($wants_custom_parsers) {
    push @{$self->{features}}, 'custom-parsers';
  }

  my $wants_enhanced_curator = prompt_for_boolean(
    'Would you like enhanced index lifecycle management with Curator?'
  );

  if ($wants_enhanced_curator) {
    push @{$self->{features}}, 'enhanced-curator';
  }
}
# }}}

# generate_environment_file - Generate the environment YAML content {{{
sub generate_environment_file {
  my ($self) = @_;

  my $content = "---\n";
  $content .= "kit:\n";
  $content .= "  name:    $ENV{GENESIS_KIT_NAME}\n";
  $content .= "  version: $ENV{GENESIS_KIT_VERSION}\n";

  if (@{$self->{features}}) {
    $content .= "  features:\n";
    for my $feature (@{$self->{features}}) {
      $content .= "  - $feature\n";
    }
  }

  $content .= "\n";
  $content .= $self->env->genesis_config_block;

  $content .= "params:\n";
  $content .= "  base_domain: $self->{base_domain}\n";

  # Add sizing parameters based on cluster size
  if ($self->{cluster_size} eq 'large') {
    $content .= "  elasticsearch_instances: 6\n";
    $content .= "  logstash_instances: 4\n";
    $content .= "  kibana_instances: 2\n";
    $content .= "  elasticsearch_heap_size: \"16g\"\n";
    $content .= "  logstash_heap_size: \"4g\"\n";
  } elsif ($self->{cluster_size} eq 'small') {
    $content .= "  elasticsearch_instances: 1\n";
    $content .= "  logstash_instances: 1\n";
    $content .= "  kibana_instances: 1\n";
    $content .= "  elasticsearch_heap_size: \"1g\"\n";
    $content .= "  logstash_heap_size: \"512m\"\n";
  }
  # Medium size uses defaults from kit.yml

  # Add placeholder storage parameters
  if ($self->{storage_backend} eq 's3') {
    $content .= "\n";
    $content .= "  # S3 Storage Configuration\n";
    $content .= "  # s3_bucket: my-logsearch-snapshots\n";
    $content .= "  # s3_region: us-east-1\n";
  } elsif ($self->{storage_backend} eq 'azure') {
    $content .= "\n";
    $content .= "  # Azure Storage Configuration\n";
    $content .= "  # azure_storage_account: mylogstorageacct\n";
    $content .= "  # azure_container: elasticsearch-snapshots\n";
  } elsif ($self->{storage_backend} eq 'gcs') {
    $content .= "\n";
    $content .= "  # GCS Storage Configuration\n";
    $content .= "  # gcs_bucket: my-logsearch-snapshots\n";
    $content .= "  # gcp_project_id: my-project-id\n";
  }

  return $content;
}
# }}}

# show_next_steps - Display post-creation instructions {{{
sub show_next_steps {
  my ($self) = @_;

  info("");
  info("Environment file created successfully!");
  info("");
  info("Next steps:");
  info("  1. Review and edit your environment file: %s.yml", $self->env->name);
  info("  2. Configure any commented parameters for storage backends");
  info("  3. Deploy your environment: genesis deploy %s", $self->env->name);
  info("  4. After deployment, check cluster health: genesis do %s -- es-health", $self->env->name);
  info("  5. Open Kibana in your browser: genesis do %s -- visit-kibana", $self->env->name);
  info("");
  info("For more information, see: https://github.com/genesis-community/logsearch-genesis-kit");
  info("");
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
