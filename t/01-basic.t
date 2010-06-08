#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;
plan 'no_plan';

use Config::Identity;
use Config::Identity::GitHub;
use Config::Identity::PAUSE;

my $h0 = File::Spec->catdir(qw/ t assets h0 /);
my $h1 = File::Spec->catdir(qw/ t assets h1 /);

is( Config::Identity->best( 'test' => $h0 ), File::Spec->catfile( $h0, '.test-identity' ) );
is( Config::Identity->best( 'test' => $h1 ), File::Spec->catfile( $h1, '.test' ) );

my ( %cfg );

%cfg = Config::Identity->parse( <<'_END_' );
    # Xyzzy
apple a1
banana b2

    

_END_

cmp_deeply( \%cfg, {qw/ apple a1 banana b2 /} );

SKIP: {
    skip 'GnuPG not available' unless Config::Identity->GPG;

    $ENV{CI_GPG_ARGUMENTS} =
        '--no-secmem-warning ' .
        '--no-permission-warning ' .
        '--homedir ' . File::Spec->catfile(qw/ t assets gpg /)
    ;

    is( Config::Identity->read( File::Spec->catfile(qw/ t assets test.asc /) ), <<_END_ );
1234567890xyzzy

# 123
_END_

    is( Config::Identity->read( File::Spec->catfile(qw/ t assets test.gpg /) ), <<_END_ );
ABCDEFGHIJKLMNOPQRSTUVWXYZ

1 2 3 4 5 6 7 8 9 0

.
_END_

    use Config::Identity::GitHub;
    {
        local $Config::Identity::home = File::Spec->catfile(qw/ t assets github /);
        my %identity = Config::Identity::GitHub->load_check;
        cmp_deeply( \%identity, {qw/ login alice token hunter2 /} );
    }

    use Config::Identity::PAUSE;
    {
        local $Config::Identity::home = File::Spec->catfile(qw/ t assets pause /);
        my %identity = Config::Identity::PAUSE->load_check;
        cmp_deeply( \%identity, {qw/ username alice user alice password hunter2 /} );
    }
    {
        local $Config::Identity::home = File::Spec->catfile(qw/ t assets pause-username /);
        my %identity = Config::Identity::PAUSE->load_check;
        cmp_deeply( \%identity, {qw/ username alice user alice password hunter3 /} );
    }
}

1;
