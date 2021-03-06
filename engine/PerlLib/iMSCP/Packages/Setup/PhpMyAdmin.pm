=head1 NAME

 iMSCP::Packages::Setup::PhpMyAdmin - i-MSCP PhpMyAdmin package

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2018 Laurent Declercq <l.declercq@nuxwin.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

package iMSCP::Packages::Setup::PhpMyAdmin;

use strict;
use warnings;
use Class::Autouse qw/ :nostat iMSCP::Packages::Setup::PhpMyAdmin::Installer iMSCP::Packages::Setup::PhpMyAdmin::Uninstaller /;
use iMSCP::Config;
use iMSCP::Debug qw/ debug error getMessageByType /;
use iMSCP::EventManager;
use iMSCP::Getopt;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 PhpMyAdmin package for i-MSCP.

 PhpMyAdmin allows administering of MySQL with a web interface.

 It allows administrators to:
 * browse through databases and tables;
 * create, copy, rename, alter and drop databases;
 * create, copy, rename, alter and drop tables;
 * perform table maintenance;
 * add, edit and drop fields;
 * execute any SQL-statement, even multiple queries;
 * create, alter and drop indexes;
 * load text files into tables;
 * create and read dumps of tables or databases;
 * export data to SQL, CSV, XML, Word, Excel, PDF and LaTeX formats;
 * administer multiple servers;
 * manage MySQL users and privileges;
 * check server settings and runtime information with configuration hints;
 * check referential integrity in MyISAM tables;
 * create complex queries using Query-by-example (QBE), automatically connecting required tables;
 * create PDF graphics of database layout;
 * search globally in a database or a subset of it;
 * transform stored data into any format using a set of predefined functions, such as displaying BLOB-data as image or download-link;
 * manage InnoDB tables and foreign keys;
 and is fully internationalized and localized in dozens of languages.

 Project homepage: http://www.phpmyadmin.net/

=head1 PUBLIC METHODS

=over 4

=item registerSetupListeners( \%eventManager )

 Register setup event listeners

 Param iMSCP::EventManager \%eventManager
 Return void, die on failure

=cut

sub registerSetupListeners
{
    my ( $self ) = @_;

    iMSCP::Packages::Setup::PhpMyAdmin::Installer->getInstance( eventManager => $self->{'eventManager'} )->registerSetupListeners();
}

=item preinstall( )

 Process preinstall tasks

 Return void, die on failure

=cut

sub preinstall
{
    my ( $self ) = @_;

    iMSCP::Packages::Setup::PhpMyAdmin::Installer->getInstance( eventManager => $self->{'eventManager'} )->preinstall();
}

=item install( )

 Process install tasks

 Return void, die on failure

=cut

sub install
{
    my ( $self ) = @_;

    iMSCP::Packages::Setup::PhpMyAdmin::Installer->getInstance( eventManager => $self->{'eventManager'} )->install();
}

=item uninstall( )

 Process uninstall tasks

 Return void, die on failure

=cut

sub uninstall
{
    my ( $self ) = @_;

    return if $self->{'skip_uninstall'};

    iMSCP::Packages::Setup::PhpMyAdmin::Uninstaller->getInstance( eventManager => $self->{'eventManager'} )->uninstall();
}

=item getPriority( )

 Get package priority

 Return int package priority

=cut

sub getPriority
{
    0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Packages::Setup::PhpMyAdmin

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'cfgDir'} = "$::imscpConfig{'CONF_DIR'}/pma";
    $self->{'bkpDir'} = "$self->{'cfgDir'}/backup";
    $self->{'wrkDir'} = "$self->{'cfgDir'}/working";
    $self->_mergeConfig() if iMSCP::Getopt->context() eq 'installer' && -f "$self->{'cfgDir'}/phpmyadmin.data.dist";
    eval {
        tie %{ $self->{'config'} },
            'iMSCP::Config',
            filename    => "$self->{'cfgDir'}/phpmyadmin.data",
            readonly    => iMSCP::Getopt->context() ne 'installer',
            nodeferring => iMSCP::Getopt->context() eq 'installer';
    };
    if ( $@ ) {
        die unless iMSCP::Getopt->context() eq 'uninstaller';
        $self->{'skip_uninstall'} = 1;
    }
    $self;
}

=item _mergeConfig

 Merge distribution configuration with production configuration

 Return void, die on failure

=cut

sub _mergeConfig
{
    my ( $self ) = @_;

    if ( -f "$self->{'cfgDir'}/phpmyadmin.data" ) {
        tie my %newConfig, 'iMSCP::Config', filename => "$self->{'cfgDir'}/phpmyadmin.data.dist";
        tie my %oldConfig, 'iMSCP::Config', filename => "$self->{'cfgDir'}/phpmyadmin.data", readonly => 1;

        debug( 'Merging old configuration with new configuration...' );

        while ( my ( $key, $value ) = each( %oldConfig ) ) {
            next unless exists $newConfig{$key};
            $newConfig{$key} = $value;
        }

        untie( %newConfig );
        untie( %oldConfig );
    }

    iMSCP::File->new( filename => "$self->{'cfgDir'}/phpmyadmin.data.dist" )->move( "$self->{'cfgDir'}/phpmyadmin.data" );
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
