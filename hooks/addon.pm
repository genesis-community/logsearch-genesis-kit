package Genesis::Hook::Addon::Logsearch;

use v5.20;
use warnings;

# Only needed for development
BEGIN {
  push @INC,
    $ENV{GENESIS_LIB}
      ? $ENV{GENESIS_LIB}
      : $ENV{HOME}.'/.genesis/lib'
}

use parent qw(Genesis::Hook::Addon);
use Genesis qw/bail/;

# init - enforce minimum Genesis version {{{
sub init {
  my ($class, %ops) = @_;
  my $self = $class->SUPER::init(%ops);
  
  # Match the version required by the kit
  $self->check_minimum_genesis_version('2.8.12');
  return $self;
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1: