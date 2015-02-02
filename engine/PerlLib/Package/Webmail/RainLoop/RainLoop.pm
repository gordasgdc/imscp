=head1 NAME

Package::Webmail::RainLoop::RainLoop - i-MSCP RainLoop package

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2015 by internet Multi Server Control Panel
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# @category    i-MSCP
# @copyright   2010-2015 by i-MSCP | http://i-mscp.net
# @author      Laurent Declercq <l.declercq@nuxwin.com>
# @link        http://i-mscp.net i-MSCP Home Site
# @license     http://www.gnu.org/licenses/gpl-2.0.html GPL v2

package Package::Webmail::RainLoop::RainLoop;

use strict;
use warnings;

use iMSCP::Debug;
use iMSCP::Config;
use iMSCP::Database;
use iMSCP::Dir;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 RainLoop package for i-MSCP.

 RainLoop Webmail is a simple, modern and fast Web-based email client.

 Project homepage: http://http://rainloop.net/

=head1 PUBLIC METHODS

=over 4

=item showDialog(\%dialog)

 Show dialog

 Param iMSCP::Dialog \%dialog
 Return int 0 or 30

=cut

sub showDialog
{
	my ($self, $dialog) = @_;

	require Package::Webmail::RainLoop::Installer;

	Package::Webmail::RainLoop::Installer->getInstance()->showDialog($dialog);
}

=item preinstall()

 Process preinstall tasks

 Return int 0 on success, other on failure

=cut

sub preinstall
{
	require Package::Webmail::RainLoop::Installer;

	Package::Webmail::RainLoop::Installer->getInstance()->preinstall();
}

=item install()

 Process install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
	require Package::Webmail::RainLoop::Installer;

	Package::Webmail::RainLoop::Installer->getInstance()->install();
}

=item uninstall()

 Process uninstall tasks

 Return int 0 on success, other on failure

=cut

sub uninstall
{
	require Package::Webmail::RainLoop::Uninstaller;

	Package::Webmail::RainLoop::Uninstaller->getInstance()->uninstall();
}

=item setGuiPermissions()

 Set gui permissions

 Return int 0 on success, other on failure

=cut

sub setGuiPermissions
{
	require Package::Webmail::RainLoop::Installer;

	Package::Webmail::RainLoop::Installer->getInstance()->setGuiPermissions();
}

=item deleteMail(\%data)

 Process deleteMail tasks

 Param hash \%data Mail data
 Return int 0 on success, other on failure

=cut

sub deleteMail
{
	my ($self, $data) = @_;

	if($data->{'MAIL_TYPE'} =~ /_mail/) {
		my $database = iMSCP::Database->factory();
		$database->set('DATABASE_NAME', $main::imscpConfig{'DATABASE_NAME'} . '_rainloop');
		my $rs = $database->connect();

		unless($rs) {
			$rs = $database->doQuery(
				'dummy',
				'
					DELETE
						u, c, p
					FROM
						rainloop_users u
					JOIN
						rainloop_ab_contacts c USING(id_user)
					JOIN
						rainloop_ab_properties p USING(id_user)
					WHERE
						rl_email = ?
				',
				$data->{'MAIL_ADDR'}
			);
			unless(ref $rs eq 'HASH') {
				error("Unable to remove mail user '$data->{'MAIL_ADDR'}' from rainloop database: $rs");
				return 1;
			}
		} else {
			error($rs);
			return 1;
		}

		$database->set('DATABASE_NAME', $main::imscpConfig{'DATABASE_NAME'});

		fatal("Unable to restore connection to i-MSCP database: $rs") if $database->connect();

		my $storageDir = "$main::imscpConfig{'GUI_PUBLIC_DIR'}/tools/rainloop" .
			"/data/_data_11c052c218cd2a2febbfb268624efdc1/_default_/storage/cfg";

		(my $email = $data->{'MAIL_ADDR'}) =~ s/[^a-z0-9\-\.@]+/_/;
		(my $storagePath = substr($email, 0, 2)) =~ s/\@$//;

		$rs = iMSCP::Dir->new( dirname => $storageDir . '/' . $storagePath . '/' . $email )->remove();
		return $rs if $rs;
	}

	0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init()

 Initialize instance

 Return Package::Webmail::RainLoop::RainLoop

=cut

sub _init
{
	my $self = $_[0];

	$self->{'cfgDir'} = "$main::imscpConfig{'CONF_DIR'}/rainloop";

	if(-f "$self->{'cfgDir'}/rainloop.data") {
		tie %{$self->{'config'}}, 'iMSCP::Config', 'fileName' => "$self->{'cfgDir'}/rainloop.data";
	} else {
		$self->{'config'} = { };
	}

	$self;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__