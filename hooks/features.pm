package Genesis::Hook::Features::Logsearch;

use v5.20;
use warnings;

# Only needed for development
BEGIN { push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME} . '/.genesis/lib' }

use parent qw(Genesis::Hook::Features);

use Genesis qw(new_enough);

# init - Initialize the hook {{{
sub init {
	my ( $class, %ops ) = @_;
	my $obj = $class->SUPER::init(%ops);
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}

# }}}

# perform - Main hook execution {{{
sub perform {
	my ($self) = @_;

	# Build features list based on requested features
	my @features;

	# Process requested features with transformations
	my $is_ocfp = $self->want_feature('ocfp');
	foreach my $feature ($self->features) {
		if ($feature eq 'split-network') { # Short-lived ocfp feature that is better handled by existing feature name
			push @features, 'partitioned-network';
		} elsif ($feature eq 'external-elasticsearch' && $is_ocfp) {
			push @features, '+external-elasticsearch';
		} elsif ($feature eq 's3-blobstore' && $is_ocfp) {
			push @features, '+s3-blobstore';
		} else {
			push @features, $feature;
		}
	}

	if ($is_ocfp) { # OCFP default integrations
		push @features, 'prometheus-monitoring';
		push @features, 'cf-integration';
		push @features, 'shield-integration';
		push @features, 'bosh-integration';
		push @features, 'oauth-authentication';
		push @features, 'alerting';
		push @features, 'enhanced-curator';
	}

	return $self->done(\@features);
}

# }}}

1;

# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
