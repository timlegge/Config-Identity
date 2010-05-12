package Config::Identity;
# ABSTRACT: Load (and optionally decrypt via GnuPG) user/pass identity information 

=head1 SYNOPSIS

PAUSE:

    use Config::Identity::PAUSE;

    # 1. Find either $HOME/.pause-identity or $HOME/.pause
    # 2. Decrypt the found file (if necessary), read, and parse it
    # 3. Throw an exception unless  %identity has 'user' and 'password' defined

    my %identity = Config::Identity::PAUSE->load;
    print "user: $identity{user} password: $identity{password}\n";
     
GitHub API:

    use Config::Identity::GitHub;

    # 1. Find either $HOME/.github-identity or $HOME/.github
    # 2. Decrypt the found file (if necessary) read, and parse it
    # 3. Throw an exception unless %identity has 'login' and 'token' defined

    my %identity = Config::Identity::PAUSE->load;
    print "login: $identity{login} token: $identity{token}\n";

=head1 DESCRIPTION

Config::Identity is a tool for loadiing (and optionally decrypting via GnuPG) user/pass identity information

For GitHub API access, an identity is a C<login>/C<token> pair

For PAUSE access, an identity is a C<user>/C<password> pair

See the SYNOPSIS for usage

=head1 Encrypting your identity information with GnuPG

If you've never used GnuPG before, first initialize it:

    # Follow the prompts to create a new key for yourself
    gpg --gen-key 

To encrypt your GitHub identity with GnuPG using the above key:
    
    # Follow the prompts, using the above key as the "recipient"
    # Use ^D once you've finished typing out your authentication information
    gpg -ea > $HOME/.github

=head1 Caching your GnuPG secret key via gpg-agent

Put the following in your .*rc

    if which gpg-agent 1>/dev/null
    then
        if test -f $HOME/.gpg-agent-info && \
            kill -0 `cut -d: -f 2 $HOME/.gpg-agent-info` 2>/dev/null
        then
            . "${HOME}/.gpg-agent-info"
            export GPG_AGENT_INFO
        else
            eval `gpg-agent --daemon --write-env-file "${HOME}/.gpg-agent-info"`
        fi
    else
    fi

=head1 PAUSE identity format

    user <user>
    password <password>

=head1 GitHub identity format

    login <login>
    token <token>

=head1 USAGE

See the SYNOPSIS

=cut

use strict;
use warnings;

use Carp;
use IPC::Open3 qw/ open3 /;
use Symbol qw/ gensym /;
use File::HomeDir();
use File::Spec;

our $home = File::HomeDir->home;
{
    my $gpg;
    sub GPG() { $ENV{CI_GPG} || ( $gpg ||= do {
        require File::Which;
        $gpg = File::Which::which( $_ ) and last for qw/ gpg gpg2 /;
        $gpg;
    } ) }
}
sub GPG_ARGUMENTS() { $ENV{CI_GPG_ARGUMENTS} || '' }

# TODO Do not even need to do this, since the file is on disk already...
sub decrypt {
    my $self = shift;
    my $input = shift;

    my ( $in, $out, $error ) = ( gensym, gensym, gensym );
    my $gpg = GPG or croak "Missing gpg";
    my $gpg_arguments = GPG_ARGUMENTS;
    my $run;
    $run = "$gpg $gpg_arguments -qd --no-tty --command-fd 0 --status-fd 1";
    $run = "$gpg $gpg_arguments -qd --no-tty --command-fd 0";
    my $process = open3( $in, $out, $error, $run );
    print $in $input;
    close $in;
    my $output = join '', <$out>;
    my $_error = join '', <$error>;
    return ( $output, $_error );
}

sub best {
    my $self = shift;
    my $stub = shift;
    my $base = shift;
    $base = $home unless defined $base;

    croak "Missing stub" unless defined $stub && length $stub;

    for my $i0 ( ".$stub-identity", ".$stub" ) {
        for my $i1 ( "." ) {
            my $path = File::Spec->catfile( $base, $i1, $i0 );
            return $path if -f $path;
        }
    }

    return '';
}

sub read {
    my $self = shift;
    my $file = shift;

    croak "Missing file" unless -f $file;
    croak "Cannot read file ($file)" unless -r $file;

    my $binary = -B $file;

    open my $handle, $file or croak $!;
    binmode $handle if $binary;
    local $/ = undef;
    my $content = <$handle>;
    close $handle or warn $!;

    if ( $binary || $content =~ m/----BEGIN PGP MESSAGE----/ ) {
        my ( $_content, $error ) = $self->decrypt( $content );
        if ( $error ) {
            carp "Error during decryption of content" . $binary ? '' : "\n$content";
            croak "Error during decryption of $file:\n$error";
        }
        $content = $_content;
    }
    
    return $content;
}

sub parse {
    my $self = shift;
    my $content = shift;

    return unless $content;
    my %content;
    for ( split m/\n/, $content ) {
        next if /^\s*#/;
        next unless m/\S/;
        next unless my ($key, $value) = /^\s*(\w+)\s+(.+)$/;
        $content{$key} = $value;
    }
    return %content;
}

sub load_best {
    my $self = shift;
    my $stub = shift;

    return unless my $path = $self->best( $stub );
    return $self->load( $path );
}

sub load {
    my $self = shift;
    my $file = shift;

    return $self->parse( $self->read( $file ) );
}

1;
