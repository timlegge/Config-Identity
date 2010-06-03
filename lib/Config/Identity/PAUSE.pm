package Config::Identity::PAUSE;

use strict;
use warnings;

use Config::Identity;
use Carp;

sub load {
    my $self = shift;
    return Config::Identity->try_best( 'pause' );
}

sub check {
    my $self = shift;
    my %identity = @_;
    my @missing;
    defined $identity{$_} && length $identity{$_}
        or push @missing, $_ for qw/ user password /;
    croak "Missing ", join ' and ', @missing if @missing;
}

sub load_check {
    my $self = shift;
    my %identity = $self->load;
    $self->check( %identity );
    return %identity;
}

1;
