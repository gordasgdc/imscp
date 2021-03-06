=head1 NAME

 iMSCP::DistPackageManager::Debian - Debian distribution package manager

=cut

package iMSCP::DistPackageManager::Debian;

use strict;
use warnings;
use Array::Utils qw/ intersect /;
use File::Temp;
use iMSCP::Boolean;
use iMSCP::Debug qw/ debug /;
use iMSCP::Dialog;
use iMSCP::Execute qw/ execute /;
use iMSCP::File;
use iMSCP::Getopt;
use version;
use parent qw/ iMSCP::Common::Object iMSCP::DistPackageManager::Interface /;

=head1 DESCRIPTION

 Debian distribution package manager.

=head1 PUBLIC METHODS

=over 4

=item addRepositories( @repositories )

 See iMSCP::DistPackageManager::Interface::addRepositories()
 
 @repositories must contain a list of hashes, each describing an APT repository.
 The hashes *MUST* contain the following key/value pairs:
  repository         : APT repository in format 'uri suite [component1] [component2] [...]' 
  repository_key_srv : APT repository key server such as keyserver.ubuntu.com  (not needed if repository_key_uri is provided)
  repository_key_id  : APT repository key identifier such as 5072E1F5 (not needed if repository_key_uri is provided)
  repository_key_uri : APT repository key URI such as https://packages.sury.org/php/apt.gpg (not needed if repository_key_id is provided)

=cut

sub addRepositories
{
    my ( $self, @repositories ) = @_;

    my $file = iMSCP::File->new( filename => '/etc/apt/sources.list' );
    my $fileContent = $file->getAsRef();

    # Add APT repositories
    for my $repository ( @repositories ) {
        next if ${ $fileContent } =~ /^deb\s+$repository->{'repository'}/m;

        ${ $fileContent } .= <<"EOF";

deb $repository->{'repository'}
deb-src $repository->{'repository'}
EOF
        # Hide "apt-key output should not be parsed (stdout is not a terminal)" warning that
        # is raised in newest apt-key versions. Our usage of apt-key is not dangerous (not parsing)
        local $ENV{'APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE'} = TRUE;

        if ( $repository->{'repository_key_srv'} && $repository->{'repository_key_id'} ) {
            # Add the repository key from the given key server
            my $rs = execute(
                [ 'apt-key', 'adv', '--recv-keys', '--keyserver', $repository->{'repository_key_srv'}, $repository->{'repository_key_id'} ],
                \my $stdout,
                \my $stderr
            );
            debug( $stdout ) if length $stdout;
            !$rs or die( $stderr || 'Unknown error' );

            # Workaround https://bugs.launchpad.net/ubuntu/+source/gnupg2/+bug/1633754
            execute( [ 'pkill', '-TERM', 'dirmngr' ], \$stdout, \$stderr );
        } elsif ( $repository->{'repository_key_uri'} ) {
            # Add the repository key by fetching it first from the given URI
            my $keyFile = File::Temp->new();
            $keyFile->close();
            my $rs = execute(
                [ 'wget', '--prefer-family=IPv4', '--timeout=30', '-O', $keyFile, $repository->{'repository_key_uri'} ], \my $stdout, \my $stderr
            );
            debug( $stdout ) if length $stdout;
            !$rs or die( $stderr || 'Unknown error' );

            $rs = execute( [ 'apt-key', 'add', $keyFile ], \$stdout, \$stderr );
            debug( $stdout ) if length $stdout;
            !$rs or die( $stderr || 'Unknown error' );
        }
    }

    $file->save();
    $self->_updateAptIndex();
}

=item removeRepositories( @repositories )

 See iMSCP::DistPackageManager::Interface::removeRepositories()
 
 @repositories must contain a list of repository in following format: 'uri suite [component1] [component2] [...]' 

=cut

