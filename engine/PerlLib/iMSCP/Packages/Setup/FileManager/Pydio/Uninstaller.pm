=head1 NAME

 iMSCP::Packages::Setup::FileManager::Pydio::Uninstaller - i-MSCP Pydio package uninstaller

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

package iMSCP::Packages::Setup::FileManager::Pydio::Uninstaller;

use strict;
use warnings;
use iMSCP::Debug qw/ error /;
use iMSCP::Dir;
use iMSCP::File;
use iMSCP::Packages::FrontEnd;
use parent 'iMSCP::Common::Singleton';

=head1 DESCRIPTION

 i-MSCP Pydio package uninstaller.

=head1 PUBLIC METHODS

=over 4

=item uninstall( )

 Process uninstall tasks

 Return void, die on failure

=cut

sub uninstall
{
    my ( $self ) = @_;

    $self->_unregisterConfig();
    $self->_removeFiles();
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init( )

 Initialize instance

 Return iMSCP::Packages::Setup::FileManager::Pydio::Uninstaller

=cut

sub _init
{
    my ( $self ) = @_;

    $self->{'frontend'} = iMSCP::Packages::FrontEnd->getInstance();
    $self;
}

=item _unregisterConfig

 Remove include directive from frontEnd vhost files

 Return void, die on failure

=cut

sub _unregisterConfig
{
    my ( $self ) = @_;

    return unless -f "$self->{'frontend'}->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/$_";

    my $file = iMSCP::File->new( filename => "$self->{'frontend'}->{'config'}->{'HTTPD_SITES_AVAILABLE_DIR'}/00_master.conf" );
    my $fileContentRef = $file->getAsRef();
    ${ $fileContentRef } =~ s/[\t ]*include imscp_pydio.conf;\n//;
    $file->save();

    $self->{'frontend'}->{'reload'} ||= 1;
}

=item _removeFiles( )

 Remove files

 Return void, die on failure

=cut

sub _removeFiles
{
    my ( $self ) = @_;

    iMSCP::Dir->new( dirname => "$::imscpConfig{'GUI_PUBLIC_DIR'}/tools/ftp" )->remove();
    iMSCP::File->new( filename => "$self->{'frontend'}->{'config'}->{'HTTPD_CONF_DIR'}/imscp_pydio.conf" )->remove();
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
