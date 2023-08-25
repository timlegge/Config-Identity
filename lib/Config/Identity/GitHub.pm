use strict;
use warnings;

package Config::Identity::GitHub;

our $VERSION = '0.0020';

use Config::Identity;
use Carp;

our $STUB = 'github';
sub STUB { defined $_ and return $_ for $ENV{CI_GITHUB_STUB}, $STUB }

sub load {
    my $self = shift;
    my $stub = shift || $self->STUB;
    return Config::Identity->try_best( $stub );
}

sub check {
    my $self = shift;
    my %identity = @_;
    my @missing;
    defined $identity{$_} && length $identity{$_}
        or push @missing, $_ for qw/ login token /;
    croak "Missing ", join ' and ', @missing if @missing;
}

sub load_check {
    my $self = shift;
    my $stub = shift;
    my %identity = $self->load($stub);
    $self->check( %identity );
    return %identity;
}

=pod

=head1 SYNOPSIS

GitHub API:

    use Config::Identity::GitHub;

    # 1. Find either $HOME/.github-identity or $HOME/.github
    # 2. Decrypt the found file (if necessary) read, and parse it
    # 3. Throw an exception unless %identity has 'login' and 'token' defined

    my %identity = Config::Identity::GitHub->load_check;
    print "login: $identity{login} token: $identity{token}\n";

    or

    # you can also pass a "stub" to the load_check to look for
    # the identity information in ~/.project-identity or ~/.project
    my %identity = Config::Identity::GitHub->load_check("project");
    print "login: $identity{login} token: $identity{token}\n";


=head2 METHODS

=over

=item load_check

Accepts an optional "STUB" to allow you to find a separate identity file.
The filename becomes:

    ~/.STUB-identity or ~/.STUB

If the option setting is not provided it defaults to github

    ~/.github-identity or ~/.github

=back

=cut

1;