sub removeRepositories
{
    my ( $self, @repositories ) = shift;

    my $file = iMSCP::File->new( filename => '/etc/apt/sources.list' );
    my $fileContent = $file->getAsRef();

    for my $repository ( @repositories ) {
        ${ $fileContent } =~ s/^\n?(?:#\s*)?deb(?:-src)?\s+\Q$repository\E.*?\n//gm;
    }

    $file->save();
    $self->_updateAptIndex();
}

=item installPackages( @packages )

 See iMSCP::DistPackageManager::Interface::installPackages()

=cut

sub installPackages
{
    my ( $self, @packages ) = @_;

    # Ignores exit code due to https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1258958 bug
    execute( [ 'apt-mark', 'unhold', @packages ], \my $stdout, \my $stderr );

    iMSCP::Dialog->getInstance()->endGauge() if iMSCP::Getopt->context() eq 'installer';

    local $ENV{'UCF_FORCE_CONFFNEW'} = TRUE;
    local $ENV{'UCF_FORCE_CONFFMISS'} = TRUE;

    my @cmd = (
        ( !iMSCP::Getopt->noprompt ? ( 'debconf-apt-progress', '--logstderr', '--' ) : () ),
        'apt-get', '--assume-yes', '--option', 'DPkg::Options::=--force-confnew', '--option',
        'DPkg::Options::=--force-confmiss', '--option', 'Dpkg::Options::=--force-overwrite',
        '--auto-remove', '--purge', '--no-install-recommends',
        ( version->parse( `apt-get --version 2>/dev/null` =~ /^apt\s+(\d\.\d)/ ) < version->parse( '1.1' )
            ? '--force-yes' : '--allow-downgrades' ),
        'install'
    );

    execute( [ @cmd, @packages ], ( iMSCP::Getopt->noprompt && !iMSCP::Getopt->verbose ? \$stdout : undef ), \$stderr ) == 0 or die(
        sprintf( "Couldn't install packages: %s", $stderr || 'Unknown error' )
    );

    $self;
}

=item uninstallPackages( @packages )

 See iMSCP::DistPackageManager::Interface::uninstallPackages()

=cut

sub uninstallPackages
{
    my ( $self, @packages ) = @_;

    # Filter packages that are no longer available
    # Ignore exit code as 1 is returned when a queried package is not found
    execute( [ 'dpkg-query', '-W', '-f=${Package}\n', @packages ], \my $stdout, \my $stderr );
    my @availablePackages = $stdout ? split /\n/, $stdout : ();
    @packages = intersect( @packages, @availablePackages );
    undef @availablePackages;

    if ( @packages ) {
        iMSCP::Dialog->getInstance()->endGauge() if iMSCP::Getopt->context() eq 'installer';

        # Ignores exit code due to https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1258958 bug
        execute( [ 'apt-mark', 'unhold', @packages ], \$stdout, \$stderr );
        execute(
            [
                ( !iMSCP::Getopt->noprompt ? ( 'debconf-apt-progress', '--logstderr', '--' ) : () ),
                'apt-get', '--assume-yes', '--auto-remove', 'purge', @packages
            ],
            ( iMSCP::Getopt->noprompt && !iMSCP::Getopt->verbose ? \$stdout : undef ),
            \$stderr
        ) == 0 or die( sprintf( "Couldn't uninstall packages: %s", $stderr || 'Unknown error' ));

        # Purge packages that were indirectly removed
        execute(
            "apt-get -y purge \$(dpkg -l | grep ^rc | awk '{print \$2}')",
            ( iMSCP::Getopt->noprompt && iMSCP::Getopt->verbose ? undef : \$stdout ),
            \$stderr
        ) == 0 or die( sprintf( "Couldn't purge packages that are in RC state: %s", $stderr || 'Unknown error' ));
    }

    $self;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _updateAptIndex( )

 Update APT index

 Return iMSCP::DistPackageManager::Interface, die on failure

=cut

sub _updateAptIndex
{
    my ( $self ) = @_;

    iMSCP::Dialog->getInstance()->endGauge() if iMSCP::Getopt->context() eq 'installer';

    my $stdout;
    my $rs = execute(
        [ ( !iMSCP::Getopt->noprompt ? ( 'debconf-apt-progress', '--logstderr', '--' ) : () ), 'apt-get', 'update' ],
        ( iMSCP::Getopt->noprompt && !iMSCP::Getopt->verbose ? \$stdout : undef ), \my $stderr
    );
    !$rs or die( sprintf( "Couldn't update APT index: %s", $stderr || 'Unknown error' ));
    debug( $stderr );
    $self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
