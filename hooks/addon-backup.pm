package Genesis::Hook::Addon::Logsearch::Backup;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'./.genesis/lib'}

use parent qw(Genesis::Hook::Addon);
use Genesis qw/bail info warning error run/;
use JSON::PP;
use POSIX qw/strftime/;

# addon-backup - Create Elasticsearch snapshot {{{
sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub cmd_details {
  return "Create a snapshot backup of Elasticsearch indices.\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Check if any storage backend is configured
  my $has_storage = 0;
  my $repository = 'backup';

  if ($self->want_feature('s3-blobstore')) {
    $repository = 's3_repository';
    $has_storage = 1;
  } elsif ($self->want_feature('azure-blobstore')) {
    $repository = 'azure_repository';
    $has_storage = 1;
  } elsif ($self->want_feature('gcs-blobstore')) {
    $repository = 'gcs_repository';
    $has_storage = 1;
  }

  if (!$has_storage) {
    warning("No cloud storage backend configured");
    warning("Snapshots will only be available locally on Elasticsearch nodes");
    info("");
    info("To configure cloud storage, add one of these features to your environment:");
    info("  - s3-blobstore");
    info("  - azure-blobstore");
    info("  - gcs-blobstore");
    info("");
    bail("Please configure a storage backend before creating snapshots");
  }

  # Get base domain for constructing URL
  my $base_domain = $env->lookup('params.base_domain', '');
  bail("Missing base_domain parameter") unless $base_domain;

  my $es_url = "https://elasticsearch.$base_domain:9200";
  my $vault_path = $env->lookup('params.vault', 'secret/logsearch');

  # Generate snapshot name with timestamp
  my $timestamp = strftime("%Y%m%d-%H%M%S", localtime());
  my $snapshot_name = "manual-snapshot-$timestamp";

  info("");
  info("Creating Elasticsearch snapshot...");
  info("Repository: %s", $repository);
  info("Snapshot: %s", $snapshot_name);
  info("");

  # Create the snapshot
  my $snapshot_payload = encode_json({
    indices => '*',
    ignore_unavailable => JSON::PP::true,
    include_global_state => JSON::PP::true,
    metadata => {
      taken_by => 'genesis-addon',
      taken_because => 'manual-backup',
      environment => $env->name
    }
  });

  my $snapshot_cmd = sprintf(
    'curl -sk -X PUT "%s/_snapshot/%s/%s" -H "Content-Type: application/json" -u "elastic:\$(safe read %s/elasticsearch:admin_password)" -d \'%s\'',
    $es_url,
    $repository,
    $snapshot_name,
    $vault_path,
    $snapshot_payload
  );

  my ($output, $rc) = run({interactive => 0}, $snapshot_cmd);

  if ($rc == 0) {
    eval {
      my $response = decode_json($output);
      if ($response->{accepted}) {
        info("Snapshot creation started successfully");
        info("Snapshot name: %s", $snapshot_name);
      } else {
        error("Snapshot creation was not accepted");
        error("Response: %s", $output);
        return $self->done(1);
      }
    };
    if ($@) {
      warning("Unexpected response format: %s", $output);
    }
  } else {
    error("Failed to create snapshot");
    error("Command failed with exit code: %d", $rc);
    error("Output: %s", $output);
    return $self->done(1);
  }

  info("");
  info("Monitoring snapshot progress...");

  # Monitor snapshot progress
  my $max_wait = 300; # 5 minutes
  my $wait_interval = 10; # 10 seconds
  my $waited = 0;

  while ($waited < $max_wait) {
    sleep($wait_interval);
    $waited += $wait_interval;

    my $status_cmd = sprintf(
      'curl -sk "%s/_snapshot/%s/%s" -u "elastic:\$(safe read %s/elasticsearch:admin_password)"',
      $es_url,
      $repository,
      $snapshot_name,
      $vault_path
    );

    my ($status_output, $status_rc) = run({interactive => 0}, $status_cmd);

    if ($status_rc == 0) {
      eval {
        my $status_response = decode_json($status_output);
        my $snapshots = $status_response->{snapshots};

        if (@$snapshots > 0) {
          my $snapshot = $snapshots->[0];
          my $state = $snapshot->{state};

          if ($state eq 'SUCCESS') {
            info("Snapshot completed successfully!");
            info("Duration: %d seconds", $snapshot->{duration_in_millis} / 1000);
            info("Shards: %d total, %d successful, %d failed",
              $snapshot->{shards}{total},
              $snapshot->{shards}{successful},
              $snapshot->{shards}{failed}
            );

            if ($snapshot->{shards}{failed} > 0) {
              warning("Some shards failed to backup");
            }

            last;
          } elsif ($state eq 'FAILED') {
            error("Snapshot failed!");
            error("Failures: %s", encode_json($snapshot->{failures} || []));
            return $self->done(1);
          } elsif ($state eq 'IN_PROGRESS') {
            info("Progress: %d%%", int(($snapshot->{shards}{successful} / $snapshot->{shards}{total}) * 100));
          }
        }
      };
    }
  }

  if ($waited >= $max_wait) {
    warning("Snapshot still in progress after %d seconds", $max_wait);
    info("Check status manually with:");
    info("  curl -sk '%s/_snapshot/%s/%s' -u 'elastic:\$(safe read %s/elasticsearch:admin_password)'",
      $es_url, $repository, $snapshot_name, $vault_path);
  }

  info("");
  info("Snapshot management:");
  info("  List snapshots: curl -sk '%s/_snapshot/%s/_all' -u 'elastic:\$(safe read %s/elasticsearch:admin_password)'",
    $es_url, $repository, $vault_path);
  info("  Restore: genesis do %s -- restore %s", $env->name, $snapshot_name);
  info("");

  return $self->done();
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
